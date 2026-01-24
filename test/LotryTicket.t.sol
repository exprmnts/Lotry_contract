// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {LotryTestBase, MockLotryToken, MockRewardToken, MockSmartWallet} from "./LotryTestBase.sol";
import {LotryTicket} from "../contracts/LotryTicket.sol";
import {LotryLaunch} from "../contracts/LotryLaunch.sol";

/**
 * @title LotryTicket Unit Test Suite
 * @notice Core unit tests for LotryTicket and LotryLaunch contracts
 * @dev Tests individual functions in isolation
 */
contract LotryTicketTest is LotryTestBase {

    // ========================================================================
    //                      LAUNCHPAD TESTS
    // ========================================================================

    function test_Launchpad_LaunchToken() public {
        console.log("\n=== TEST: Launch New Token ===");
        
        vm.startPrank(buyer1);
        
        string memory name = "My Lottery";
        string memory symbol = "MLOT";
        
        console.log("Creating token with name: %s, symbol: %s", name, symbol);
        
        vm.expectEmit(false, true, true, true);
        emit TokenCreated(address(0), buyer1, 1, block.timestamp, name, symbol);
        
        address newTicketAddress = launchpad.launchToken(name, symbol);
        LotryTicket newTicket = LotryTicket(newTicketAddress);
        
        console.log("New ticket deployed at:", newTicketAddress);
        console.log("New ticket owner:", newTicket.owner());
        console.log("New ticket name:", newTicket.name());
        console.log("New ticket symbol:", newTicket.symbol());
        console.log("Token count now:", launchpad.tokenCount());
        
        assertEq(newTicket.owner(), buyer1, "New ticket owner should be buyer1");
        assertEq(newTicket.name(), name, "Token name mismatch");
        assertEq(newTicket.symbol(), symbol, "Token symbol mismatch");
        assertEq(launchpad.tokenCount(), 2, "Token count should be 2");
        
        vm.stopPrank();
        console.log("TEST PASSED");
    }

    function test_Launchpad_MultipleTokenLaunches() public {
        console.log("\n=== TEST: Multiple Token Launches ===");
        
        uint256 initialCount = launchpad.tokenCount();
        console.log("Initial token count:", initialCount);
        
        // Launch 5 tokens from different addresses
        address[] memory creators = new address[](5);
        creators[0] = buyer1;
        creators[1] = buyer2;
        creators[2] = buyer3;
        creators[3] = winner;
        creators[4] = attacker;
        
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(creators[i]);
            address newToken = launchpad.launchToken(
                string(abi.encodePacked("Token", vm.toString(i))),
                string(abi.encodePacked("TKN", vm.toString(i)))
            );
            console.log("Token %d created at %s by:", i, newToken);
            console.log("  Creator:", creators[i]);
        }
        
        assertEq(launchpad.tokenCount(), initialCount + 5, "Token count should increase by 5");
        console.log("Final token count:", launchpad.tokenCount());
        console.log("TEST PASSED");
    }

    // ========================================================================
    //                      TICKET INITIALIZATION TESTS
    // ========================================================================

    function test_Ticket_InitialState() public view {
        console.log("\n=== TEST: Ticket Initial State ===");
        
        console.log("Ticket Name:", ticket.name());
        console.log("Ticket Symbol:", ticket.symbol());
        console.log("Ticket Owner:", ticket.owner());
        console.log("Total Supply:", ticket.totalSupply() / 1e18, "tokens");
        console.log("Contract Balance:", ticket.balanceOf(address(ticket)) / 1e18, "tokens");
        console.log("Initial K:", ticket.I_CONSTANT_K());
        console.log("Liquidity Pulled:", ticket.liquidityPulled());
        console.log("LOTRY Token Address:", ticket.lotryTokenAddress());
        
        assertEq(ticket.name(), "Test Ticket", "Name mismatch");
        assertEq(ticket.symbol(), "TCKT", "Symbol mismatch");
        assertEq(ticket.owner(), tokenCreator, "Owner should be token creator");
        assertEq(ticket.totalSupply(), INITIAL_SUPPLY, "Total supply mismatch");
        assertEq(ticket.balanceOf(address(ticket)), INITIAL_SUPPLY, "Contract should hold all tokens");
        assertFalse(ticket.liquidityPulled(), "Liquidity should not be pulled initially");
        assertEq(ticket.lotryTokenAddress(), address(0), "LOTRY token should not be set initially");
        
        console.log("TEST PASSED");
    }

    function test_Ticket_ConstantK_Calculation() public view {
        console.log("\n=== TEST: Constant K Calculation ===");
        
        uint256 virtualTokenReserve = 66_666_666_666667000000000000;
        uint256 virtualLotryReserve = 1_333333333333000000;
        uint256 expectedK = (INITIAL_SUPPLY + virtualTokenReserve) * virtualLotryReserve;
        
        console.log("Virtual Token Reserve:", virtualTokenReserve / 1e18, "tokens");
        console.log("Virtual LOTRY Reserve (internal):", virtualLotryReserve);
        console.log("Expected K:", expectedK);
        console.log("Actual K:", ticket.I_CONSTANT_K());
        
        assertEq(ticket.I_CONSTANT_K(), expectedK, "Constant K calculation mismatch");
        console.log("TEST PASSED");
    }

    // ========================================================================
    //                      ACCESS CONTROL TESTS
    // ========================================================================

    function test_AccessControl_SetLotryToken_OnlyOwner() public {
        console.log("\n=== TEST: setLotryToken Access Control ===");
        
        // Non-owner should fail
        console.log("Attempting to set LOTRY token as non-owner (buyer1)...");
        vm.prank(buyer1);
        vm.expectRevert();
        ticket.setLotryToken(address(lotryToken));
        console.log("Non-owner correctly rejected");
        
        // Owner should succeed
        console.log("Setting LOTRY token as owner (tokenCreator)...");
        vm.prank(tokenCreator);
        ticket.setLotryToken(address(lotryToken));
        assertEq(ticket.lotryTokenAddress(), address(lotryToken), "LOTRY token not set correctly");
        console.log("Owner successfully set LOTRY token");
        console.log("TEST PASSED");
    }

    function test_AccessControl_SetLotryToken_RejectsZeroAddress() public {
        console.log("\n=== TEST: setLotryToken Rejects Zero Address ===");
        
        vm.prank(tokenCreator);
        vm.expectRevert(abi.encodeWithSignature("Ticket__InvalidLotryToken()"));
        ticket.setLotryToken(address(0));
        
        console.log("Zero address correctly rejected");
        console.log("TEST PASSED");
    }

    function test_AccessControl_SetRewardToken_OnlyOwner() public {
        console.log("\n=== TEST: setRewardToken Access Control ===");
        
        // Non-owner should fail
        vm.prank(attacker);
        vm.expectRevert();
        ticket.setRewardToken(address(rewardToken));
        console.log("Non-owner correctly rejected");
        
        // Owner should succeed
        vm.prank(tokenCreator);
        ticket.setRewardToken(address(rewardToken));
        assertEq(ticket.rewardTokenAddress(), address(rewardToken), "Reward token not set correctly");
        console.log("Owner successfully set reward token");
        console.log("TEST PASSED");
    }

    function test_AccessControl_DistributeRewards_OnlyOwner() public {
        console.log("\n=== TEST: distributeRewards Access Control ===");
        
        _setupLotryToken();
        
        // Non-owner should fail
        vm.prank(attacker);
        vm.expectRevert();
        ticket.distributeRewards(winner);
        console.log("Non-owner correctly rejected from distributing rewards");
        
        console.log("TEST PASSED");
    }

    function test_AccessControl_PullLiquidity_OnlyOwner() public {
        console.log("\n=== TEST: pullLiquidity Access Control ===");
        
        _setupLotryToken();
        
        address[] memory wallets = new address[](1);
        wallets[0] = buyer1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;
        
        // Non-owner should fail
        vm.prank(attacker);
        vm.expectRevert();
        ticket.pullLiquidity(wallets, amounts);
        console.log("Non-owner correctly rejected from pulling liquidity");
        
        console.log("TEST PASSED");
    }

    // ========================================================================
    //                      LOTRY TOKEN VALIDATION TESTS
    // ========================================================================

    function test_LotryToken_BuyFailsWithoutLotryTokenSet() public {
        console.log("\n=== TEST: Buy Fails Without LOTRY Token Set ===");
        
        vm.startPrank(buyer1);
        lotryToken.approve(address(ticket), 1e18);
        
        vm.expectRevert(abi.encodeWithSignature("Ticket__NoLotryTokenSet()"));
        ticket.buy(1e18);
        vm.stopPrank();
        
        console.log("Buy correctly fails when LOTRY token not set");
        console.log("TEST PASSED");
    }

    function test_LotryToken_SellFailsWithoutLotryTokenSet() public {
        console.log("\n=== TEST: Sell Fails Without LOTRY Token Set ===");
        
        // First set up and do a buy
        _setupLotryToken();
        _approveAndBuy(buyer1, 1_000_000_000 * 1e18);
        
        // Remove lotry token (simulate edge case by deploying new ticket)
        vm.prank(tokenCreator);
        address newTicketAddr = launchpad.launchToken("New Test", "NTEST");
        LotryTicket newTicket = LotryTicket(newTicketAddr);
        
        // Try to sell on ticket without lotry token set
        vm.prank(buyer1);
        vm.expectRevert(abi.encodeWithSignature("Ticket__NoLotryTokenSet()"));
        newTicket.sell(100);
        
        console.log("Sell correctly fails when LOTRY token not set");
        console.log("TEST PASSED");
    }

    function test_LotryToken_OnlyAcceptsConfiguredToken() public {
        console.log("\n=== TEST: Contract Only Accepts Configured LOTRY Token ===");
        
        // Deploy a different mock token
        MockLotryToken fakeToken = new MockLotryToken();
        console.log("Fake token deployed at:", address(fakeToken));
        
        // Set the real LOTRY token
        _setupLotryToken();
        console.log("Real LOTRY token set:", address(lotryToken));
        
        // Try to buy with fake token (will fail because transferFrom will fail)
        vm.startPrank(buyer1);
        fakeToken.approve(address(ticket), 1e18);
        
        // This should fail because the contract tries to transferFrom the configured lotryToken,
        // but buyer1 hasn't approved the real lotryToken.
        vm.expectRevert();
        ticket.buy(1e18);
        vm.stopPrank();
        
        console.log("Contract correctly only uses configured LOTRY token");
        console.log("TEST PASSED");
    }

    // ========================================================================
    //                      BUY FUNCTION TESTS
    // ========================================================================

    function test_Buy_BasicPurchase() public {
        console.log("\n=== TEST: Basic Token Purchase ===");
        
        _setupLotryToken();
        
        uint256 buyAmount = 1_000_000_000 * 1e18; // 1B $LOTRY
        uint256 initialPrice = ticket.calculateCurrentPriceExternal();
        uint256 initialTicketBalance = ticket.balanceOf(buyer1);
        
        console.log("Buy Amount:", buyAmount / 1e18, "LOTRY");
        console.log("Initial Price (external):", initialPrice);
        console.log("Buyer1 initial ticket balance:", initialTicketBalance);
        
        _approveAndBuy(buyer1, buyAmount);
        
        uint256 finalPrice = ticket.calculateCurrentPriceExternal();
        uint256 finalTicketBalance = ticket.balanceOf(buyer1);
        uint256 tokensReceived = finalTicketBalance - initialTicketBalance;
        
        console.log("Final Price (external):", finalPrice);
        console.log("Buyer1 final ticket balance:", finalTicketBalance / 1e18, "tokens");
        console.log("Tokens Received:", tokensReceived / 1e18, "tokens");
        console.log("LOTRY Raised (external):", ticket.getLotryRaisedExternal());
        console.log("Accumulated Pool Fee (external):", ticket.getAccumulatedPoolFeeExternal());
        
        assertGt(tokensReceived, 0, "Should receive tokens");
        assertGt(finalPrice, initialPrice, "Price should increase after buy");
        assertGt(ticket.getLotryRaisedExternal(), 0, "LOTRY raised should increase");
        assertGt(ticket.getAccumulatedPoolFeeExternal(), 0, "Pool fee should accumulate");
        
        console.log("TEST PASSED");
    }

    function test_Buy_BelowMinimumFails() public {
        console.log("\n=== TEST: Buy Below Minimum Fails ===");
        
        _setupLotryToken();
        
        uint256 tooSmall = MIN_BUY - 1;
        console.log("Attempting to buy with amount:", tooSmall);
        
        vm.startPrank(buyer1);
        lotryToken.approve(address(ticket), tooSmall);
        vm.expectRevert(abi.encodeWithSignature("Ticket__BelowMinimumBuy()"));
        ticket.buy(tooSmall);
        vm.stopPrank();
        
        console.log("Below minimum buy correctly rejected");
        console.log("TEST PASSED");
    }

    function test_Buy_MultipleBuysIncreasesPrice() public {
        console.log("\n=== TEST: Multiple Buys Increase Price ===");
        
        _setupLotryToken();
        
        uint256 buyAmount = 1_000_000_000 * 1e18;
        uint256[] memory prices = new uint256[](6);
        
        prices[0] = ticket.calculateCurrentPriceExternal();
        console.log("Initial Price:", prices[0]);
        
        for (uint256 i = 1; i <= 5; i++) {
            address buyer = i % 2 == 0 ? buyer1 : buyer2;
            _approveAndBuy(buyer, buyAmount);
            prices[i] = ticket.calculateCurrentPriceExternal();
            console.log("Price after buy %d: %d", i, prices[i]);
            assertGt(prices[i], prices[i-1], "Price should increase");
        }
        
        console.log("Price increase factor:", (prices[5] * 100) / prices[0], "% of initial");
        console.log("TEST PASSED");
    }

    function test_Buy_TaxAccumulation() public {
        console.log("\n=== TEST: Tax Accumulation on Buy ===");
        
        _setupLotryToken();
        
        uint256 buyAmount = 10_000_000_000 * 1e18; // 10B $LOTRY (within buyer's 100B allocation)
        uint256 initialPoolFee = ticket.accumulatedPoolFee();
        
        console.log("Buy Amount:", buyAmount / 1e18, "LOTRY");
        console.log("Initial Pool Fee (internal):", initialPoolFee);
        
        _approveAndBuy(buyer1, buyAmount);
        
        uint256 finalPoolFee = ticket.accumulatedPoolFee();
        uint256 internalAmount = buyAmount / LOTRY_SCALE;
        uint256 expectedFee = (internalAmount * TAX_NUMERATOR) / TAX_DENOMINATOR;
        
        console.log("Final Pool Fee (internal):", finalPoolFee);
        console.log("Expected Fee (internal):", expectedFee);
        console.log("Accumulated Fee External:", ticket.getAccumulatedPoolFeeExternal() / 1e18, "LOTRY");
        
        assertEq(finalPoolFee, expectedFee, "Pool fee should match expected");
        console.log("TEST PASSED");
    }

    function test_Buy_EmitsTradeEvent() public {
        console.log("\n=== TEST: Buy Emits TradeEvent ===");
        
        _setupLotryToken();
        
        vm.startPrank(buyer1);
        lotryToken.approve(address(ticket), 1_000_000_000 * 1e18);
        
        vm.expectEmit(true, false, false, false);
        emit TradeEvent(address(ticket), 0);
        
        ticket.buy(1_000_000_000 * 1e18);
        vm.stopPrank();
        
        console.log("TradeEvent correctly emitted");
        console.log("TEST PASSED");
    }

    // ========================================================================
    //                      SELL FUNCTION TESTS
    // ========================================================================

    function test_Sell_BasicSale() public {
        console.log("\n=== TEST: Basic Token Sale ===");
        
        _setupLotryToken();
        
        // First buy some tokens
        uint256 buyAmount = 10_000_000_000 * 1e18;
        _approveAndBuy(buyer1, buyAmount);
        
        uint256 tokensOwned = ticket.balanceOf(buyer1);
        uint256 sellAmount = tokensOwned / 2;
        uint256 lotryBalanceBefore = lotryToken.balanceOf(buyer1);
        uint256 priceBefore = ticket.calculateCurrentPriceExternal();
        
        console.log("Tokens owned:", tokensOwned / 1e18);
        console.log("Selling:", sellAmount / 1e18, "tokens");
        console.log("Price before sell:", priceBefore);
        console.log("LOTRY balance before:", lotryBalanceBefore / 1e18);
        
        vm.prank(buyer1);
        ticket.sell(sellAmount);
        
        uint256 lotryBalanceAfter = lotryToken.balanceOf(buyer1);
        uint256 priceAfter = ticket.calculateCurrentPriceExternal();
        uint256 lotryReceived = lotryBalanceAfter - lotryBalanceBefore;
        
        console.log("Price after sell:", priceAfter);
        console.log("LOTRY received:", lotryReceived / 1e18);
        console.log("LOTRY balance after:", lotryBalanceAfter / 1e18);
        
        assertLt(priceAfter, priceBefore, "Price should decrease after sell");
        assertGt(lotryReceived, 0, "Should receive LOTRY");
        assertEq(ticket.balanceOf(buyer1), tokensOwned - sellAmount, "Token balance should decrease");
        
        console.log("TEST PASSED");
    }

    function test_Sell_FailsWithInsufficientBalance() public {
        console.log("\n=== TEST: Sell Fails With Insufficient Balance ===");
        
        _setupLotryToken();
        
        // buyer1 has no tokens
        uint256 balance = ticket.balanceOf(buyer1);
        console.log("Buyer1 balance:", balance);
        
        vm.prank(buyer1);
        vm.expectRevert(abi.encodeWithSignature("Ticket__InsufficientTokenBalance()"));
        ticket.sell(1e18);
        
        console.log("Sell correctly fails with insufficient balance");
        console.log("TEST PASSED");
    }

    function test_Sell_FailsWithZeroAmount() public {
        console.log("\n=== TEST: Sell Fails With Zero Amount ===");
        
        _setupLotryToken();
        _approveAndBuy(buyer1, 1_000_000_000 * 1e18);
        
        vm.prank(buyer1);
        vm.expectRevert(abi.encodeWithSignature("Ticket__InvalidTokenAmount()"));
        ticket.sell(0);
        
        console.log("Sell correctly fails with zero amount");
        console.log("TEST PASSED");
    }

    function test_Sell_TaxDeduction() public {
        console.log("\n=== TEST: Sell Tax Deduction ===");
        
        _setupLotryToken();
        
        // Buy tokens
        _approveAndBuy(buyer1, 10_000_000_000 * 1e18);
        
        uint256 poolFeeBefore = ticket.accumulatedPoolFee();
        uint256 tokensToSell = ticket.balanceOf(buyer1) / 2;
        
        console.log("Pool fee before sell (internal):", poolFeeBefore);
        console.log("Selling tokens:", tokensToSell / 1e18);
        
        vm.prank(buyer1);
        ticket.sell(tokensToSell);
        
        uint256 poolFeeAfter = ticket.accumulatedPoolFee();
        console.log("Pool fee after sell (internal):", poolFeeAfter);
        console.log("Fee accumulated from sell:", poolFeeAfter - poolFeeBefore);
        
        assertGt(poolFeeAfter, poolFeeBefore, "Pool fee should increase after sell");
        console.log("TEST PASSED");
    }

    // ========================================================================
    //                      TRADING DISABLED TESTS
    // ========================================================================

    function test_TradingDisabled_BuyFailsAfterLiquidityPulled() public {
        console.log("\n=== TEST: Buy Fails After Liquidity Pulled ===");
        
        _setupLotryToken();
        
        // Do some trading first
        _approveAndBuy(buyer1, 1_000_000_000 * 1e18);
        
        // Pull liquidity
        address[] memory wallets = new address[](1);
        wallets[0] = tokenCreator;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;
        
        vm.prank(tokenCreator);
        ticket.pullLiquidity(wallets, amounts);
        
        console.log("Liquidity pulled:", ticket.liquidityPulled());
        
        // Try to buy
        vm.startPrank(buyer2);
        lotryToken.approve(address(ticket), 1e18);
        vm.expectRevert(abi.encodeWithSignature("Ticket__TradingDisabled()"));
        ticket.buy(1e18);
        vm.stopPrank();
        
        console.log("Buy correctly fails after liquidity pulled");
        console.log("TEST PASSED");
    }

    function test_TradingDisabled_SellFailsAfterLiquidityPulled() public {
        console.log("\n=== TEST: Sell Fails After Liquidity Pulled ===");
        
        _setupLotryToken();
        
        // Buy tokens first
        _approveAndBuy(buyer1, 1_000_000_000 * 1e18);
        
        // Pull liquidity
        address[] memory wallets = new address[](1);
        wallets[0] = tokenCreator;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;
        
        vm.prank(tokenCreator);
        ticket.pullLiquidity(wallets, amounts);
        
        // Try to sell
        vm.prank(buyer1);
        vm.expectRevert(abi.encodeWithSignature("Ticket__TradingDisabled()"));
        ticket.sell(1e18);
        
        console.log("Sell correctly fails after liquidity pulled");
        console.log("TEST PASSED");
    }

    // ========================================================================
    //                      REWARD DISTRIBUTION TESTS
    // ========================================================================

    function test_DistributeRewards_Basic() public {
        console.log("\n=== TEST: Basic Reward Distribution ===");
        
        _setupLotryToken();
        
        // Generate some fees through trading
        _approveAndBuy(buyer1, 10_000_000_000 * 1e18);
        _approveAndBuy(buyer2, 10_000_000_000 * 1e18);
        
        uint256 poolFeeExternal = ticket.getAccumulatedPoolFeeExternal();
        uint256 winnerBalanceBefore = lotryToken.balanceOf(winner);
        uint256 protocolBalanceBefore = lotryToken.balanceOf(PROTOCOL_WALLET);
        
        console.log("Pool Fee (external):", poolFeeExternal / 1e18, "LOTRY");
        console.log("Winner balance before:", winnerBalanceBefore / 1e18);
        console.log("Protocol balance before:", protocolBalanceBefore / 1e18);
        
        vm.prank(tokenCreator);
        ticket.distributeRewards(winner);
        
        uint256 winnerBalanceAfter = lotryToken.balanceOf(winner);
        uint256 protocolBalanceAfter = lotryToken.balanceOf(PROTOCOL_WALLET);
        uint256 winnerReceived = winnerBalanceAfter - winnerBalanceBefore;
        uint256 protocolReceived = protocolBalanceAfter - protocolBalanceBefore;
        
        console.log("Winner received:", winnerReceived / 1e18, "LOTRY");
        console.log("Protocol received:", protocolReceived / 1e18, "LOTRY");
        console.log("Pool fee after distribution:", ticket.getAccumulatedPoolFeeExternal());
        
        // Verify 80/20 split
        assertGt(winnerReceived, protocolReceived * 3, "Winner should receive ~80%");
        assertEq(ticket.accumulatedPoolFee(), 0, "Pool fee should be cleared");
        
        console.log("TEST PASSED");
    }

    function test_DistributeRewards_FailsWithZeroWinner() public {
        console.log("\n=== TEST: Distribute Rewards Fails With Zero Address ===");
        
        _setupLotryToken();
        
        vm.prank(tokenCreator);
        vm.expectRevert(abi.encodeWithSignature("Ticket__NullWinnerAddress()"));
        ticket.distributeRewards(address(0));
        
        console.log("Zero address winner correctly rejected");
        console.log("TEST PASSED");
    }

    function test_DistributeRewards_WithRewardTokens() public {
        console.log("\n=== TEST: Distribute Rewards With Additional Reward Tokens ===");
        
        _setupLotryToken();
        _setupRewardToken();
        
        // Generate fees
        _approveAndBuy(buyer1, 10_000_000_000 * 1e18);
        
        // Deposit reward tokens
        uint256 rewardAmount = 1000 * 1e18;
        vm.startPrank(deployer);
        rewardToken.approve(address(ticket), rewardAmount);
        ticket.depositRewardTokens(rewardAmount);
        vm.stopPrank();
        
        console.log("Deposited reward tokens:", rewardAmount / 1e18);
        console.log("Accumulated reward tokens:", ticket.getRewardTokenBalance() / 1e18);
        
        uint256 winnerRewardBefore = rewardToken.balanceOf(winner);
        
        vm.prank(tokenCreator);
        ticket.distributeRewards(winner);
        
        uint256 winnerRewardAfter = rewardToken.balanceOf(winner);
        
        console.log("Winner received reward tokens:", (winnerRewardAfter - winnerRewardBefore) / 1e18);
        assertEq(winnerRewardAfter - winnerRewardBefore, rewardAmount, "Winner should receive all reward tokens");
        assertEq(ticket.getRewardTokenBalance(), 0, "Reward token balance should be cleared");
        
        console.log("TEST PASSED");
    }

    function test_DistributeRewards_EmitsEvent() public {
        console.log("\n=== TEST: Distribute Rewards Emits Event ===");
        
        _setupLotryToken();
        _approveAndBuy(buyer1, 1_000_000_000 * 1e18);
        
        vm.prank(tokenCreator);
        vm.expectEmit(true, false, false, false);
        emit RewardsDistributed(winner, 0, 0);
        ticket.distributeRewards(winner);
        
        console.log("RewardsDistributed event correctly emitted");
        console.log("TEST PASSED");
    }

    // ========================================================================
    //                      SMART WALLET REWARD DISTRIBUTION TESTS
    // ========================================================================

    function test_DistributeRewards_ToSmartWallet() public {
        console.log("\n=== TEST: Distribute Rewards To Smart Wallet ===");
        
        _setupLotryToken();
        _setupRewardToken();
        
        // Deploy a smart wallet (simulating Safe, Argent, etc.)
        MockSmartWallet smartWallet = new MockSmartWallet();
        console.log("Smart wallet deployed at:", address(smartWallet));
        
        // Generate fees through trading
        _approveAndBuy(buyer1, 10_000_000_000 * 1e18);
        _approveAndBuy(buyer2, 10_000_000_000 * 1e18);
        
        // Deposit reward tokens
        uint256 rewardAmount = 1000 * 1e18;
        vm.startPrank(deployer);
        rewardToken.approve(address(ticket), rewardAmount);
        ticket.depositRewardTokens(rewardAmount);
        vm.stopPrank();
        
        uint256 poolFeeExternal = ticket.getAccumulatedPoolFeeExternal();
        console.log("Pool Fee (external):", poolFeeExternal / 1e18, "LOTRY");
        
        // Distribute rewards to smart wallet
        vm.prank(tokenCreator);
        ticket.distributeRewards(address(smartWallet));
        
        uint256 smartWalletLotryBalance = lotryToken.balanceOf(address(smartWallet));
        uint256 smartWalletRewardBalance = rewardToken.balanceOf(address(smartWallet));
        
        console.log("Smart wallet received LOTRY:", smartWalletLotryBalance / 1e18);
        console.log("Smart wallet received Reward:", smartWalletRewardBalance / 1e18);
        
        // Verify funds were received
        assertGt(smartWalletLotryBalance, 0, "Smart wallet should receive LOTRY");
        assertEq(smartWalletRewardBalance, rewardAmount, "Smart wallet should receive all reward tokens");
        
        // Verify smart wallet can access the funds
        uint256 lotryBalance = smartWallet.getTokenBalance(address(lotryToken));
        uint256 rewardBalance = smartWallet.getTokenBalance(address(rewardToken));
        
        assertEq(lotryBalance, smartWalletLotryBalance, "Smart wallet should be able to read LOTRY balance");
        assertEq(rewardBalance, smartWalletRewardBalance, "Smart wallet should be able to read reward balance");
        
        console.log("Smart wallet successfully received and can access funds");
        console.log("TEST PASSED");
    }

    function test_DistributeRewards_ToTempWallet() public {
        console.log("\n=== TEST: Distribute Rewards To Temporary Wallet ===");
        
        _setupLotryToken();
        _setupRewardToken();
        
        // Create a random temporary wallet address
        address tempWallet = makeAddr("temporaryWinner");
        console.log("Temp wallet address:", tempWallet);
        
        // Verify temp wallet starts with zero balance
        assertEq(lotryToken.balanceOf(tempWallet), 0, "Temp wallet should start with 0 LOTRY");
        assertEq(rewardToken.balanceOf(tempWallet), 0, "Temp wallet should start with 0 reward tokens");
        
        // Generate fees through trading
        _approveAndBuy(buyer1, 10_000_000_000 * 1e18);
        _approveAndBuy(buyer2, 10_000_000_000 * 1e18);
        
        // Deposit reward tokens
        uint256 rewardAmount = 500 * 1e18;
        vm.startPrank(deployer);
        rewardToken.approve(address(ticket), rewardAmount);
        ticket.depositRewardTokens(rewardAmount);
        vm.stopPrank();
        
        uint256 poolFeeExternal = ticket.getAccumulatedPoolFeeExternal();
        uint256 expectedWinnerShare = (poolFeeExternal * 80) / 100;
        
        console.log("Pool Fee (external):", poolFeeExternal / 1e18, "LOTRY");
        console.log("Expected winner share (~80%):", expectedWinnerShare / 1e18, "LOTRY");
        
        // Distribute rewards to temp wallet
        vm.prank(tokenCreator);
        ticket.distributeRewards(tempWallet);
        
        uint256 tempWalletLotryBalance = lotryToken.balanceOf(tempWallet);
        uint256 tempWalletRewardBalance = rewardToken.balanceOf(tempWallet);
        
        console.log("Temp wallet received LOTRY:", tempWalletLotryBalance / 1e18);
        console.log("Temp wallet received Reward:", tempWalletRewardBalance / 1e18);
        
        // Verify funds were received
        assertGt(tempWalletLotryBalance, 0, "Temp wallet should receive LOTRY");
        assertEq(tempWalletRewardBalance, rewardAmount, "Temp wallet should receive all reward tokens");
        
        // Verify the 80% split is correct
        assertEq(tempWalletLotryBalance, expectedWinnerShare, "Winner should receive exactly 80%");
        
        console.log("Temp wallet successfully received rewards");
        console.log("TEST PASSED");
    }

    function test_DistributeRewards_VerifyProtocolReceived() public {
        console.log("\n=== TEST: Verify Protocol Wallet Received 20% ===");
        
        _setupLotryToken();
        
        // Generate fees through trading
        _approveAndBuy(buyer1, 10_000_000_000 * 1e18);
        
        uint256 poolFeeExternal = ticket.getAccumulatedPoolFeeExternal();
        uint256 protocolBalanceBefore = lotryToken.balanceOf(PROTOCOL_WALLET);
        uint256 expectedProtocolShare = (poolFeeExternal * 20) / 100;
        
        console.log("Pool Fee (external):", poolFeeExternal / 1e18, "LOTRY");
        console.log("Protocol balance before:", protocolBalanceBefore / 1e18, "LOTRY");
        console.log("Expected protocol share (20%):", expectedProtocolShare / 1e18, "LOTRY");
        
        // Distribute rewards
        vm.prank(tokenCreator);
        ticket.distributeRewards(winner);
        
        uint256 protocolBalanceAfter = lotryToken.balanceOf(PROTOCOL_WALLET);
        uint256 protocolReceived = protocolBalanceAfter - protocolBalanceBefore;
        
        console.log("Protocol balance after:", protocolBalanceAfter / 1e18, "LOTRY");
        console.log("Protocol received:", protocolReceived / 1e18, "LOTRY");
        
        // Verify 20% split
        assertEq(protocolReceived, expectedProtocolShare, "Protocol should receive exactly 20%");
        
        console.log("Protocol wallet correctly received 20%");
        console.log("TEST PASSED");
    }

    // ========================================================================
    //                      LIQUIDITY PULL TESTS
    // ========================================================================

    function test_PullLiquidity_Basic() public {
        console.log("\n=== TEST: Basic Liquidity Pull ===");
        
        _setupLotryToken();
        
        // Generate some liquidity
        _approveAndBuy(buyer1, 10_000_000_000 * 1e18);
        
        uint256 contractLotryBalance = ticket.getLotryBalance();
        console.log("Contract LOTRY balance:", contractLotryBalance / 1e18);
        
        // Set up recipients
        address[] memory wallets = new address[](2);
        wallets[0] = buyer1;
        wallets[1] = buyer2;
        
        uint256 halfBalance = contractLotryBalance / 2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = halfBalance;
        amounts[1] = halfBalance;
        
        uint256 buyer1Before = lotryToken.balanceOf(buyer1);
        uint256 buyer2Before = lotryToken.balanceOf(buyer2);
        
        vm.prank(tokenCreator);
        vm.expectEmit(false, false, false, true);
        emit LiquidityPulled(halfBalance * 2);
        ticket.pullLiquidity(wallets, amounts);
        
        console.log("Buyer1 received:", (lotryToken.balanceOf(buyer1) - buyer1Before) / 1e18, "LOTRY");
        console.log("Buyer2 received:", (lotryToken.balanceOf(buyer2) - buyer2Before) / 1e18, "LOTRY");
        console.log("Liquidity pulled flag:", ticket.liquidityPulled());
        
        assertTrue(ticket.liquidityPulled(), "Liquidity pulled flag should be true");
        console.log("TEST PASSED");
    }

    function test_PullLiquidity_FailsOnSecondCall() public {
        console.log("\n=== TEST: Pull Liquidity Fails On Second Call ===");
        
        _setupLotryToken();
        
        address[] memory wallets = new address[](1);
        wallets[0] = buyer1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;
        
        vm.prank(tokenCreator);
        ticket.pullLiquidity(wallets, amounts);
        
        // Second call should fail
        vm.prank(tokenCreator);
        vm.expectRevert(abi.encodeWithSignature("Ticket__LiquidityAlreadyPulled()"));
        ticket.pullLiquidity(wallets, amounts);
        
        console.log("Second pull correctly rejected");
        console.log("TEST PASSED");
    }

    function test_PullLiquidity_FailsWithMismatchedArrays() public {
        console.log("\n=== TEST: Pull Liquidity Fails With Mismatched Arrays ===");
        
        _setupLotryToken();
        
        address[] memory wallets = new address[](2);
        wallets[0] = buyer1;
        wallets[1] = buyer2;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100;
        
        vm.prank(tokenCreator);
        vm.expectRevert(abi.encodeWithSignature("Ticket__MismatchedArrayLengths()"));
        ticket.pullLiquidity(wallets, amounts);
        
        console.log("Mismatched arrays correctly rejected");
        console.log("TEST PASSED");
    }

    function test_PullLiquidity_FailsExceedingBalance() public {
        console.log("\n=== TEST: Pull Liquidity Fails Exceeding Balance ===");
        
        _setupLotryToken();
        _approveAndBuy(buyer1, 1_000_000_000 * 1e18);
        
        uint256 contractBalance = ticket.getLotryBalance();
        
        address[] memory wallets = new address[](1);
        wallets[0] = buyer1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = contractBalance + 1;
        
        vm.prank(tokenCreator);
        vm.expectRevert(abi.encodeWithSignature("Ticket__ExceedsContractBalance()"));
        ticket.pullLiquidity(wallets, amounts);
        
        console.log("Exceeding balance correctly rejected");
        console.log("TEST PASSED");
    }

    function test_PullLiquidity_ToSmartWallet() public {
        console.log("\n=== TEST: Pull Liquidity To Smart Wallet ===");
        
        _setupLotryToken();
        
        // Deploy a smart wallet
        MockSmartWallet smartWallet = new MockSmartWallet();
        console.log("Smart wallet deployed at:", address(smartWallet));
        
        // Generate some liquidity
        _approveAndBuy(buyer1, 10_000_000_000 * 1e18);
        
        uint256 contractLotryBalance = ticket.getLotryBalance();
        console.log("Contract LOTRY balance:", contractLotryBalance / 1e18);
        
        // Pull liquidity to smart wallet
        address[] memory wallets = new address[](1);
        wallets[0] = address(smartWallet);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = contractLotryBalance;
        
        vm.prank(tokenCreator);
        ticket.pullLiquidity(wallets, amounts);
        
        uint256 smartWalletBalance = lotryToken.balanceOf(address(smartWallet));
        console.log("Smart wallet received:", smartWalletBalance / 1e18, "LOTRY");
        
        assertEq(smartWalletBalance, contractLotryBalance, "Smart wallet should receive all liquidity");
        
        console.log("Smart wallet successfully received liquidity");
        console.log("TEST PASSED");
    }

    // ========================================================================
    //                      DEPOSIT FUNCTIONS TESTS
    // ========================================================================

    function test_DepositLotryTokens() public {
        console.log("\n=== TEST: Deposit LOTRY Tokens ===");
        
        _setupLotryToken();
        
        uint256 depositAmount = 1_000_000_000 * 1e18;
        uint256 poolFeeBefore = ticket.accumulatedPoolFee();
        
        console.log("Depositing:", depositAmount / 1e18, "LOTRY");
        console.log("Pool fee before (internal):", poolFeeBefore);
        
        vm.startPrank(buyer1);
        lotryToken.approve(address(ticket), depositAmount);
        ticket.depositLotryTokens(depositAmount);
        vm.stopPrank();
        
        uint256 poolFeeAfter = ticket.accumulatedPoolFee();
        uint256 expectedInternalIncrease = depositAmount / LOTRY_SCALE;
        
        console.log("Pool fee after (internal):", poolFeeAfter);
        console.log("Expected increase (internal):", expectedInternalIncrease);
        
        assertEq(poolFeeAfter - poolFeeBefore, expectedInternalIncrease, "Pool fee should increase by deposited amount");
        console.log("TEST PASSED");
    }

    function test_DepositLotryTokens_FailsWithZeroAmount() public {
        console.log("\n=== TEST: Deposit LOTRY Fails With Zero Amount ===");
        
        _setupLotryToken();
        
        vm.prank(buyer1);
        vm.expectRevert(abi.encodeWithSignature("Ticket__InvalidTokenAmount()"));
        ticket.depositLotryTokens(0);
        
        console.log("Zero amount deposit correctly rejected");
        console.log("TEST PASSED");
    }

    function test_DepositRewardTokens() public {
        console.log("\n=== TEST: Deposit Reward Tokens ===");
        
        _setupRewardToken();
        
        uint256 depositAmount = 500 * 1e18;
        
        vm.startPrank(deployer);
        rewardToken.approve(address(ticket), depositAmount);
        ticket.depositRewardTokens(depositAmount);
        vm.stopPrank();
        
        assertEq(ticket.getRewardTokenBalance(), depositAmount, "Reward token balance should match deposit");
        console.log("Deposited reward tokens:", ticket.getRewardTokenBalance() / 1e18);
        console.log("TEST PASSED");
    }

    function test_DepositRewardTokens_FailsWithoutRewardTokenSet() public {
        console.log("\n=== TEST: Deposit Reward Tokens Fails Without Token Set ===");
        
        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSignature("Ticket__NoRewardTokenSet()"));
        ticket.depositRewardTokens(100);
        
        console.log("Deposit correctly fails when reward token not set");
        console.log("TEST PASSED");
    }

    // ========================================================================
    //                      BONDING CURVE TESTS
    // ========================================================================

    function test_BondingCurve_PriceIncreasesWithBuys() public {
        console.log("\n=== TEST: Bonding Curve Price Increase ===");
        
        _setupLotryToken();
        
        uint256 buyAmount = 1_000_000_000 * 1e18;
        uint256 initialPrice = ticket.calculateCurrentPriceExternal();
        
        console.log("Initial Price:", initialPrice);
        console.log("Buy Amount per transaction:", buyAmount / 1e18, "LOTRY");
        
        uint256 prevPrice = initialPrice;
        for (uint256 i = 0; i < 10; i++) {
            _approveAndBuy(buyer1, buyAmount);
            uint256 newPrice = ticket.calculateCurrentPriceExternal();
            console.log("Price after buy %d: %d", i + 1, newPrice);
            assertGt(newPrice, prevPrice, "Price should increase");
            prevPrice = newPrice;
        }
        
        uint256 priceMultiplier = (prevPrice * 100) / initialPrice;
        console.log("Final price is", priceMultiplier, "% of initial");
        console.log("TEST PASSED");
    }

    function test_BondingCurve_PriceDecreasesWithSells() public {
        console.log("\n=== TEST: Bonding Curve Price Decrease ===");
        
        _setupLotryToken();
        
        // First buy a significant amount
        uint256 buyAmount = 50_000_000_000 * 1e18;
        _approveAndBuy(buyer1, buyAmount);
        
        uint256 priceAfterBuy = ticket.calculateCurrentPriceExternal();
        uint256 tokensOwned = ticket.balanceOf(buyer1);
        uint256 sellChunk = tokensOwned / 10;
        
        console.log("Price after initial buy:", priceAfterBuy);
        console.log("Tokens owned:", tokensOwned / 1e18);
        console.log("Selling in chunks of:", sellChunk / 1e18, "tokens");
        
        uint256 prevPrice = priceAfterBuy;
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(buyer1);
            ticket.sell(sellChunk);
            uint256 newPrice = ticket.calculateCurrentPriceExternal();
            console.log("Price after sell %d: %d", i + 1, newPrice);
            assertLt(newPrice, prevPrice, "Price should decrease");
            prevPrice = newPrice;
        }
        
        console.log("TEST PASSED");
    }

    function test_BondingCurve_CalculateBuyReturn() public {
        console.log("\n=== TEST: Calculate Buy Return ===");
        
        _setupLotryToken();
        
        uint256[] memory amounts = new uint256[](5);
        amounts[0] = 100000000; // 0.1 internal
        amounts[1] = 1000000000; // 1 internal
        amounts[2] = 10000000000; // 10 internal
        amounts[3] = 100000000000; // 100 internal
        amounts[4] = 1000000000000; // 1000 internal
        
        console.log("Testing calculateBuyReturn with various amounts:");
        
        for (uint256 i = 0; i < 5; i++) {
            uint256 tokensOut = ticket.calculateBuyReturn(amounts[i]);
            console.log("Internal amount: %d -> Tokens: %d", amounts[i], tokensOut / 1e18);
            assertGt(tokensOut, 0, "Should return positive tokens");
        }
        
        console.log("TEST PASSED");
    }

    function test_BondingCurve_CalculateSellReturn() public {
        console.log("\n=== TEST: Calculate Sell Return ===");
        
        _setupLotryToken();
        _approveAndBuy(buyer1, 50_000_000_000 * 1e18);
        
        uint256 tokensOwned = ticket.balanceOf(buyer1);
        
        console.log("Tokens owned:", tokensOwned / 1e18);
        console.log("Testing calculateSellReturn with various amounts:");
        
        uint256[] memory sellAmounts = new uint256[](4);
        sellAmounts[0] = tokensOwned / 100;
        sellAmounts[1] = tokensOwned / 10;
        sellAmounts[2] = tokensOwned / 4;
        sellAmounts[3] = tokensOwned / 2;
        
        for (uint256 i = 0; i < 4; i++) {
            uint256 lotryOut = ticket.calculateSellReturn(sellAmounts[i]);
            console.log("Selling %d tokens -> LOTRY (internal): %d", sellAmounts[i] / 1e18, lotryOut);
            assertGt(lotryOut, 0, "Should return positive LOTRY");
        }
        
        console.log("TEST PASSED");
    }

    // ========================================================================
    //                      VIEW FUNCTIONS TESTS
    // ========================================================================

    function test_ViewFunctions_GettersReturnCorrectValues() public {
        console.log("\n=== TEST: View Functions Return Correct Values ===");
        
        _setupLotryToken();
        _setupRewardToken();
        
        // Do some trading
        _approveAndBuy(buyer1, 1_000_000_000 * 1e18);
        
        console.log("LOTRY Token Address:", ticket.lotryTokenAddress());
        console.log("Reward Token Address:", ticket.rewardTokenAddress());
        console.log("LOTRY Raised (internal):", ticket.lotryRaised());
        console.log("LOTRY Raised (external):", ticket.getLotryRaisedExternal());
        console.log("Pool Fee (internal):", ticket.accumulatedPoolFee());
        console.log("Pool Fee (external):", ticket.getAccumulatedPoolFeeExternal());
        console.log("Current Price (internal):", ticket.calculateCurrentPrice());
        console.log("Current Price (external):", ticket.calculateCurrentPriceExternal());
        console.log("LOTRY Balance:", ticket.getLotryBalance());
        console.log("Liquidity Pulled:", ticket.liquidityPulled());
        
        assertEq(ticket.lotryTokenAddress(), address(lotryToken), "LOTRY token address mismatch");
        assertEq(ticket.rewardTokenAddress(), address(rewardToken), "Reward token address mismatch");
        assertEq(ticket.getLotryRaisedExternal(), ticket.lotryRaised() * LOTRY_SCALE, "External LOTRY raised mismatch");
        assertEq(ticket.getAccumulatedPoolFeeExternal(), ticket.accumulatedPoolFee() * LOTRY_SCALE, "External pool fee mismatch");
        assertEq(ticket.calculateCurrentPriceExternal(), ticket.calculateCurrentPrice() * LOTRY_SCALE, "External price mismatch");
        
        console.log("TEST PASSED");
    }
}
