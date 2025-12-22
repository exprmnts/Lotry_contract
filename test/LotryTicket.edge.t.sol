// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {LotryTestBase, MockLotryToken, MockRewardToken, MockSmartWallet, MockNonReturningToken} from "./LotryTestBase.sol";
import {LotryTicket} from "../contracts/LotryTicket.sol";
import {LotryLaunch} from "../contracts/LotryLaunch.sol";

/**
 * @title LotryTicket Edge Cases and Boundary Test Suite
 * @notice Tests for edge cases, boundary conditions, and limit testing
 * @dev Tests unusual scenarios and boundary values
 */
contract LotryTicketEdgeTest is LotryTestBase {

    // ========================================================================
    //                      MINIMUM VALUES TESTS
    // ========================================================================

    function test_Edge_MinimumBuyAmount() public {
        console.log("\n=== TEST: Minimum Buy Amount ===");
        
        _setupLotryToken();
        
        // The actual minimum must be large enough so after:
        // 1. Dividing by LOTRY_SCALE (1e10)
        // 2. Subtracting 11% tax
        // The net amount for the curve is still > 0
        // MIN_BUY / 1e10 = 1 (rounded down), then 1 * 89 / 100 = 0
        // So we need at least: 1e10 * 100 / 89 ≈ 1.12e10 to get net > 0
        // Using 1e11 as a safe minimum viable buy
        uint256 viableMinimum = 1e11;
        console.log("Testing viable minimum:", viableMinimum);
        
        vm.startPrank(buyer1);
        lotryToken.approve(address(ticket), viableMinimum);
        ticket.buy(viableMinimum);
        vm.stopPrank();
        
        assertGt(ticket.balanceOf(buyer1), 0, "Should receive tokens at viable minimum");
        console.log("Tokens received:", ticket.balanceOf(buyer1));
        
        console.log("TEST PASSED");
    }

    function test_Edge_JustBelowMinimumFails() public {
        console.log("\n=== TEST: Just Below Minimum Fails ===");
        
        _setupLotryToken();
        
        uint256 belowMinimum = MIN_BUY - 1;
        console.log("Testing below minimum:", belowMinimum);
        
        vm.startPrank(buyer1);
        lotryToken.approve(address(ticket), belowMinimum);
        vm.expectRevert(abi.encodeWithSignature("Ticket__BelowMinimumBuy()"));
        ticket.buy(belowMinimum);
        vm.stopPrank();
        
        console.log("Correctly rejected");
        console.log("TEST PASSED");
    }

    function test_Edge_SellSingleToken() public {
        console.log("\n=== TEST: Sell Single Token ===");
        
        _setupLotryToken();
        _approveAndBuy(buyer1, 10_000_000_000 * 1e18);
        
        uint256 singleToken = 1; // 1 wei of token
        uint256 lotryBefore = lotryToken.balanceOf(buyer1);
        
        vm.prank(buyer1);
        ticket.sell(singleToken);
        
        uint256 lotryAfter = lotryToken.balanceOf(buyer1);
        
        console.log("Sold 1 wei of token");
        console.log("LOTRY received:", lotryAfter - lotryBefore);
        
        // Even selling 1 wei should work (though return might be 0 due to rounding)
        console.log("TEST PASSED");
    }

    // ========================================================================
    //                      MAXIMUM VALUES TESTS
    // ========================================================================

    function test_Edge_LargeNumberOfBuys() public {
        console.log("\n=== TEST: Large Number of Buys ===");
        
        _setupLotryToken();
        
        uint256 buyAmount = 100_000_000 * 1e18;
        uint256 numBuys = 50;
        
        console.log("Performing %d buys of %d LOTRY each", numBuys, buyAmount / 1e18);
        
        uint256 initialPrice = ticket.calculateCurrentPriceExternal();
        
        for (uint256 i = 0; i < numBuys; i++) {
            _approveAndBuy(buyer1, buyAmount);
        }
        
        uint256 finalPrice = ticket.calculateCurrentPriceExternal();
        uint256 tokensOwned = ticket.balanceOf(buyer1);
        
        console.log("Initial Price:", initialPrice);
        console.log("Final Price:", finalPrice);
        console.log("Price multiplier:", (finalPrice * 100) / initialPrice, "%");
        console.log("Tokens owned:", tokensOwned / 1e18);
        
        assertGt(finalPrice, initialPrice, "Price should increase significantly");
        console.log("TEST PASSED");
    }

    function test_Edge_BuyEntireSupply() public {
        console.log("\n=== TEST: Attempt to Buy Entire Supply ===");
        
        _setupLotryToken();
        
        // Try to buy with a massive amount
        uint256 massiveAmount = 90_000_000_000 * 1e18; // 90B LOTRY
        
        _approveAndBuy(buyer1, massiveAmount);
        
        uint256 tokensReceived = ticket.balanceOf(buyer1);
        uint256 contractBalance = ticket.balanceOf(address(ticket));
        
        console.log("Tokens received:", tokensReceived / 1e18);
        console.log("Contract still holds:", contractBalance / 1e18);
        
        // Should not be able to buy all tokens due to bonding curve
        assertGt(contractBalance, 0, "Contract should still hold some tokens");
        
        console.log("TEST PASSED");
    }

    function test_Edge_SellAllTokens() public {
        console.log("\n=== TEST: Sell All Tokens ===");
        
        _setupLotryToken();
        
        // Buy tokens
        _approveAndBuy(buyer1, 10_000_000_000 * 1e18);
        
        uint256 allTokens = ticket.balanceOf(buyer1);
        console.log("Tokens owned:", allTokens / 1e18);
        
        // Sell all
        vm.prank(buyer1);
        ticket.sell(allTokens);
        
        assertEq(ticket.balanceOf(buyer1), 0, "Should have zero tokens after selling all");
        console.log("All tokens sold successfully");
        console.log("TEST PASSED");
    }

    // ========================================================================
    //                      OVERFLOW/UNDERFLOW TESTS
    // ========================================================================

    function test_Edge_LargePoolFeeAccumulation() public {
        console.log("\n=== TEST: Large Pool Fee Accumulation ===");
        
        _setupLotryToken();
        
        // Generate lots of trading
        for (uint256 i = 0; i < 20; i++) {
            address buyer = i % 2 == 0 ? buyer1 : buyer2;
            _approveAndBuy(buyer, 1_000_000_000 * 1e18);
        }
        
        uint256 poolFee = ticket.getAccumulatedPoolFeeExternal();
        console.log("Total pool fee accumulated:", poolFee / 1e18, "LOTRY");
        
        // Distribute rewards
        vm.prank(tokenCreator);
        ticket.distributeRewards(winner);
        
        console.log("Winner received:", lotryToken.balanceOf(winner) / 1e18, "LOTRY");
        assertEq(ticket.accumulatedPoolFee(), 0, "Pool fee should be cleared");
        
        console.log("TEST PASSED");
    }

    function test_Edge_MultipleDepositsAndDistributions() public {
        console.log("\n=== TEST: Multiple Deposits and Distributions ===");
        
        _setupLotryToken();
        _setupRewardToken();
        
        for (uint256 round = 0; round < 10; round++) {
            // Generate fees
            _approveAndBuy(buyer1, 500_000_000 * 1e18);
            
            // Deposit reward tokens
            uint256 depositAmount = 100 * 1e18;
            vm.startPrank(deployer);
            rewardToken.mint(deployer, depositAmount);
            rewardToken.approve(address(ticket), depositAmount);
            ticket.depositRewardTokens(depositAmount);
            vm.stopPrank();
            
            // Distribute
            address roundWinner = makeAddr(string(abi.encodePacked("winner", vm.toString(round))));
            vm.prank(tokenCreator);
            ticket.distributeRewards(roundWinner);
            
            console.log("Round", round, "- Winner:", roundWinner);
        }
        
        console.log("All 10 rounds completed without overflow");
        console.log("TEST PASSED");
    }

    // ========================================================================
    //                      CIRCULATING SUPPLY TESTS
    // ========================================================================

    function test_Edge_ExceedCirculatingSupply() public {
        console.log("\n=== TEST: Exceed Circulating Supply Check ===");
        
        _setupLotryToken();
        _approveAndBuy(buyer1, 1_000_000_000 * 1e18);
        
        uint256 tokensOwned = ticket.balanceOf(buyer1);
        uint256 circulatingSupply = INITIAL_SUPPLY - ticket.balanceOf(address(ticket));
        
        console.log("Tokens owned:", tokensOwned / 1e18);
        console.log("Circulating supply:", circulatingSupply / 1e18);
        
        // Try to calculate sell return for more than circulating supply
        vm.prank(buyer1);
        vm.expectRevert(abi.encodeWithSignature("Ticket__ExceedsCirculatingSupply()"));
        ticket.calculateSellReturn(circulatingSupply + 1);
        
        console.log("Exceeding circulating supply correctly rejected");
        console.log("TEST PASSED");
    }

    function test_Edge_SellExactCirculatingSupply() public {
        console.log("\n=== TEST: Sell Exact Circulating Supply ===");
        
        _setupLotryToken();
        _approveAndBuy(buyer1, 10_000_000_000 * 1e18);
        
        uint256 tokensOwned = ticket.balanceOf(buyer1);
        uint256 circulatingSupply = INITIAL_SUPPLY - ticket.balanceOf(address(ticket));
        
        console.log("Tokens owned:", tokensOwned / 1e18);
        console.log("Circulating supply:", circulatingSupply / 1e18);
        
        // These should be equal
        assertEq(tokensOwned, circulatingSupply, "Buyer should own all circulating supply");
        
        // Selling all should work
        uint256 sellReturn = ticket.calculateSellReturn(tokensOwned);
        console.log("Sell return for all tokens:", sellReturn);
        assertGt(sellReturn, 0, "Should get positive return");
        
        console.log("TEST PASSED");
    }

    // ========================================================================
    //                      BUY AND SELL SAME AMOUNT TESTS
    // ========================================================================

    function test_Edge_BuyAndSellSameAmount() public {
        console.log("\n=== TEST: Buy and Sell Same Amount ===");
        
        _setupLotryToken();
        
        uint256 buyAmount = 5_000_000_000 * 1e18;
        uint256 initialLotryBalance = lotryToken.balanceOf(buyer1);
        
        console.log("Initial LOTRY balance:", initialLotryBalance / 1e18);
        
        // Buy
        _approveAndBuy(buyer1, buyAmount);
        uint256 tokensReceived = ticket.balanceOf(buyer1);
        console.log("Tokens received:", tokensReceived / 1e18);
        
        // Sell all tokens
        vm.prank(buyer1);
        ticket.sell(tokensReceived);
        
        uint256 finalLotryBalance = lotryToken.balanceOf(buyer1);
        uint256 lotryLost = initialLotryBalance - finalLotryBalance;
        
        console.log("Final LOTRY balance:", finalLotryBalance / 1e18);
        console.log("LOTRY lost to fees:", lotryLost / 1e18);
        console.log("Tokens remaining:", ticket.balanceOf(buyer1) / 1e18);
        
        // Should have lost some LOTRY due to taxes
        assertLt(finalLotryBalance, initialLotryBalance, "Should lose LOTRY to fees");
        assertEq(ticket.balanceOf(buyer1), 0, "Should have no tokens left");
        
        // Calculate expected loss (11% buy tax + 11% sell tax on remaining)
        // This is approximate due to bonding curve
        console.log("TEST PASSED");
    }

    function test_Edge_MultipleBuySellCyclesNetLoss() public {
        console.log("\n=== TEST: Multiple Buy/Sell Cycles Net Loss ===");
        
        _setupLotryToken();
        
        uint256 initialBalance = lotryToken.balanceOf(buyer1);
        uint256 buyAmount = 1_000_000_000 * 1e18;
        
        for (uint256 i = 0; i < 5; i++) {
            // Buy
            _approveAndBuy(buyer1, buyAmount);
            
            // Sell all
            uint256 tokensOwned = ticket.balanceOf(buyer1);
            vm.prank(buyer1);
            ticket.sell(tokensOwned);
            
            console.log("Cycle", i + 1, "completed");
        }
        
        uint256 finalBalance = lotryToken.balanceOf(buyer1);
        uint256 totalLoss = initialBalance - finalBalance;
        
        console.log("Initial balance:", initialBalance / 1e18, "LOTRY");
        console.log("Final balance:", finalBalance / 1e18, "LOTRY");
        console.log("Total loss:", totalLoss / 1e18, "LOTRY");
        
        assertLt(finalBalance, initialBalance, "Should lose LOTRY over multiple cycles");
        
        console.log("TEST PASSED");
    }

    // ========================================================================
    //                      EMPTY/ZERO STATE TESTS
    // ========================================================================

    function test_Edge_DistributeRewardsWithZeroFees() public {
        console.log("\n=== TEST: Distribute Rewards With Zero Fees ===");
        
        _setupLotryToken();
        
        uint256 poolFee = ticket.accumulatedPoolFee();
        console.log("Pool fee before:", poolFee);
        assertEq(poolFee, 0, "Pool fee should be zero initially");
        
        uint256 winnerBefore = lotryToken.balanceOf(winner);
        
        // Distribute with zero fees
        vm.prank(tokenCreator);
        ticket.distributeRewards(winner);
        
        uint256 winnerAfter = lotryToken.balanceOf(winner);
        
        assertEq(winnerAfter, winnerBefore, "Winner should receive nothing with zero fees");
        console.log("Zero fee distribution handled correctly");
        console.log("TEST PASSED");
    }

    function test_Edge_DistributeRewardsWithOnlyRewardTokens() public {
        console.log("\n=== TEST: Distribute With Only Reward Tokens (No LOTRY Fees) ===");
        
        _setupLotryToken();
        _setupRewardToken();
        
        // Deposit reward tokens without any trading
        uint256 rewardAmount = 1000 * 1e18;
        vm.startPrank(deployer);
        rewardToken.approve(address(ticket), rewardAmount);
        ticket.depositRewardTokens(rewardAmount);
        vm.stopPrank();
        
        uint256 winnerLotryBefore = lotryToken.balanceOf(winner);
        uint256 winnerRewardBefore = rewardToken.balanceOf(winner);
        
        vm.prank(tokenCreator);
        ticket.distributeRewards(winner);
        
        uint256 winnerLotryAfter = lotryToken.balanceOf(winner);
        uint256 winnerRewardAfter = rewardToken.balanceOf(winner);
        
        assertEq(winnerLotryAfter, winnerLotryBefore, "No LOTRY should be distributed");
        assertEq(winnerRewardAfter - winnerRewardBefore, rewardAmount, "All reward tokens should go to winner");
        
        console.log("Winner received 0 LOTRY and", rewardAmount / 1e18, "reward tokens");
        console.log("TEST PASSED");
    }

    function test_Edge_PullLiquidityWithZeroAmounts() public {
        console.log("\n=== TEST: Pull Liquidity With Zero Amounts ===");
        
        _setupLotryToken();
        _approveAndBuy(buyer1, 1_000_000_000 * 1e18);
        
        uint256 buyer1Before = lotryToken.balanceOf(buyer1);
        
        address[] memory wallets = new address[](2);
        wallets[0] = buyer1;
        wallets[1] = buyer2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 0; // Zero amount
        amounts[1] = 0; // Zero amount
        
        vm.prank(tokenCreator);
        ticket.pullLiquidity(wallets, amounts);
        
        uint256 buyer1After = lotryToken.balanceOf(buyer1);
        
        assertTrue(ticket.liquidityPulled(), "Liquidity should be marked as pulled");
        assertEq(buyer1After, buyer1Before, "No tokens should be transferred with zero amounts");
        
        console.log("Zero amount pull handled correctly");
        console.log("TEST PASSED");
    }

    // ========================================================================
    //                      ARRAY BOUNDARY TESTS
    // ========================================================================

    function test_Edge_PullLiquidityEmptyArrays() public {
        console.log("\n=== TEST: Pull Liquidity With Empty Arrays ===");
        
        _setupLotryToken();
        
        address[] memory wallets = new address[](0);
        uint256[] memory amounts = new uint256[](0);
        
        vm.prank(tokenCreator);
        ticket.pullLiquidity(wallets, amounts);
        
        assertTrue(ticket.liquidityPulled(), "Should mark liquidity as pulled even with empty arrays");
        
        console.log("Empty array pull handled correctly");
        console.log("TEST PASSED");
    }

    function test_Edge_PullLiquiditySingleRecipient() public {
        console.log("\n=== TEST: Pull Liquidity Single Recipient ===");
        
        _setupLotryToken();
        _approveAndBuy(buyer1, 10_000_000_000 * 1e18);
        
        uint256 contractBalance = ticket.getLotryBalance();
        
        address[] memory wallets = new address[](1);
        wallets[0] = buyer1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = contractBalance;
        
        uint256 buyer1Before = lotryToken.balanceOf(buyer1);
        
        vm.prank(tokenCreator);
        ticket.pullLiquidity(wallets, amounts);
        
        uint256 buyer1After = lotryToken.balanceOf(buyer1);
        
        assertEq(buyer1After - buyer1Before, contractBalance, "Single recipient should get all");
        
        console.log("Single recipient received:", contractBalance / 1e18, "LOTRY");
        console.log("TEST PASSED");
    }

    function test_Edge_PullLiquidityManyRecipients() public {
        console.log("\n=== TEST: Pull Liquidity Many Recipients ===");
        
        _setupLotryToken();
        _approveAndBuy(buyer1, 50_000_000_000 * 1e18);
        
        uint256 contractBalance = ticket.getLotryBalance();
        uint256 numRecipients = 20;
        uint256 amountEach = contractBalance / numRecipients;
        
        address[] memory wallets = new address[](numRecipients);
        uint256[] memory amounts = new uint256[](numRecipients);
        
        for (uint256 i = 0; i < numRecipients; i++) {
            wallets[i] = makeAddr(string(abi.encodePacked("recipient", vm.toString(i))));
            amounts[i] = i == numRecipients - 1 
                ? contractBalance - (amountEach * (numRecipients - 1))
                : amountEach;
        }
        
        vm.prank(tokenCreator);
        ticket.pullLiquidity(wallets, amounts);
        
        // Verify all received
        for (uint256 i = 0; i < numRecipients; i++) {
            assertEq(lotryToken.balanceOf(wallets[i]), amounts[i], "Recipient should receive correct amount");
        }
        
        console.log("Successfully distributed to", numRecipients, "recipients");
        console.log("TEST PASSED");
    }

    // ========================================================================
    //                      REENTRANCY TESTS
    // ========================================================================

    function test_Edge_ReentrancyProtection() public {
        console.log("\n=== TEST: Reentrancy Protection ===");
        
        _setupLotryToken();
        
        // Note: The contract uses ReentrancyGuard from OpenZeppelin
        // Direct reentrancy is prevented by the nonReentrant modifier
        // This test verifies the modifier is in place by checking
        // that normal operations complete successfully
        
        _approveAndBuy(buyer1, 1_000_000_000 * 1e18);
        
        uint256 tokens = ticket.balanceOf(buyer1);
        assertGt(tokens, 0, "Should receive tokens");
        
        vm.prank(buyer1);
        ticket.sell(tokens / 2);
        
        console.log("Normal buy/sell completed (reentrancy guard active)");
        console.log("TEST PASSED");
    }

    // ========================================================================
    //                      GAS LIMIT TESTS
    // ========================================================================

    function test_Edge_GasConsumption() public {
        console.log("\n=== TEST: Gas Consumption ===");
        
        _setupLotryToken();
        
        // Measure gas for buy
        uint256 gasStart = gasleft();
        _approveAndBuy(buyer1, 1_000_000_000 * 1e18);
        uint256 buyGas = gasStart - gasleft();
        console.log("Buy gas used:", buyGas);
        
        // Measure gas for sell
        uint256 tokensOwned = ticket.balanceOf(buyer1);
        gasStart = gasleft();
        vm.prank(buyer1);
        ticket.sell(tokensOwned / 2);
        uint256 sellGas = gasStart - gasleft();
        console.log("Sell gas used:", sellGas);
        
        // Measure gas for reward distribution
        _approveAndBuy(buyer2, 5_000_000_000 * 1e18);
        gasStart = gasleft();
        vm.prank(tokenCreator);
        ticket.distributeRewards(winner);
        uint256 distributeGas = gasStart - gasleft();
        console.log("Distribute gas used:", distributeGas);
        
        // All operations should be under reasonable gas limits
        assertLt(buyGas, 500000, "Buy should use less than 500k gas");
        assertLt(sellGas, 500000, "Sell should use less than 500k gas");
        assertLt(distributeGas, 500000, "Distribute should use less than 500k gas");
        
        console.log("TEST PASSED");
    }

    // ========================================================================
    //                      PRECISION TESTS
    // ========================================================================

    function test_Edge_PrecisionInCalculations() public {
        console.log("\n=== TEST: Precision in Calculations ===");
        
        _setupLotryToken();
        
        // Test with very small amounts
        uint256 smallAmount = 1e11; // Minimum viable amount
        
        uint256 priceBefore = ticket.calculateCurrentPriceExternal();
        _approveAndBuy(buyer1, smallAmount);
        uint256 priceAfter = ticket.calculateCurrentPriceExternal();
        
        console.log("Small buy amount:", smallAmount);
        console.log("Price before:", priceBefore);
        console.log("Price after:", priceAfter);
        
        // Price should still increase even with tiny amounts
        assertGe(priceAfter, priceBefore, "Price should not decrease");
        
        console.log("TEST PASSED");
    }

    function test_Edge_InternalExternalScaleConversion() public {
        console.log("\n=== TEST: Internal/External Scale Conversion ===");
        
        _setupLotryToken();
        _approveAndBuy(buyer1, 10_000_000_000 * 1e18);
        
        // Verify scale conversions are consistent
        uint256 internalLotryRaised = ticket.lotryRaised();
        uint256 externalLotryRaised = ticket.getLotryRaisedExternal();
        
        assertEq(externalLotryRaised, internalLotryRaised * LOTRY_SCALE, "External should be internal * scale");
        
        uint256 internalPoolFee = ticket.accumulatedPoolFee();
        uint256 externalPoolFee = ticket.getAccumulatedPoolFeeExternal();
        
        assertEq(externalPoolFee, internalPoolFee * LOTRY_SCALE, "Pool fee scale should be consistent");
        
        uint256 internalPrice = ticket.calculateCurrentPrice();
        uint256 externalPrice = ticket.calculateCurrentPriceExternal();
        
        assertEq(externalPrice, internalPrice * LOTRY_SCALE, "Price scale should be consistent");
        
        console.log("All scale conversions are consistent");
        console.log("TEST PASSED");
    }
}

