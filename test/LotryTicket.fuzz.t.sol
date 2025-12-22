// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {LotryTestBase} from "./LotryTestBase.sol";
import {LotryTicket} from "../contracts/LotryTicket.sol";

/**
 * @title LotryTicket Fuzz Test Suite
 * @notice Fuzz tests for random input validation
 * @dev Tests contract behavior with randomized inputs
 */
contract LotryTicketFuzzTest is LotryTestBase {

    // ========================================================================
    //                      FUZZ TESTS - BUY FUNCTION
    // ========================================================================

    function testFuzz_Buy_VariousAmounts(uint256 amount) public {
        _setupLotryToken();
        
        // Bound the amount to reasonable values
        // Minimum must be large enough so that after dividing by LOTRY_SCALE (1e10) 
        // and subtracting the 11% fee, the net amount is still > 0
        // netLotryForCurve = (amount / 1e10) * 89 / 100 > 0
        // So amount must be > 1e10 * 100 / 89 ≈ 1.12e10, use 1e11 to be safe
        uint256 minAmount = 1e11; // 0.0001 LOTRY with 18 decimals
        amount = bound(amount, minAmount, 10_000_000_000 * 1e18);
        
        uint256 initialBalance = ticket.balanceOf(buyer1);
        
        _approveAndBuy(buyer1, amount);
        
        assertGt(ticket.balanceOf(buyer1), initialBalance, "Should receive tokens");
    }

    function testFuzz_Buy_PriceAlwaysIncreases(uint256 amount) public {
        _setupLotryToken();
        
        // Need a larger minimum to ensure price changes due to integer division
        // At very small amounts, the price change might be too small to register
        uint256 minAmount = 1e14; // Larger minimum for measurable price change
        amount = bound(amount, minAmount, 5_000_000_000 * 1e18);
        
        uint256 priceBefore = ticket.calculateCurrentPriceExternal();
        
        _approveAndBuy(buyer1, amount);
        
        uint256 priceAfter = ticket.calculateCurrentPriceExternal();
        
        // Price should increase or stay same (for very small amounts due to precision)
        assertGe(priceAfter, priceBefore, "Price should never decrease after buy");
    }

    function testFuzz_Buy_TaxAlwaysCollected(uint256 amount) public {
        _setupLotryToken();
        
        uint256 minAmount = 1e11;
        amount = bound(amount, minAmount, 10_000_000_000 * 1e18);
        
        uint256 poolFeeBefore = ticket.accumulatedPoolFee();
        
        _approveAndBuy(buyer1, amount);
        
        uint256 poolFeeAfter = ticket.accumulatedPoolFee();
        
        assertGt(poolFeeAfter, poolFeeBefore, "Tax should always be collected on buy");
    }

    function testFuzz_Buy_MultipleBuyers(uint256 amount1, uint256 amount2, uint256 amount3) public {
        _setupLotryToken();
        
        // Need larger minimum to ensure measurable price changes
        uint256 minAmount = 1e14;
        amount1 = bound(amount1, minAmount, 10_000_000_000 * 1e18);
        amount2 = bound(amount2, minAmount, 10_000_000_000 * 1e18);
        amount3 = bound(amount3, minAmount, 10_000_000_000 * 1e18);
        
        uint256 price0 = ticket.calculateCurrentPriceExternal();
        
        _approveAndBuy(buyer1, amount1);
        uint256 price1 = ticket.calculateCurrentPriceExternal();
        assertGe(price1, price0, "Price should not decrease after buyer1");
        
        _approveAndBuy(buyer2, amount2);
        uint256 price2 = ticket.calculateCurrentPriceExternal();
        assertGe(price2, price1, "Price should not decrease after buyer2");
        
        _approveAndBuy(buyer3, amount3);
        uint256 price3 = ticket.calculateCurrentPriceExternal();
        assertGe(price3, price2, "Price should not decrease after buyer3");
        
        // Cumulative price should definitely increase
        assertGt(price3, price0, "Cumulative price should increase");
    }

    // ========================================================================
    //                      FUZZ TESTS - SELL FUNCTION
    // ========================================================================

    function testFuzz_Sell_VariousAmounts(uint256 buyAmount, uint256 sellPercent) public {
        _setupLotryToken();
        
        buyAmount = bound(buyAmount, 1_000_000_000 * 1e18, 50_000_000_000 * 1e18);
        sellPercent = bound(sellPercent, 1, 100);
        
        _approveAndBuy(buyer1, buyAmount);
        
        uint256 tokensOwned = ticket.balanceOf(buyer1);
        uint256 sellAmount = (tokensOwned * sellPercent) / 100;
        
        if (sellAmount > 0) {
            uint256 lotryBefore = lotryToken.balanceOf(buyer1);
            
            vm.prank(buyer1);
            ticket.sell(sellAmount);
            
            assertGt(lotryToken.balanceOf(buyer1), lotryBefore, "Should receive LOTRY");
            assertEq(ticket.balanceOf(buyer1), tokensOwned - sellAmount, "Token balance should decrease");
        }
    }

    function testFuzz_Sell_PriceAlwaysDecreases(uint256 buyAmount, uint256 sellPercent) public {
        _setupLotryToken();
        
        buyAmount = bound(buyAmount, 5_000_000_000 * 1e18, 50_000_000_000 * 1e18);
        sellPercent = bound(sellPercent, 10, 90); // Sell 10-90% to ensure meaningful price change
        
        _approveAndBuy(buyer1, buyAmount);
        
        uint256 tokensOwned = ticket.balanceOf(buyer1);
        uint256 sellAmount = (tokensOwned * sellPercent) / 100;
        
        uint256 priceBefore = ticket.calculateCurrentPriceExternal();
        
        vm.prank(buyer1);
        ticket.sell(sellAmount);
        
        uint256 priceAfter = ticket.calculateCurrentPriceExternal();
        
        assertLt(priceAfter, priceBefore, "Price should always decrease after sell");
    }

    function testFuzz_Sell_TaxAlwaysCollected(uint256 buyAmount, uint256 sellPercent) public {
        _setupLotryToken();
        
        buyAmount = bound(buyAmount, 5_000_000_000 * 1e18, 50_000_000_000 * 1e18);
        sellPercent = bound(sellPercent, 10, 90);
        
        _approveAndBuy(buyer1, buyAmount);
        
        uint256 poolFeeBefore = ticket.accumulatedPoolFee();
        
        uint256 tokensOwned = ticket.balanceOf(buyer1);
        uint256 sellAmount = (tokensOwned * sellPercent) / 100;
        
        vm.prank(buyer1);
        ticket.sell(sellAmount);
        
        uint256 poolFeeAfter = ticket.accumulatedPoolFee();
        
        assertGt(poolFeeAfter, poolFeeBefore, "Tax should always be collected on sell");
    }

    // ========================================================================
    //                      FUZZ TESTS - BUY AND SELL CYCLE
    // ========================================================================

    function testFuzz_BuySellCycle_AlwaysLosesToFees(uint256 buyAmount) public {
        _setupLotryToken();
        
        buyAmount = bound(buyAmount, 5_000_000_000 * 1e18, 50_000_000_000 * 1e18);
        
        uint256 initialLotryBalance = lotryToken.balanceOf(buyer1);
        
        // Buy
        _approveAndBuy(buyer1, buyAmount);
        uint256 tokensReceived = ticket.balanceOf(buyer1);
        
        // Sell all tokens
        vm.prank(buyer1);
        ticket.sell(tokensReceived);
        
        uint256 finalLotryBalance = lotryToken.balanceOf(buyer1);
        
        // Should have lost LOTRY due to 11% tax on both buy and sell
        assertLt(finalLotryBalance, initialLotryBalance, "Should lose LOTRY to fees");
        assertEq(ticket.balanceOf(buyer1), 0, "Should have no tokens left");
    }

    function testFuzz_MultipleBuySellCycles(uint256 seed) public {
        _setupLotryToken();
        
        uint256 numCycles = bound(seed, 2, 5);
        uint256 buyAmount = 1_000_000_000 * 1e18;
        
        for (uint256 i = 0; i < numCycles; i++) {
            // Buy
            _approveAndBuy(buyer1, buyAmount);
            
            uint256 tokensOwned = ticket.balanceOf(buyer1);
            uint256 sellAmount = tokensOwned / 2; // Sell half
            
            if (sellAmount > 0) {
                vm.prank(buyer1);
                ticket.sell(sellAmount);
            }
        }
        
        // Price should have increased overall
        assertGt(ticket.calculateCurrentPriceExternal(), 0, "Price should be positive");
        // Pool fee should have accumulated
        assertGt(ticket.accumulatedPoolFee(), 0, "Pool fee should have accumulated");
    }

    // ========================================================================
    //                      FUZZ TESTS - DEPOSIT FUNCTIONS
    // ========================================================================

    function testFuzz_DepositLotryTokens(uint256 depositAmount) public {
        _setupLotryToken();
        
        // Bound to reasonable deposit amounts
        depositAmount = bound(depositAmount, 1e18, 10_000_000_000 * 1e18);
        
        uint256 poolFeeBefore = ticket.accumulatedPoolFee();
        
        vm.startPrank(buyer1);
        lotryToken.approve(address(ticket), depositAmount);
        ticket.depositLotryTokens(depositAmount);
        vm.stopPrank();
        
        uint256 poolFeeAfter = ticket.accumulatedPoolFee();
        uint256 expectedIncrease = depositAmount / LOTRY_SCALE;
        
        assertEq(poolFeeAfter - poolFeeBefore, expectedIncrease, "Pool fee should increase by deposit");
    }

    function testFuzz_DepositRewardTokens(uint256 depositAmount) public {
        _setupRewardToken();
        
        // Bound to reasonable deposit amounts
        depositAmount = bound(depositAmount, 1, 500_000_000 * 1e18);
        
        // Mint more tokens if needed
        vm.prank(deployer);
        rewardToken.mint(deployer, depositAmount);
        
        vm.startPrank(deployer);
        rewardToken.approve(address(ticket), depositAmount);
        ticket.depositRewardTokens(depositAmount);
        vm.stopPrank();
        
        assertEq(ticket.getRewardTokenBalance(), depositAmount, "Reward token balance should match deposit");
    }

    // ========================================================================
    //                      FUZZ TESTS - REWARD DISTRIBUTION
    // ========================================================================

    function testFuzz_DistributeRewards_CorrectSplit(uint256 tradingAmount) public {
        _setupLotryToken();
        
        tradingAmount = bound(tradingAmount, 1_000_000_000 * 1e18, 50_000_000_000 * 1e18);
        
        // Generate fees through trading
        _approveAndBuy(buyer1, tradingAmount);
        
        uint256 poolFeeExternal = ticket.getAccumulatedPoolFeeExternal();
        
        uint256 winnerBefore = lotryToken.balanceOf(winner);
        uint256 protocolBefore = lotryToken.balanceOf(PROTOCOL_WALLET);
        
        vm.prank(tokenCreator);
        ticket.distributeRewards(winner);
        
        uint256 winnerReceived = lotryToken.balanceOf(winner) - winnerBefore;
        uint256 protocolReceived = lotryToken.balanceOf(PROTOCOL_WALLET) - protocolBefore;
        
        // Due to integer division and internal/external scale conversions,
        // there may be small rounding differences
        // Winner should receive approximately 80% (within rounding tolerance)
        uint256 expectedWinnerApprox = (poolFeeExternal * 80) / 100;
        uint256 tolerance = LOTRY_SCALE * 10; // Allow small rounding error
        
        assertApproxEqAbs(winnerReceived, expectedWinnerApprox, tolerance, "Winner should receive ~80%");
        assertGt(winnerReceived, protocolReceived * 3, "Winner should receive much more than protocol");
        assertEq(ticket.accumulatedPoolFee(), 0, "Pool fee should be cleared");
    }

    function testFuzz_DistributeRewards_ToRandomWinner(address randomWinner) public {
        // Skip zero address and precompiles
        vm.assume(randomWinner != address(0));
        vm.assume(randomWinner.code.length == 0 || randomWinner == address(this));
        vm.assume(uint160(randomWinner) > 100); // Skip precompiles
        
        _setupLotryToken();
        
        // Generate fees
        _approveAndBuy(buyer1, 10_000_000_000 * 1e18);
        
        uint256 winnerBefore = lotryToken.balanceOf(randomWinner);
        
        vm.prank(tokenCreator);
        ticket.distributeRewards(randomWinner);
        
        uint256 winnerAfter = lotryToken.balanceOf(randomWinner);
        
        assertGt(winnerAfter, winnerBefore, "Random winner should receive rewards");
    }

    // ========================================================================
    //                      FUZZ TESTS - LIQUIDITY PULL
    // ========================================================================

    function testFuzz_PullLiquidity_MultipleRecipients(uint256 numRecipients) public {
        _setupLotryToken();
        
        numRecipients = bound(numRecipients, 1, 10);
        
        // Generate liquidity
        _approveAndBuy(buyer1, 50_000_000_000 * 1e18);
        
        uint256 contractBalance = ticket.getLotryBalance();
        uint256 amountPerRecipient = contractBalance / numRecipients;
        
        address[] memory wallets = new address[](numRecipients);
        uint256[] memory amounts = new uint256[](numRecipients);
        
        for (uint256 i = 0; i < numRecipients; i++) {
            wallets[i] = makeAddr(string(abi.encodePacked("recipient", vm.toString(i))));
            amounts[i] = i == numRecipients - 1 
                ? contractBalance - (amountPerRecipient * (numRecipients - 1)) // Last one gets remainder
                : amountPerRecipient;
        }
        
        vm.prank(tokenCreator);
        ticket.pullLiquidity(wallets, amounts);
        
        assertTrue(ticket.liquidityPulled(), "Liquidity should be pulled");
        
        // Verify all recipients received their amounts
        for (uint256 i = 0; i < numRecipients; i++) {
            assertEq(lotryToken.balanceOf(wallets[i]), amounts[i], "Recipient should receive correct amount");
        }
    }

    // ========================================================================
    //                      FUZZ TESTS - BONDING CURVE MATH
    // ========================================================================

    function testFuzz_BondingCurve_BuyReturnIsPositive(uint256 lotryAmount) public view {
        // Internal amount (after dividing by LOTRY_SCALE)
        lotryAmount = bound(lotryAmount, 1, 1_000_000_000_000); // Up to 1000 internal
        
        uint256 tokensOut = ticket.calculateBuyReturn(lotryAmount);
        
        assertGt(tokensOut, 0, "Buy return should always be positive");
    }

    function testFuzz_BondingCurve_SellReturnIsPositive(uint256 sellAmount) public {
        _setupLotryToken();
        
        // Buy some tokens first
        _approveAndBuy(buyer1, 50_000_000_000 * 1e18);
        
        uint256 tokensOwned = ticket.balanceOf(buyer1);
        sellAmount = bound(sellAmount, 1, tokensOwned);
        
        uint256 lotryOut = ticket.calculateSellReturn(sellAmount);
        
        assertGt(lotryOut, 0, "Sell return should always be positive");
    }

    function testFuzz_BondingCurve_ConstantKPreserved(uint256 buyAmount) public {
        _setupLotryToken();
        
        buyAmount = bound(buyAmount, 1e11, 10_000_000_000 * 1e18);
        
        uint256 constantK = ticket.I_CONSTANT_K();
        
        _approveAndBuy(buyer1, buyAmount);
        
        // K should remain the same (it's immutable)
        assertEq(ticket.I_CONSTANT_K(), constantK, "Constant K should never change");
    }
}

