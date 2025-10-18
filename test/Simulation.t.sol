// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/LotryLaunch.sol";
import "../contracts/LotryTicket.sol";
import "./helpers/Formatting.sol";

contract PoolSimulationTest is Test {
    LotryLaunch launchpad;
    LotryTicket lotry;
    address owner;
    address buyer1;
    address buyer2;
    address buyer3;
    address[] buyers;

    uint256 constant ethToUsdRate = 4098; // Example rate

    function setUp() public {
        owner = makeAddr("owner");
        buyer1 = makeAddr("buyer1");
        buyer2 = makeAddr("buyer2");
        buyer3 = makeAddr("buyer3");
        buyers.push(buyer1);
        buyers.push(buyer2);
        buyers.push(buyer3);

        vm.startPrank(owner);
        launchpad = new LotryLaunch(owner);
        vm.stopPrank();

        vm.deal(buyer1, 10000 ether);
        vm.deal(buyer2, 10000 ether);
        vm.deal(buyer3, 10000 ether);
    }

    function createNewPool(string memory name, string memory symbol) internal {
        vm.prank(owner);
        address poolAddress = launchpad.launchToken(name, symbol);
        lotry = LotryTicket(poolAddress);
    }

    function calculateMarketCapEth(
        uint256 price,
        uint256 circulatingSupply,
        uint256 virtualTokenReserve
    ) internal pure returns (uint256) {
        return (price * (circulatingSupply + virtualTokenReserve)) / (1e18);
    }

    function test_marketSimulation() public {
        createNewPool("Simulation Token", "SIM");

        uint256 INITIAL_SUPPLY = lotry.INITIAL_SUPPLY();
        uint256 vTokenReserve = lotry.virtualTokenReserve();
        uint256 vEthReserve = lotry.virtualEthReserve();

        console.log("\n--- Initial Contract State ---");
        console.log("Virtual Token Reserve:", Formatting.formatTokens(vm, vTokenReserve));
        console.log("Virtual ETH Reserve:", Formatting.formatEther(vm, vEthReserve, 4));
        console.log(
            "Tokens in Contract:",
            Formatting.formatTokens(vm, lotry.balanceOf(address(lotry)))
        );
        console.log("ETH Raised in Contract:", Formatting.formatEther(vm, lotry.ethRaised(), 4));
        console.log(
            "Initial Token Price (ETH):",
            Formatting.formatSmallPrice(vm, lotry.calculateCurrentPrice())
        );
        uint256 initialMarketCapInEth = calculateMarketCapEth(
            lotry.calculateCurrentPrice(),
            INITIAL_SUPPLY - lotry.balanceOf(address(lotry)),
            vTokenReserve
        );
        console.log("Initial Market Cap (ETH):", Formatting.formatEther(vm, initialMarketCapInEth, 4));
        console.log(
            "Initial Market Cap (USD):",
            Formatting.formatUsd(vm, (initialMarketCapInEth * ethToUsdRate) / 1e18)
        );
        console.log("------------------------------------");

        uint256 targetTokensSold = 500_000_000 * 1e18; // 500M tokens
        uint256 tokensSoldTotal;
        uint256 buyAmountWei = 1 ether;

        console.log("\n--- Adaptive Buy Loop Results ---");
        string memory header = string.concat(
            Formatting.pad("Buy(ETH)", 10), " | ",
            Formatting.pad("Tokens Recv", 15), " | ",
            Formatting.pad("Cum. Sold", 15), " | ",
            Formatting.pad("Tokens Left", 15), " | ",
            Formatting.pad("Price(ETH)", 20), " | ",
            Formatting.pad("Market Cap(USD)", 20), " | ",
            Formatting.pad("ETH Raised", 15), " | ",
            "Accum. Fee"
        );
        console.log(header);

        for (uint i = 0; i < 50 && tokensSoldTotal < targetTokensSold; i++) {
            vm.prank(buyer1);
            uint256 balanceBefore = lotry.balanceOf(buyer1);
            try lotry.buy{value: buyAmountWei}() {
                uint256 balanceAfter = lotry.balanceOf(buyer1);
                uint256 tokensReceived = balanceAfter - balanceBefore;

                uint256 currentPrice = lotry.calculateCurrentPrice();
                uint256 tokensLeft = lotry.balanceOf(address(lotry));
                uint256 circulatingSupply = INITIAL_SUPPLY - tokensLeft;
                tokensSoldTotal = circulatingSupply;
                uint256 marketCapInEth = calculateMarketCapEth(
                    currentPrice,
                    circulatingSupply,
                    vTokenReserve
                );
                uint256 marketCapUsd = (marketCapInEth * ethToUsdRate) / 1e18;

                string memory row = string.concat(
                    Formatting.pad(Formatting.formatEther(vm, buyAmountWei, 4), 10), " | ",
                    Formatting.pad(Formatting.formatTokens(vm, tokensReceived), 15), " | ",
                    Formatting.pad(Formatting.formatTokens(vm, tokensSoldTotal), 15), " | ",
                    Formatting.pad(Formatting.formatTokens(vm, tokensLeft), 15), " | ",
                    Formatting.pad(Formatting.formatSmallPrice(vm, currentPrice), 20), " | ",
                    Formatting.pad(Formatting.formatUsd(vm, marketCapUsd), 20), " | ",
                    Formatting.pad(Formatting.formatEther(vm, lotry.ethRaised(), 4), 15), " | ",
                    Formatting.formatEther(vm, lotry.accumulatedPoolFee(), 6)
                );
                console.log(row);

            } catch {
                console.log(
                    "Buy failed, likely due to insufficient reserves. Stopping loop."
                );
                break;
            }

            buyAmountWei *= 2;
            if (buyAmountWei > 1000 ether) {
                buyAmountWei = 1000 ether;
            }
        }

        console.log("\n--- Final Tax Collections ---");
        console.log(
            "Accumulated Pool Fee (ETH):",
            Formatting.formatEther(vm, lotry.accumulatedPoolFee(), 6)
        );
        console.log("------------------------------------");

        console.log("\n--- Sell Simulation Results ---");
        header = string.concat(
            Formatting.pad("Sell(Tokens)", 15), " | ",
            Formatting.pad("ETH Recv", 15), " | ",
            Formatting.pad("Tokens Left", 15), " | ",
            Formatting.pad("ETH Raised", 15), " | ",
            Formatting.pad("Price(ETH)", 20), " | ",
            Formatting.pad("Market Cap(USD)", 20), " | ",
            "Accum. Fee"
        );
        console.log(header);

        uint256 sellerBalanceTotal = lotry.balanceOf(buyer1);
        uint256[] memory sellPercentages = new uint256[](3);
        sellPercentages[0] = 10;
        sellPercentages[1] = 30;
        sellPercentages[2] = 50;

        for (uint i = 0; i < sellPercentages.length; i++) {
            uint256 sellAmount = (sellerBalanceTotal * sellPercentages[i]) / 100;
            if (lotry.balanceOf(buyer1) >= sellAmount && sellAmount > 0) {
                vm.prank(buyer1);
                uint256 ethBefore = buyer1.balance;
                lotry.sell(sellAmount);
                uint256 ethReceived = buyer1.balance - ethBefore;

                uint256 currentPrice = lotry.calculateCurrentPrice();
                uint256 tokensLeft = lotry.balanceOf(address(lotry));
                uint256 circulatingSupply = INITIAL_SUPPLY - tokensLeft;
                uint256 marketCapInEth = calculateMarketCapEth(
                    currentPrice,
                    circulatingSupply,
                    vTokenReserve
                );
                uint256 marketCapUsd = (marketCapInEth * ethToUsdRate) / 1e18;

                string memory row = string.concat(
                    Formatting.pad(Formatting.formatTokens(vm, sellAmount), 15), " | ",
                    Formatting.pad(Formatting.formatEther(vm, ethReceived, 4), 15), " | ",
                    Formatting.pad(Formatting.formatTokens(vm, tokensLeft), 15), " | ",
                    Formatting.pad(Formatting.formatEther(vm, lotry.ethRaised(), 4), 15), " | ",
                    Formatting.pad(Formatting.formatSmallPrice(vm, currentPrice), 20), " | ",
                    Formatting.pad(Formatting.formatUsd(vm, marketCapUsd), 20), " | ",
                    Formatting.formatEther(vm, lotry.accumulatedPoolFee(), 6)
                );
                console.log(row);
            }
        }

        assertGt(lotry.ethRaised(), 0);
    }

    function test_priceIncreaseSimulation50Buys() public {
        createNewPool("Price Analysis Token", "PAT");
        uint256 numberOfBuys = 50;
        uint256 minBuyAmount = 0.001 ether;
        uint256 maxBuyAmount = 0.5 ether;

        console.log("\n--- Price Increase Analysis Results ---");
        string memory header = string.concat(
            Formatting.pad("Buy #", 5), " | ",
            Formatting.pad("Buyer", 8), " | ",
            Formatting.pad("Buy (ETH)", 10), " | ",
            Formatting.pad("Tokens Recv", 15), " | ",
            Formatting.pad("Price (ETH)", 20), " | ",
            Formatting.pad("Price Inc %", 12), " | ",
            "Market Cap (USD)"
        );
        console.log(header);

        uint256[] memory buyAmounts = new uint256[](numberOfBuys);
        uint256[] memory tokensBought = new uint256[](numberOfBuys);
        uint256 initialPrice = lotry.calculateCurrentPrice();

        for (uint i = 0; i < numberOfBuys; i++) {
            buyAmounts[i] =
                minBuyAmount +
                ((maxBuyAmount - minBuyAmount) * i) /
                (numberOfBuys - 1);
        }

        for (uint i = 0; i < numberOfBuys; i++) {
            address currentBuyer = buyers[i % buyers.length];
            vm.prank(currentBuyer);
            uint256 tokenBalanceBefore = lotry.balanceOf(currentBuyer);
            uint256 priceBefore = lotry.calculateCurrentPrice();

            lotry.buy{value: buyAmounts[i]}();
            uint256 tokensReceived = lotry
                .balanceOf(currentBuyer) - tokenBalanceBefore;
            tokensBought[i] = tokensReceived;
            uint256 priceAfter = lotry.calculateCurrentPrice();
            int256 priceChange = int256(priceAfter) - int256(priceBefore);
            int256 priceIncreasePercent = int256(priceChange * 100) / int256(initialPrice);

            uint256 marketCapInEth = calculateMarketCapEth(
                priceAfter,
                lotry.INITIAL_SUPPLY() - lotry.balanceOf(address(lotry)),
                lotry.virtualTokenReserve()
            );
            uint256 marketCapUsd = (marketCapInEth * ethToUsdRate) / 1e18;
            
            string memory buyerStr = string.concat(Formatting.slice(vm.toString(currentBuyer), 0, 6), "...");

            string memory row = string.concat(
                Formatting.pad(vm.toString(i + 1), 5), " | ",
                Formatting.pad(buyerStr, 8), " | ",
                Formatting.pad(Formatting.formatEther(vm, buyAmounts[i], 4), 10), " | ",
                Formatting.pad(Formatting.formatTokens(vm, tokensReceived), 15), " | ",
                Formatting.pad(Formatting.formatSmallPrice(vm, priceAfter), 20), " | ",
                Formatting.pad(Formatting.formatPercent(vm, priceIncreasePercent), 12), " | ",
                Formatting.formatUsd(vm, marketCapUsd)
            );
            console.log(row);
        }
        assertGt(lotry.accumulatedPoolFee(), 0);

        console.log("\n--- Individual Sell Results ---");
        header = string.concat(
            Formatting.pad("Sell #", 6), " | ",
            Formatting.pad("Seller", 8), " | ",
            Formatting.pad("Tokens Sold", 15), " | ",
            Formatting.pad("ETH Received", 15), " | ",
            "Profit/Loss (ETH)"
        );
        console.log(header);

        for (uint i = 0; i < numberOfBuys; i++) {
            address currentBuyer = buyers[i % buyers.length];
            if (lotry.balanceOf(currentBuyer) > 0) {
                vm.prank(currentBuyer);
                uint256 ethBefore = currentBuyer.balance;
                uint256 tokensToSell = tokensBought[i];
                if (lotry.balanceOf(currentBuyer) < tokensToSell) {
                    tokensToSell = lotry.balanceOf(currentBuyer);
                }

                lotry.sell(tokensToSell);
                uint256 ethReceived = currentBuyer.balance - ethBefore;
                int256 profitLoss = int256(ethReceived) -
                    int256(buyAmounts[i]);
                
                string memory sellerStr = string.concat(Formatting.slice(vm.toString(currentBuyer), 0, 6), "...");

                string memory row = string.concat(
                    Formatting.pad(vm.toString(i + 1), 6), " | ",
                    Formatting.pad(sellerStr, 8), " | ",
                    Formatting.pad(Formatting.formatTokens(vm, tokensToSell), 15), " | ",
                    Formatting.pad(Formatting.formatEther(vm, ethReceived, 4), 15), " | ",
                    Formatting.formatEther(vm, uint256(profitLoss), 4)
                );
                console.log(row);
            }
        }
    }

    function test_tokenDepletionSimulation() public {
        createNewPool("Depletion Test Token", "DTT");

        uint256 INITIAL_SUPPLY = lotry.INITIAL_SUPPLY();
        uint256 initialPrice = lotry.calculateCurrentPrice();
        console.log("--- Token Depletion Simulation ---");
        console.log("Initial token supply:", Formatting.formatTokens(vm, INITIAL_SUPPLY));
        console.log("Initial price:", Formatting.formatSmallPrice(vm, initialPrice));
        
        uint256 targetTokens = (INITIAL_SUPPLY * 999) / 1000; // 99.9%
        uint256 tokensSoldTotal;
        uint256 buyAmount = 1 ether;
        uint256 totalEthSpent;
        uint buyCount = 0;

        string memory header = string.concat(
            Formatting.pad("Buy #", 5), " | ",
            Formatting.pad("ETH Spent", 10), " | ",
            Formatting.pad("Tokens Recv", 15), " | ",
            Formatting.pad("Total Sold", 15), " | ",
            Formatting.pad("Tokens Left", 15), " | ",
            Formatting.pad("Price(ETH)", 20), " | ",
            "Price Mult"
        );
        console.log(header);

        for (uint i = 0; i < 100 && tokensSoldTotal < targetTokens; i++) {
            uint256 tokensLeftBefore = lotry.balanceOf(address(lotry));
            if (tokensLeftBefore == 0) break;

            vm.prank(buyer1);
            uint256 balanceBefore = lotry.balanceOf(buyer1);
            try lotry.buy{value: buyAmount}() {
                uint256 balanceAfter = lotry.balanceOf(buyer1);
                uint256 tokensReceived = balanceAfter - balanceBefore;

                totalEthSpent += buyAmount;
                tokensSoldTotal = INITIAL_SUPPLY - lotry.balanceOf(address(lotry));
                buyCount++;

                uint256 currentPrice = lotry.calculateCurrentPrice();
                string memory priceMult = string.concat(vm.toString(currentPrice / initialPrice), "x");

                string memory row = string.concat(
                    Formatting.pad(vm.toString(buyCount), 5), " | ",
                    Formatting.pad(Formatting.formatEther(vm, buyAmount, 4), 10), " | ",
                    Formatting.pad(Formatting.formatTokens(vm, tokensReceived), 15), " | ",
                    Formatting.pad(Formatting.formatTokens(vm, tokensSoldTotal), 15), " | ",
                    Formatting.pad(Formatting.formatTokens(vm, lotry.balanceOf(address(lotry))), 15), " | ",
                    Formatting.pad(Formatting.formatSmallPrice(vm, currentPrice), 20), " | ",
                    priceMult
                );
                console.log(row);

                buyAmount *= 2;
            } catch {
                break;
            }
        }
        
        console.log("\n--- Depletion Final Results ---");
        console.log("Total ETH required:", Formatting.formatEther(vm, totalEthSpent, 4));
        console.log(
            "Total ETH required (USD):",
            Formatting.formatUsd(vm, (totalEthSpent * ethToUsdRate) / 1e18)
        );
        console.log("Total buys executed:", vm.toString(buyCount));
        console.log("Tokens sold:", Formatting.formatTokens(vm, tokensSoldTotal));
        console.log(
            "Tokens remaining:",
            Formatting.formatTokens(vm, lotry.balanceOf(address(lotry)))
        );
        console.log("Final price:", Formatting.formatSmallPrice(vm, lotry.calculateCurrentPrice()));
        console.log(
            "Price increase:",
            string.concat(vm.toString(lotry.calculateCurrentPrice() / initialPrice), "x")
        );

        assertGt(totalEthSpent, 0);
        assertGt(tokensSoldTotal, 0);
    }

    enum ActionType {
        Buy,
        Sell
    }
    struct Action {
        ActionType actionType;
        address trader;
        uint256 amount; // ETH for buy, percentage for sell (e.g., 50 for 50%)
    }

    function test_mixedBuysAndSells() public {
        createNewPool("Volatile Token", "VOL");
        Action[] memory actions = new Action[](10);
        actions[0] = Action({
            actionType: ActionType.Buy,
            trader: buyer1,
            amount: 1 ether
        });
        actions[1] = Action({
            actionType: ActionType.Buy,
            trader: buyer2,
            amount: 2.5 ether
        });
        actions[2] = Action({
            actionType: ActionType.Sell,
            trader: buyer1,
            amount: 50
        }); // 50%
        actions[3] = Action({
            actionType: ActionType.Buy,
            trader: buyer3,
            amount: 0.75 ether
        });
        actions[4] = Action({
            actionType: ActionType.Sell,
            trader: buyer2,
            amount: 25
        }); // 25%
        actions[5] = Action({
            actionType: ActionType.Buy,
            trader: buyer1,
            amount: 3 ether
        });
        actions[6] = Action({
            actionType: ActionType.Buy,
            trader: buyer2,
            amount: 1.2 ether
        });
        actions[7] = Action({
            actionType: ActionType.Sell,
            trader: buyer3,
            amount: 100
        }); // 100%
        actions[8] = Action({
            actionType: ActionType.Sell,
            trader: buyer1,
            amount: 30
        }); // 30%
        actions[9] = Action({
            actionType: ActionType.Buy,
            trader: buyer2,
            amount: 5 ether
        });

        console.log("\n--- Mixed Buy/Sell Transaction Log ---");
        string memory header = string.concat(
            Formatting.pad("#", 3), " | ",
            Formatting.pad("Action", 6), " | ",
            Formatting.pad("Trader", 8), " | ",
            Formatting.pad("ETH Amt", 10), " | ",
            Formatting.pad("Token Amt", 15), " | ",
            Formatting.pad("Price Chg %", 12), " | ",
            Formatting.pad("New Price(ETH)", 20), " | ",
            Formatting.pad("Market Cap(USD)", 20), " | ",
            "ETH in Contract"
        );
        console.log(header);

        for (uint i = 0; i < actions.length; i++) {
            Action memory action = actions[i];
            uint256 priceBefore = lotry.calculateCurrentPrice();
            string memory traderStr = string.concat(Formatting.slice(vm.toString(action.trader), 0, 6), "...");
            
            if (action.actionType == ActionType.Buy) {
                vm.prank(action.trader);
                uint256 tokenBalanceBefore = lotry.balanceOf(action.trader);
                lotry.buy{value: action.amount}();
                uint256 tokensReceived = lotry.balanceOf(action.trader) -
                    tokenBalanceBefore;
                uint256 priceAfter = lotry.calculateCurrentPrice();
                int256 priceChange = int256(priceAfter) - int256(priceBefore);
                int256 priceChangePercent = int256(priceChange * 100) / int256(priceBefore);
                uint256 marketCapInEth = calculateMarketCapEth(
                    priceAfter,
                    lotry.INITIAL_SUPPLY() - lotry.balanceOf(address(lotry)),
                    lotry.virtualTokenReserve()
                );
                uint256 marketCapUsd = (marketCapInEth * ethToUsdRate) / 1e18;

                string memory ethAmtStr = string.concat("+", Formatting.formatEther(vm, action.amount, 4));
                string memory tokenAmtStr = string.concat("+", Formatting.formatTokens(vm, tokensReceived));

                string memory row = string.concat(
                    Formatting.pad(vm.toString(i + 1), 3), " | ",
                    Formatting.pad("BUY", 6), " | ",
                    Formatting.pad(traderStr, 8), " | ",
                    Formatting.pad(ethAmtStr, 10), " | ",
                    Formatting.pad(tokenAmtStr, 15), " | ",
                    Formatting.pad(Formatting.formatPercent(vm, priceChangePercent), 12), " | ",
                    Formatting.pad(Formatting.formatSmallPrice(vm, priceAfter), 20), " | ",
                    Formatting.pad(Formatting.formatUsd(vm, marketCapUsd), 20), " | ",
                    Formatting.formatEther(vm, lotry.ethRaised(), 4)
                );
                console.log(row);

            } else {
                uint256 traderBalance = lotry.balanceOf(action.trader);
                if (traderBalance > 0) {
                    uint256 sellAmount = (traderBalance * action.amount) / 100;
                    vm.prank(action.trader);
                    uint256 ethBalanceBefore = action.trader.balance;
                    lotry.sell(sellAmount);
                    uint256 ethReceived = action.trader.balance -
                        ethBalanceBefore;
                    uint256 priceAfter = lotry.calculateCurrentPrice();
                    int256 priceChange = int256(priceAfter) -
                        int256(priceBefore);
                    int256 priceChangePercent = int256(priceChange * 100) / int256(priceBefore);
                    uint256 marketCapInEth = calculateMarketCapEth(
                        priceAfter,
                        lotry.INITIAL_SUPPLY() - lotry.balanceOf(address(lotry)),
                        lotry.virtualTokenReserve()
                    );
                    uint256 marketCapUsd = (marketCapInEth * ethToUsdRate) / 1e18;

                    string memory ethAmtStr = string.concat("-", Formatting.formatEther(vm, ethReceived, 4));
                    string memory tokenAmtStr = string.concat("-", Formatting.formatTokens(vm, sellAmount));
                    
                    string memory row = string.concat(
                        Formatting.pad(vm.toString(i + 1), 3), " | ",
                        Formatting.pad("SELL", 6), " | ",
                        Formatting.pad(traderStr, 8), " | ",
                        Formatting.pad(ethAmtStr, 10), " | ",
                        Formatting.pad(tokenAmtStr, 15), " | ",
                        Formatting.pad(Formatting.formatPercent(vm, priceChangePercent), 12), " | ",
                        Formatting.pad(Formatting.formatSmallPrice(vm, priceAfter), 20), " | ",
                        Formatting.pad(Formatting.formatUsd(vm, marketCapUsd), 20), " | ",
                        Formatting.formatEther(vm, lotry.ethRaised(), 4)
                    );
                    console.log(row);
                }
            }
        }
        assertTrue(lotry.ethRaised() >= 0);
    }
}
