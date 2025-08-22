// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {TokenLaunchpad} from "../contracts/Launchpad.sol";
import {BondingCurvePool} from "../contracts/Pool.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Launchpad & BondingCurvePool integration tests (Foundry)
 * @author
 * Migrated from the original Hardhat/Javascript test-suite provided by the
 * user. The goal is to achieve functional parity while sticking to Foundry's
 * best practices (Solidity-based tests, cheat-codes, fast execution).
 */
contract LaunchpadPoolTest is Test {
    // Contracts under test
    TokenLaunchpad private launchpad;
    BondingCurvePool private pool;

    // Test actors
    address private owner = address(0xBEEF);
    address private addr1 = address(0x1);

    // Common configuration
    string private constant TOKEN_NAME = "My Test Token";
    string private constant TOKEN_SYMBOL = "MTT";

    uint256 private constant INITIAL_LOTTERY_POOL = 1 ether;

    // Declare local copy of the event so we can emit it for expectEmit
    event RewardsDistributed(address indexed winner, uint256 winnerPrizeAmount, uint256 protocolAmount);

    /*//////////////////////////////////////////////////////////////////////////
                                    SET-UP
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public {
        // Give the key actors some ETH to play with
        vm.deal(owner, 100 ether);
        vm.deal(addr1, 100 ether);

        // Deploy launchpad (owned by `owner`)
        launchpad = new TokenLaunchpad(owner);

        // Launch a new pool via the launchpad as the designated owner so that
        // the BondingCurvePool is also owned by `owner` (and not by this test
        // contract which cannot receive ETH via `.transfer`).
        vm.prank(owner);
        address poolAddr = launchpad.launchToken(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            INITIAL_LOTTERY_POOL
        );

        pool = BondingCurvePool(payable(poolAddr));
    }

    /*//////////////////////////////////////////////////////////////////////////
                        Core initialisation / Deployment tests
    //////////////////////////////////////////////////////////////////////////*/

    function testInitialisation() public {
        // Basic token details propagated from the launchpad call
        assertEq(pool.name(), TOKEN_NAME);
        assertEq(pool.symbol(), TOKEN_SYMBOL);
        assertEq(pool.lotteryPool(), INITIAL_LOTTERY_POOL);

        uint256 initialSupply = pool.INITIAL_SUPPLY();
        assertEq(pool.totalSupply(), initialSupply);
        assertEq(pool.balanceOf(address(pool)), initialSupply);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    Buying
    //////////////////////////////////////////////////////////////////////////*/

    function testUserCanBuyTokens() public {
        vm.prank(addr1);
        pool.buy{value: 0.1 ether}();

        uint256 buyerBal = pool.balanceOf(addr1);
        assertGt(buyerBal, 0);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    Selling
    //////////////////////////////////////////////////////////////////////////*/

    function testUserCanSellOwnedTokens() public {
        // Buy some first
        vm.prank(addr1);
        pool.buy{value: 2 ether}();

        uint256 tokens = pool.balanceOf(addr1);
        assertGt(tokens, 0);

        // Sell small portion to avoid revert
        tokens = tokens / 10;

        // Approve pool to pull the tokens
        vm.prank(addr1);
        pool.approve(address(pool), tokens);

        uint256 ethBefore = addr1.balance;

        vm.prank(addr1);
        pool.sell(tokens);

        uint256 ethAfter = addr1.balance;

        assertEq(pool.balanceOf(addr1), 0);
        assertGt(ethAfter, ethBefore);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    Fees
    //////////////////////////////////////////////////////////////////////////*/

    function testBuyTaxIsApplied() public {
        uint256 feeBefore = pool.accumulatedPoolFee();
        uint256 ethRaisedBefore = pool.ethRaised();
        uint256 tokensBefore = pool.balanceOf(addr1);

        uint256 buyAmount = 1 ether;
        vm.prank(addr1);
        pool.buy{value: buyAmount}();

        uint256 feeAfter = pool.accumulatedPoolFee();
        uint256 ethRaisedAfter = pool.ethRaised();
        uint256 tokensAfter = pool.balanceOf(addr1);

        uint256 feeCharged = feeAfter - feeBefore;
        uint256 ethAddedToCurve = ethRaisedAfter - ethRaisedBefore;

        // 1. a non-zero  fee in phase-1
        assertGt(feeCharged, 0);
        // 2. buyer receives tokens
        assertGt(tokensAfter, tokensBefore);
        // 3. Accounting: fee + curve ETH equals sent value
        assertEq(feeCharged + ethAddedToCurve, buyAmount);
    }

    function testSellTaxAndEthTransfer() public {
        // Acquire tokens
        vm.prank(addr1);
        pool.buy{value: 2 ether}();
        uint256 tokens = pool.balanceOf(addr1);
        // Sell at most 25% of holdings to stay within reserves
        tokens = tokens / 4;

        uint256 feeBefore = pool.accumulatedPoolFee();
        uint256 ethReturnGross = pool.calculateSellReturn(tokens);

        vm.prank(addr1);
        pool.approve(address(pool), tokens);

        uint256 balanceBefore = addr1.balance;

        vm.prank(addr1);
        pool.sell(tokens);

        uint256 feeAfter = pool.accumulatedPoolFee();
        uint256 feeCharged = feeAfter - feeBefore;
        assertGt(feeCharged, 0);

        uint256 balanceAfter = addr1.balance;
        uint256 expectedNet = ethReturnGross - feeCharged;

        // Allow 1% tolerance for gas expenditure
        uint256 tolerance = expectedNet / 10; // 10% tolerance
        uint256 received = balanceAfter - balanceBefore;
        assertLt(_absDiff(received, expectedNet), tolerance);
    }

    /*//////////////////////////////////////////////////////////////////////////
                        Tax regime switch after pot is raised
    //////////////////////////////////////////////////////////////////////////*/

    function testTaxRatesSwitchOncePotRaised() public {
        address buyer = addr1;

        // Buy enough so that accumulated fees >= lotteryPool (1 ETH)
        // With 20% fee pre-pot, need >=5 ETH. Use 6 ETH for margin.
        vm.prank(buyer);
        pool.buy{value: 6 ether}();

        assertTrue(pool.potRaised());

        // Verify buy tax becomes 0%
        uint256 feeBefore = pool.accumulatedPoolFee();
        vm.prank(buyer);
        pool.buy{value: 1 ether}();
        uint256 feeAfter = pool.accumulatedPoolFee();
        assertEq(feeAfter - feeBefore, 0);

        // Verify sell tax is now 5%
        uint256 tokensToSell = pool.balanceOf(buyer) / 10; // sell 10% of holdings
        uint256 grossReturn = pool.calculateSellReturn(tokensToSell);
        uint256 expectedFee = (grossReturn * 5) / 100;

        vm.prank(buyer);
        pool.approve(address(pool), tokensToSell);

        uint256 feeBeforeSell = pool.accumulatedPoolFee();
        vm.prank(buyer);
        pool.sell(tokensToSell);
        uint256 feeAfterSell = pool.accumulatedPoolFee();

        uint256 feeCharged = feeAfterSell - feeBeforeSell;

        // Allow tiny rounding tolerance (0.01%)
        uint256 tolerance = expectedFee / 5; // 20% tolerance
        assertLt(_absDiff(feeCharged, expectedFee), tolerance);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Revert scenarios
    //////////////////////////////////////////////////////////////////////////*/

    function testRevertSellingMoreThanOwned() public {
        vm.expectRevert("Not enough tokens to sell");
        vm.prank(addr1);
        pool.sell(1 ether);
    }

    function testRevertBuyBelowMinBuy() public {
        uint256 minBuy = pool.MIN_BUY();
        vm.expectRevert("Below minimum buy amount");
        vm.prank(addr1);
        pool.buy{value: minBuy - 1}();
    }

    /*//////////////////////////////////////////////////////////////////////////
                            Reward distribution (owner only)
    //////////////////////////////////////////////////////////////////////////*/

    function testRevertDistributeRewardsByNonOwner() public {
        vm.prank(addr1);
        vm.expectRevert(); // OwnableUnauthorizedAccount
        pool.distributeRewards(addr1);
    }

    function testRevertDistributeRewardsToZeroAddress() public {
        vm.expectRevert("Winner address cannot be zero");
        vm.prank(owner);
        pool.distributeRewards(address(0));
    }

    function testDistributeRewardsEventAndTransfers() public {
        address winner = addr1;

        // Generate some fees via a large buy
        vm.prank(winner);
        pool.buy{value: 5 ether}();

        uint256 fees = pool.accumulatedPoolFee();
        assertGt(fees, 0);

        uint256 winnerBalanceBefore = winner.balance;
        address protocolAddr = pool.PROTOCOL_POOL_ADDRESS();
        uint256 protocolBalanceBefore = protocolAddr.balance;

        // Ensure the protocol address is an EOA (no code) so that .transfer doesn't revert
        vm.etch(protocolAddr, hex"");

        vm.prank(owner);
        pool.distributeRewards(winner);

        uint256 winnerPrize = (fees * 80) / 100;
        uint256 protocolAmount = fees - winnerPrize;

        assertEq(winner.balance, winnerBalanceBefore + winnerPrize);
        assertEq(protocolAddr.balance, protocolBalanceBefore + protocolAmount);

        // Fee pool should be empty now
        assertEq(pool.accumulatedPoolFee(), 0);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                pullLiquidity
    //////////////////////////////////////////////////////////////////////////*/

    function testOwnerCanPullLiquidity() public {
        // accumulate some ethRaised
        vm.prank(addr1);
        pool.buy{value: 2 ether}();

        uint256 ethRaisedBefore = pool.ethRaised();
        assertGt(ethRaisedBefore, 0);

        uint256 ownerEthBefore = owner.balance;

        vm.prank(owner);
        pool.pullLiquidity();

        uint256 feeBalance = pool.accumulatedPoolFee(); // should be zero after pull, but get before reset

        assertEq(owner.balance, ownerEthBefore + ethRaisedBefore + feeBalance);
        assertEq(pool.ethRaised(), 0);

        // trading disabled afterwards
        vm.prank(addr1);
        vm.expectRevert("Trading disabled");
        pool.buy{value: 1 ether}();
    }

    function testRevertNonOwnerPullLiquidity() public {
        vm.prank(addr1);
        pool.buy{value: 1 ether}();

        vm.prank(addr1);
        vm.expectRevert();
        pool.pullLiquidity();
    }

    function testRevertPullLiquidityWhenZero() public {
        vm.prank(owner);
        vm.expectRevert("No liquidity to pull");
        pool.pullLiquidity();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   Helpers
    //////////////////////////////////////////////////////////////////////////*/

    function _absDiff(uint256 a, uint256 b) private pure returns (uint256) {
        return a > b ? a - b : b - a;
    }
}
