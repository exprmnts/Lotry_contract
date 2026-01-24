// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {LotryTestBase, MockLotryToken, MockRewardToken, MockSmartWallet} from "./LotryTestBase.sol";
import {LotryTicket} from "../contracts/LotryTicket.sol";
import {LotryLaunch} from "../contracts/LotryLaunch.sol";

/**
 * @title LotryTicket Integration Test Suite
 * @notice End-to-end integration tests simulating real-world usage
 * @dev Tests complete user flows and system interactions
 */
contract LotryTicketIntegrationTest is LotryTestBase {

    // ========================================================================
    //                      FULL LIFECYCLE SIMULATION
    // ========================================================================

    function test_Integration_FullLifecycle() public {
        console.log("\n=== TEST: Full Lifecycle Simulation ===");
        console.log("========================================");
        
        _setupLotryToken();
        _setupRewardToken();
        
        // Phase 1: Initial buys
        console.log("\n--- Phase 1: Initial Buys ---");
        uint256 buyAmount = 1_000_000_000 * 1e18;
        
        _approveAndBuy(buyer1, buyAmount);
        console.log("Buyer1 bought:", buyAmount / 1e18, "LOTRY worth of tokens");
        console.log("Buyer1 tokens:", ticket.balanceOf(buyer1) / 1e18);
        
        _approveAndBuy(buyer2, buyAmount * 2);
        console.log("Buyer2 bought:", (buyAmount * 2) / 1e18, "LOTRY worth of tokens");
        console.log("Buyer2 tokens:", ticket.balanceOf(buyer2) / 1e18);
        
        console.log("Current Price:", ticket.calculateCurrentPriceExternal());
        console.log("Pool Fee:", ticket.getAccumulatedPoolFeeExternal() / 1e18, "LOTRY");
        
        // Phase 2: Some sells
        console.log("\n--- Phase 2: Some Sells ---");
        uint256 buyer1Tokens = ticket.balanceOf(buyer1);
        vm.prank(buyer1);
        ticket.sell(buyer1Tokens / 2);
        console.log("Buyer1 sold half their tokens");
        console.log("Buyer1 remaining tokens:", ticket.balanceOf(buyer1) / 1e18);
        console.log("Current Price:", ticket.calculateCurrentPriceExternal());
        
        // Phase 3: Deposit reward tokens
        console.log("\n--- Phase 3: Deposit Reward Tokens ---");
        uint256 rewardDeposit = 1000 * 1e18;
        vm.startPrank(deployer);
        rewardToken.approve(address(ticket), rewardDeposit);
        ticket.depositRewardTokens(rewardDeposit);
        vm.stopPrank();
        console.log("Deposited reward tokens:", rewardDeposit / 1e18);
        
        // Phase 4: Distribute rewards
        console.log("\n--- Phase 4: Distribute Rewards ---");
        uint256 winnerLotryBefore = lotryToken.balanceOf(winner);
        uint256 winnerRewardBefore = rewardToken.balanceOf(winner);
        
        vm.prank(tokenCreator);
        ticket.distributeRewards(winner);
        
        console.log("Winner received LOTRY:", (lotryToken.balanceOf(winner) - winnerLotryBefore) / 1e18);
        console.log("Winner received Reward:", (rewardToken.balanceOf(winner) - winnerRewardBefore) / 1e18);
        console.log("Pool fee after distribution:", ticket.getAccumulatedPoolFeeExternal());
        
        // Phase 5: More trading
        console.log("\n--- Phase 5: More Trading ---");
        _approveAndBuy(buyer3, buyAmount * 3);
        console.log("Buyer3 bought:", (buyAmount * 3) / 1e18, "LOTRY worth of tokens");
        console.log("Current Price:", ticket.calculateCurrentPriceExternal());
        console.log("New Pool Fee:", ticket.getAccumulatedPoolFeeExternal() / 1e18, "LOTRY");
        
        // Phase 6: Pull liquidity
        console.log("\n--- Phase 6: Pull Liquidity ---");
        uint256 contractBalance = ticket.getLotryBalance();
        console.log("Contract LOTRY balance:", contractBalance / 1e18);
        
        address[] memory wallets = new address[](2);
        wallets[0] = buyer1;
        wallets[1] = buyer2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = contractBalance / 2;
        amounts[1] = contractBalance / 2;
        
        vm.prank(tokenCreator);
        ticket.pullLiquidity(wallets, amounts);
        
        console.log("Liquidity pulled:", ticket.liquidityPulled());
        console.log("Trading now disabled");
        
        // Verify trading is disabled
        vm.startPrank(buyer3);
        lotryToken.approve(address(ticket), 1e18);
        vm.expectRevert(abi.encodeWithSignature("Ticket__TradingDisabled()"));
        ticket.buy(1e18);
        vm.stopPrank();
        
        console.log("\n========================================");
        console.log("FULL LIFECYCLE SIMULATION COMPLETE");
        console.log("========================================");
        console.log("TEST PASSED");
    }

    // ========================================================================
    //                      MULTI-LOTTERY SIMULATION
    // ========================================================================

    function test_Integration_MultipleLotteries() public {
        console.log("\n=== TEST: Multiple Lotteries Running In Parallel ===");
        
        // Create 3 different lotteries
        vm.startPrank(tokenCreator);
        address lottery1Addr = launchpad.launchToken("Lottery 1", "LOT1");
        address lottery2Addr = launchpad.launchToken("Lottery 2", "LOT2");
        address lottery3Addr = launchpad.launchToken("Lottery 3", "LOT3");
        vm.stopPrank();
        
        LotryTicket lottery1 = LotryTicket(lottery1Addr);
        LotryTicket lottery2 = LotryTicket(lottery2Addr);
        LotryTicket lottery3 = LotryTicket(lottery3Addr);
        
        console.log("Lottery 1:", lottery1Addr);
        console.log("Lottery 2:", lottery2Addr);
        console.log("Lottery 3:", lottery3Addr);
        
        // Set LOTRY token for all lotteries
        vm.startPrank(tokenCreator);
        lottery1.setLotryToken(address(lotryToken));
        lottery2.setLotryToken(address(lotryToken));
        lottery3.setLotryToken(address(lotryToken));
        vm.stopPrank();
        
        // Different buyers participate in different lotteries
        uint256 buyAmount = 1_000_000_000 * 1e18;
        
        // Buyer1 joins lottery1
        vm.startPrank(buyer1);
        lotryToken.approve(lottery1Addr, buyAmount);
        lottery1.buy(buyAmount);
        vm.stopPrank();
        console.log("Buyer1 bought in Lottery 1");
        
        // Buyer2 joins lottery2
        vm.startPrank(buyer2);
        lotryToken.approve(lottery2Addr, buyAmount * 2);
        lottery2.buy(buyAmount * 2);
        vm.stopPrank();
        console.log("Buyer2 bought in Lottery 2");
        
        // Buyer3 joins lottery3
        vm.startPrank(buyer3);
        lotryToken.approve(lottery3Addr, buyAmount * 3);
        lottery3.buy(buyAmount * 3);
        vm.stopPrank();
        console.log("Buyer3 bought in Lottery 3");
        
        // Verify each lottery has independent state
        console.log("\n--- Lottery States ---");
        console.log("Lottery 1 pool fee:", lottery1.getAccumulatedPoolFeeExternal() / 1e18, "LOTRY");
        console.log("Lottery 2 pool fee:", lottery2.getAccumulatedPoolFeeExternal() / 1e18, "LOTRY");
        console.log("Lottery 3 pool fee:", lottery3.getAccumulatedPoolFeeExternal() / 1e18, "LOTRY");
        
        assertGt(lottery1.getAccumulatedPoolFeeExternal(), 0, "Lottery 1 should have fees");
        assertGt(lottery2.getAccumulatedPoolFeeExternal(), 0, "Lottery 2 should have fees");
        assertGt(lottery3.getAccumulatedPoolFeeExternal(), 0, "Lottery 3 should have fees");
        
        // Different winners for each lottery
        address winner1 = makeAddr("winner1");
        address winner2 = makeAddr("winner2");
        address winner3 = makeAddr("winner3");
        
        vm.startPrank(tokenCreator);
        lottery1.distributeRewards(winner1);
        lottery2.distributeRewards(winner2);
        lottery3.distributeRewards(winner3);
        vm.stopPrank();
        
        console.log("\n--- Winners ---");
        console.log("Winner 1 received:", lotryToken.balanceOf(winner1) / 1e18, "LOTRY");
        console.log("Winner 2 received:", lotryToken.balanceOf(winner2) / 1e18, "LOTRY");
        console.log("Winner 3 received:", lotryToken.balanceOf(winner3) / 1e18, "LOTRY");
        
        assertGt(lotryToken.balanceOf(winner1), 0, "Winner 1 should receive rewards");
        assertGt(lotryToken.balanceOf(winner2), 0, "Winner 2 should receive rewards");
        assertGt(lotryToken.balanceOf(winner3), 0, "Winner 3 should receive rewards");
        
        console.log("TEST PASSED");
    }

    // ========================================================================
    //                      HIGH VOLUME TRADING SIMULATION
    // ========================================================================

    function test_Integration_HighVolumeTrading() public {
        console.log("\n=== TEST: High Volume Trading Simulation ===");
        
        _setupLotryToken();
        
        uint256 numTrades = 100;
        uint256 tradeAmount = 100_000_000 * 1e18;
        
        console.log("Executing %d trades of %d LOTRY each", numTrades, tradeAmount / 1e18);
        
        uint256 initialPrice = ticket.calculateCurrentPriceExternal();
        console.log("Initial Price:", initialPrice);
        
        uint256 gasUsedTotal = 0;
        
        for (uint256 i = 0; i < numTrades; i++) {
            address buyer = i % 3 == 0 ? buyer1 : (i % 3 == 1 ? buyer2 : buyer3);
            
            uint256 gasBefore = gasleft();
            _approveAndBuy(buyer, tradeAmount);
            gasUsedTotal += gasBefore - gasleft();
        }
        
        uint256 finalPrice = ticket.calculateCurrentPriceExternal();
        uint256 totalPoolFee = ticket.getAccumulatedPoolFeeExternal();
        
        console.log("Final Price:", finalPrice);
        console.log("Price multiplier:", (finalPrice * 100) / initialPrice, "%");
        console.log("Total Pool Fee:", totalPoolFee / 1e18, "LOTRY");
        console.log("Average gas per trade:", gasUsedTotal / numTrades);
        
        assertGt(finalPrice, initialPrice, "Price should increase significantly");
        assertGt(totalPoolFee, 0, "Pool fee should accumulate");
        
        console.log("TEST PASSED");
    }

    // ========================================================================
    //                      SMART WALLET INTEGRATION
    // ========================================================================

    function test_Integration_SmartWalletFullFlow() public {
        console.log("\n=== TEST: Smart Wallet Full Integration ===");
        
        _setupLotryToken();
        _setupRewardToken();
        
        // Deploy smart wallets for participants
        MockSmartWallet smartBuyer = new MockSmartWallet();
        MockSmartWallet smartWinner = new MockSmartWallet();
        
        console.log("Smart Buyer deployed at:", address(smartBuyer));
        console.log("Smart Winner deployed at:", address(smartWinner));
        
        // Fund smart buyer with LOTRY tokens
        vm.prank(deployer);
        lotryToken.transfer(address(smartBuyer), 50_000_000_000 * 1e18);
        console.log("Smart Buyer funded with LOTRY");
        
        // Smart buyer approves and buys (simulating Safe transaction)
        // Note: In real world, this would be done through the smart wallet's execute function
        // For testing, we simulate the smart wallet making the call directly
        vm.startPrank(address(smartBuyer));
        lotryToken.approve(address(ticket), 10_000_000_000 * 1e18);
        ticket.buy(10_000_000_000 * 1e18);
        vm.stopPrank();
        
        uint256 smartBuyerTokens = ticket.balanceOf(address(smartBuyer));
        console.log("Smart Buyer received tokens:", smartBuyerTokens / 1e18);
        assertGt(smartBuyerTokens, 0, "Smart buyer should receive tokens");
        
        // Regular buyers also participate
        _approveAndBuy(buyer1, 5_000_000_000 * 1e18);
        _approveAndBuy(buyer2, 5_000_000_000 * 1e18);
        
        // Add reward tokens
        uint256 rewardAmount = 2000 * 1e18;
        vm.startPrank(deployer);
        rewardToken.approve(address(ticket), rewardAmount);
        ticket.depositRewardTokens(rewardAmount);
        vm.stopPrank();
        
        // Smart wallet wins the lottery
        uint256 poolFee = ticket.getAccumulatedPoolFeeExternal();
        console.log("Pool Fee before distribution:", poolFee / 1e18, "LOTRY");
        
        vm.prank(tokenCreator);
        ticket.distributeRewards(address(smartWinner));
        
        uint256 smartWinnerLotry = lotryToken.balanceOf(address(smartWinner));
        uint256 smartWinnerReward = rewardToken.balanceOf(address(smartWinner));
        
        console.log("Smart Winner received LOTRY:", smartWinnerLotry / 1e18);
        console.log("Smart Winner received Reward:", smartWinnerReward / 1e18);
        
        assertGt(smartWinnerLotry, 0, "Smart winner should receive LOTRY");
        assertEq(smartWinnerReward, rewardAmount, "Smart winner should receive all reward tokens");
        
        // Verify smart winner can access funds
        assertEq(smartWinner.getTokenBalance(address(lotryToken)), smartWinnerLotry, "Smart winner should access LOTRY");
        assertEq(smartWinner.getTokenBalance(address(rewardToken)), smartWinnerReward, "Smart winner should access rewards");
        
        console.log("TEST PASSED");
    }

    // ========================================================================
    //                      COMPLETE LOTTERY ROUND
    // ========================================================================

    function test_Integration_CompleteLotteryRound() public {
        console.log("\n=== TEST: Complete Lottery Round ===");
        
        _setupLotryToken();
        _setupRewardToken();
        
        // Step 1: Multiple users buy tickets
        console.log("\n--- Step 1: Ticket Sales ---");
        
        address[] memory participants = new address[](5);
        participants[0] = buyer1;
        participants[1] = buyer2;
        participants[2] = buyer3;
        participants[3] = makeAddr("participant4");
        participants[4] = makeAddr("participant5");
        
        // Fund additional participants
        vm.startPrank(deployer);
        lotryToken.transfer(participants[3], 10_000_000_000 * 1e18);
        lotryToken.transfer(participants[4], 10_000_000_000 * 1e18);
        vm.stopPrank();
        
        uint256[] memory buyAmounts = new uint256[](5);
        buyAmounts[0] = 5_000_000_000 * 1e18;
        buyAmounts[1] = 3_000_000_000 * 1e18;
        buyAmounts[2] = 8_000_000_000 * 1e18;
        buyAmounts[3] = 2_000_000_000 * 1e18;
        buyAmounts[4] = 4_000_000_000 * 1e18;
        
        uint256 totalBought = 0;
        for (uint256 i = 0; i < 5; i++) {
            _approveAndBuy(participants[i], buyAmounts[i]);
            totalBought += buyAmounts[i];
            console.log("Participant %d bought %d LOTRY worth", i, buyAmounts[i] / 1e18);
        }
        
        console.log("Total LOTRY spent:", totalBought / 1e18);
        console.log("Pool Fee accumulated:", ticket.getAccumulatedPoolFeeExternal() / 1e18, "LOTRY");
        
        // Step 2: Some participants sell (partial exit)
        console.log("\n--- Step 2: Some Participants Sell ---");
        
        uint256 buyer2Tokens = ticket.balanceOf(buyer2);
        vm.prank(buyer2);
        ticket.sell(buyer2Tokens / 2);
        console.log("Buyer2 sold half their tokens");
        
        // Step 3: Sponsor deposits additional rewards
        console.log("\n--- Step 3: Sponsor Adds Rewards ---");
        
        uint256 sponsorReward = 5000 * 1e18;
        vm.startPrank(deployer);
        rewardToken.approve(address(ticket), sponsorReward);
        ticket.depositRewardTokens(sponsorReward);
        vm.stopPrank();
        console.log("Sponsor deposited:", sponsorReward / 1e18, "reward tokens");
        
        // Step 4: Pick winner (using participant3 as example)
        console.log("\n--- Step 4: Winner Selection ---");
        
        address theWinner = participants[2]; // buyer3 wins
        uint256 poolFeeBeforeDistribution = ticket.getAccumulatedPoolFeeExternal();
        uint256 winnerLotryBefore = lotryToken.balanceOf(theWinner);
        uint256 winnerRewardBefore = rewardToken.balanceOf(theWinner);
        
        vm.prank(tokenCreator);
        ticket.distributeRewards(theWinner);
        
        uint256 winnerLotryAfter = lotryToken.balanceOf(theWinner);
        uint256 winnerRewardAfter = rewardToken.balanceOf(theWinner);
        
        console.log("Winner (buyer3) received LOTRY:", (winnerLotryAfter - winnerLotryBefore) / 1e18);
        console.log("Winner received Reward tokens:", (winnerRewardAfter - winnerRewardBefore) / 1e18);
        
        // Verify 80/20 split (with tolerance for rounding)
        uint256 expectedWinnerShare = (poolFeeBeforeDistribution * 80) / 100;
        uint256 tolerance = LOTRY_SCALE * 10; // Allow small rounding error
        assertApproxEqAbs(winnerLotryAfter - winnerLotryBefore, expectedWinnerShare, tolerance, "Winner should receive ~80%");
        assertEq(winnerRewardAfter - winnerRewardBefore, sponsorReward, "Winner should receive all sponsor rewards");
        
        // Step 5: End lottery and distribute liquidity
        console.log("\n--- Step 5: End Lottery ---");
        
        uint256 contractBalance = ticket.getLotryBalance();
        console.log("Contract LOTRY balance:", contractBalance / 1e18);
        
        // Distribute proportionally to ticket holders
        address[] memory holders = new address[](4);
        holders[0] = buyer1;
        holders[1] = buyer2;
        holders[2] = buyer3;
        holders[3] = participants[3];
        
        uint256[] memory distributions = new uint256[](4);
        uint256 perHolder = contractBalance / 4;
        distributions[0] = perHolder;
        distributions[1] = perHolder;
        distributions[2] = perHolder;
        distributions[3] = contractBalance - (perHolder * 3);
        
        vm.prank(tokenCreator);
        ticket.pullLiquidity(holders, distributions);
        
        assertTrue(ticket.liquidityPulled(), "Liquidity should be pulled");
        console.log("Liquidity distributed to holders");
        
        // Verify trading is disabled
        vm.startPrank(buyer1);
        lotryToken.approve(address(ticket), 1e18);
        vm.expectRevert(abi.encodeWithSignature("Ticket__TradingDisabled()"));
        ticket.buy(1e18);
        vm.stopPrank();
        
        console.log("\n=== LOTTERY ROUND COMPLETE ===");
        console.log("TEST PASSED");
    }

    // ========================================================================
    //                      STRESS TEST - MANY PARTICIPANTS
    // ========================================================================

    function test_Integration_ManyParticipants() public {
        console.log("\n=== TEST: Many Participants Stress Test ===");
        
        _setupLotryToken();
        
        uint256 numParticipants = 50;
        uint256 buyAmount = 100_000_000 * 1e18;
        
        console.log("Creating %d participants", numParticipants);
        
        address[] memory participants = new address[](numParticipants);
        
        for (uint256 i = 0; i < numParticipants; i++) {
            participants[i] = makeAddr(string(abi.encodePacked("participant", vm.toString(i))));
            
            // Fund participant
            vm.prank(deployer);
            lotryToken.transfer(participants[i], buyAmount * 2);
            
            // Participant buys
            vm.startPrank(participants[i]);
            lotryToken.approve(address(ticket), buyAmount);
            ticket.buy(buyAmount);
            vm.stopPrank();
        }
        
        console.log("All participants bought tickets");
        console.log("Total pool fee:", ticket.getAccumulatedPoolFeeExternal() / 1e18, "LOTRY");
        console.log("Final price:", ticket.calculateCurrentPriceExternal());
        
        // Pick random winner
        address randomWinner = participants[25];
        
        vm.prank(tokenCreator);
        ticket.distributeRewards(randomWinner);
        
        console.log("Winner received:", lotryToken.balanceOf(randomWinner) / 1e18, "LOTRY");
        
        assertGt(lotryToken.balanceOf(randomWinner), 0, "Winner should receive rewards");
        
        console.log("TEST PASSED");
    }

    // ========================================================================
    //                      REPEATED REWARD DISTRIBUTIONS
    // ========================================================================

    function test_Integration_RepeatedRewardDistributions() public {
        console.log("\n=== TEST: Repeated Reward Distributions ===");
        
        _setupLotryToken();
        
        uint256 numRounds = 5;
        
        for (uint256 round = 0; round < numRounds; round++) {
            console.log("\n--- Round", round + 1, "---");
            
            // Trading generates fees
            _approveAndBuy(buyer1, 2_000_000_000 * 1e18);
            _approveAndBuy(buyer2, 2_000_000_000 * 1e18);
            
            // Some sells
            uint256 buyer1Tokens = ticket.balanceOf(buyer1) / 4;
            if (buyer1Tokens > 0) {
                vm.prank(buyer1);
                ticket.sell(buyer1Tokens);
            }
            
            uint256 poolFee = ticket.getAccumulatedPoolFeeExternal();
            console.log("Pool fee:", poolFee / 1e18, "LOTRY");
            
            if (poolFee > 0) {
                // Pick winner for this round
                address roundWinner = makeAddr(string(abi.encodePacked("winner", vm.toString(round))));
                
                vm.prank(tokenCreator);
                ticket.distributeRewards(roundWinner);
                
                console.log("Winner received:", lotryToken.balanceOf(roundWinner) / 1e18, "LOTRY");
                assertGt(lotryToken.balanceOf(roundWinner), 0, "Round winner should receive rewards");
            }
        }
        
        console.log("\nAll %d rounds completed successfully", numRounds);
        console.log("TEST PASSED");
    }

    // ========================================================================
    //                      TOKEN PRICE DISCOVERY
    // ========================================================================

    function test_Integration_PriceDiscovery() public {
        console.log("\n=== TEST: Price Discovery Through Trading ===");
        
        _setupLotryToken();
        
        uint256 initialPrice = ticket.calculateCurrentPriceExternal();
        console.log("Initial Price:", initialPrice);
        
        // Phase 1: Heavy buying (price goes up)
        console.log("\n--- Phase 1: Heavy Buying ---");
        for (uint256 i = 0; i < 10; i++) {
            _approveAndBuy(buyer1, 1_000_000_000 * 1e18);
        }
        uint256 priceAfterBuying = ticket.calculateCurrentPriceExternal();
        console.log("Price after buying:", priceAfterBuying);
        assertGt(priceAfterBuying, initialPrice, "Price should increase after buying");
        
        // Phase 2: Heavy selling (price goes down)
        console.log("\n--- Phase 2: Heavy Selling ---");
        uint256 tokensToSell = ticket.balanceOf(buyer1);
        uint256 sellChunk = tokensToSell / 10;
        
        for (uint256 i = 0; i < 8; i++) {
            vm.prank(buyer1);
            ticket.sell(sellChunk);
        }
        uint256 priceAfterSelling = ticket.calculateCurrentPriceExternal();
        console.log("Price after selling:", priceAfterSelling);
        assertLt(priceAfterSelling, priceAfterBuying, "Price should decrease after selling");
        
        // Phase 3: Mixed trading (price stabilizes)
        console.log("\n--- Phase 3: Mixed Trading ---");
        for (uint256 i = 0; i < 5; i++) {
            // Buy
            _approveAndBuy(buyer2, 500_000_000 * 1e18);
            
            // Sell some
            uint256 buyer2Tokens = ticket.balanceOf(buyer2);
            if (buyer2Tokens > 0) {
                vm.prank(buyer2);
                ticket.sell(buyer2Tokens / 3);
            }
        }
        
        uint256 finalPrice = ticket.calculateCurrentPriceExternal();
        console.log("Final Price:", finalPrice);
        
        console.log("\nPrice history:");
        console.log("  Initial:", initialPrice);
        console.log("  After heavy buying:", priceAfterBuying);
        console.log("  After heavy selling:", priceAfterSelling);
        console.log("  Final (mixed):", finalPrice);
        
        console.log("TEST PASSED");
    }
}

