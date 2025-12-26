// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {LotryTestBase, MockLotryToken} from "./LotryTestBase.sol";
import {LotryTicket} from "../contracts/LotryTicket.sol";

/**
 * @title LotryTicket Bonding Curve Simulation Tests
 * @notice Comprehensive simulation tests to verify bonding curve behavior
 * @dev Tests the actual buy function and produces detailed console output
 *      All values are read from contract functions - no manual calculations
 */
contract LotryTicketSimulationTest is LotryTestBase {

    /**
     * @notice Main test: Performs 50 actual buys and displays results in a table
     * @dev This tests the real buy() function from the contract with 11% tax applied
     *      Shows tax collected after each buy
     */
    function test_BuySimulation_50Buys() public {
        _setupLotryToken();
        
        console.log("");
        console.log("========================================================================================================");
        console.log("                              BUY SIMULATION TEST (WITH 11% TAX)");
        console.log("========================================================================================================");
        console.log("Testing actual buy() function with 50 sequential buys of 1B $LOTRY each");
        console.log("Tax is applied on each buy - 11% goes to prize pool");
        console.log("");
        
        // Get initial state from contract
        uint256 initialPrice = ticket.calculateCurrentPriceExternal();
        uint256 initialTokensInContract = ticket.balanceOf(address(ticket));
        uint256 initialLotryBalance = ticket.getLotryBalance();
        uint256 initialTaxPot = ticket.getAccumulatedPoolFeeExternal();
        
        console.log("=== INITIAL STATE ===");
        console.log("Token Price          :", _formatPrice(initialPrice), "$LOTRY");
        console.log("Tokens in Contract   :", initialTokensInContract / 1e18);
        console.log("$LOTRY in Contract   :", initialLotryBalance / 1e18);
        console.log("Tax Pot              :", initialTaxPot / 1e18);
        console.log("Constant K           :", ticket.I_CONSTANT_K());
        console.log("");
        
        // Print table header
        console.log("========================================================================================================");
        console.log("Buy#  | Price ($LOTRY) | Increase | Tokens in Contract | $LOTRY in Contract | Tax Collected in contract");
        console.log("========================================================================================================");
        
        uint256 buyAmount = 1_000_000_000 * 1e18; // 1B LOTRY per buy
        uint256 totalLotrySpent = 0;
        
        for (uint256 i = 0; i < 50; i++) {
            // Rotate between buyers
            address buyer = i % 3 == 0 ? buyer1 : (i % 3 == 1 ? buyer2 : buyer3);
            
            // Execute actual buy
            vm.startPrank(buyer);
            lotryToken.approve(address(ticket), buyAmount);
            ticket.buy(buyAmount);
            vm.stopPrank();
            
            totalLotrySpent += buyAmount;
            
            // Get state from contract after buy
            uint256 price = ticket.calculateCurrentPriceExternal();
            uint256 tokensInContract = ticket.balanceOf(address(ticket));
            uint256 lotryInContract = ticket.getLotryBalance();
            uint256 taxThisBuy = ticket.getAccumulatedPoolFeeExternal();

            // Calculate price increase factor (e.g., 1.16x, 2.56x, 16.00x)
            uint256 increaseFactorX100 = (price * 100) / initialPrice;
            
            // Log table row
            _logTableRowWithTax(
                i + 1,
                price,
                increaseFactorX100,
                tokensInContract,
                lotryInContract,
                taxThisBuy
            );
        }
        
        console.log("========================================================================================================");
        console.log("");
        
        // Final state from contract
        uint256 finalPrice = ticket.calculateCurrentPriceExternal();
        uint256 finalTokensInContract = ticket.balanceOf(address(ticket));
        uint256 finalLotryInContract = ticket.getLotryBalance();
        uint256 finalTaxPot = ticket.getAccumulatedPoolFeeExternal();
        uint256 lotryRaised = ticket.getLotryRaisedExternal();
        
        console.log("=== FINAL STATE ===");
        console.log("Final Token Price    :", _formatPrice(finalPrice), "$LOTRY");
        console.log("Tokens in Contract   :", finalTokensInContract / 1e18);
        console.log("Tokens Circulating   :", (INITIAL_SUPPLY - finalTokensInContract) / 1e18);
        console.log("$LOTRY in Contract   :", finalLotryInContract / 1e18);
        console.log("$LOTRY Raised (curve):", lotryRaised / 1e18);
        console.log("Total Tax Collected  :", finalTaxPot / 1e18);
        console.log("");
        
        // Price increase summary
        uint256 totalIncrease = (finalPrice * 100) / initialPrice;
        console.log("=== SUMMARY ===");
        console.log("Total $LOTRY Spent   :", totalLotrySpent / 1e18);
        console.log("Net to Curve (89%)   :", lotryRaised / 1e18);
        console.log("Tax Collected (11%)  :", finalTaxPot / 1e18);
        console.log("Price Increase       :", _formatFactor(totalIncrease));
        console.log("Initial Price        :", initialPrice / 1e18, "$LOTRY");
        console.log("Final Price          :", finalPrice / 1e18, "$LOTRY");
        
        // Verify tax is correctly accumulated (11% of total spent)
        uint256 expectedTax = (totalLotrySpent * TAX_NUMERATOR) / TAX_DENOMINATOR;
        assertApproxEqRel(finalTaxPot, expectedTax, 1e15, "Tax pot should be 11% of total spent");
    }

    /**
     * @notice Shows $LOTRY requirements to reach various circulation levels
     * @dev Uses contract functions to calculate buy returns
     *      Note: 1B tokens is the total supply, so max circulation is <1B
     */
    function test_LotryRequirementsAnalysis() public {
        _setupLotryToken();
        
        console.log("");
        console.log("========================================================================================================");
        console.log("                         $LOTRY REQUIREMENTS ANALYSIS (WITH TAX)");
        console.log("========================================================================================================");
        console.log("Simulating buys to reach each circulation level - includes 11% tax");
        console.log("Note: Total supply is 1B, so max circulation approaches but never reaches 1B");
        console.log("");
        
        // Get initial price from contract
        uint256 initialPrice = ticket.calculateCurrentPriceExternal();
        
        // Target circulation levels (realistic - up to 900M since 1B is total supply)
        uint256[] memory targetCirculating = new uint256[](10);
        targetCirculating[0] = 100_000_000 * 1e18;  // 100M
        targetCirculating[1] = 200_000_000 * 1e18;  // 200M
        targetCirculating[2] = 300_000_000 * 1e18;  // 300M
        targetCirculating[3] = 400_000_000 * 1e18;  // 400M
        targetCirculating[4] = 500_000_000 * 1e18;  // 500M
        targetCirculating[5] = 600_000_000 * 1e18;  // 600M
        targetCirculating[6] = 700_000_000 * 1e18;  // 700M
        targetCirculating[7] = 790_000_000 * 1e18;  // 790M
        targetCirculating[8] = 800_000_000 * 1e18;  // 800M
        targetCirculating[9] = 900_000_000 * 1e18;  // 900M
        
        string[10] memory labels = ["100M", "200M", "300M", "400M", "500M", "600M", "700M", "790M", "800M", "900M"];
        
        // Print table header
        console.log("========================================================================================================");
        console.log("Target    | $LOTRY Spent   | Price ($LOTRY) | Increase | Tax Collected  | Circulating");
        console.log("========================================================================================================");
        
        uint256 buyChunk = 500_000_000 * 1e18; // 500M LOTRY per buy chunk
        uint256 totalSpent = 0;
        uint256 levelIndex = 0;
        
        while (levelIndex < 10) {
            uint256 currentCirculating = INITIAL_SUPPLY - ticket.balanceOf(address(ticket));
            
            // Check if we've reached the current target
            if (currentCirculating >= targetCirculating[levelIndex]) {
                uint256 price = ticket.calculateCurrentPriceExternal();
                uint256 taxPot = ticket.getAccumulatedPoolFeeExternal();
                uint256 increaseX100 = (price * 100) / initialPrice;
                
                _logRequirementsRow(
                    labels[levelIndex],
                    totalSpent,
                    price,
                    increaseX100,
                    taxPot,
                    currentCirculating
                );
                
                levelIndex++;
                continue;
            }
            
            // Buy more tokens
            address buyer = totalSpent % 3 == 0 ? buyer1 : (totalSpent % 3 == 1 ? buyer2 : buyer3);
            
            // Use smaller chunks near targets for accuracy
            uint256 tokensRemaining = targetCirculating[levelIndex] - currentCirculating;
            uint256 thisBuy = tokensRemaining < 50_000_000 * 1e18 ? 100_000_000 * 1e18 : buyChunk;
            
            vm.startPrank(buyer);
            lotryToken.approve(address(ticket), thisBuy);
            ticket.buy(thisBuy);
            vm.stopPrank();
            
            totalSpent += thisBuy;
            
            // Safety limit
            if (totalSpent > 300_000_000_000 * 1e18) break;
        }
        
        console.log("========================================================================================================");
    }


    // ========================================================================
    //                      HELPER FUNCTIONS
    // ========================================================================

    function _logTableRowWithTax(
        uint256 buyNum,
        uint256 price,
        uint256 increaseFactorX100,
        uint256 tokensInContract,
        uint256 lotryInContract,
        uint256 taxThisBuy
    ) internal pure {
        string memory row = string(abi.encodePacked(
            _padLeft(_uint2str(buyNum), 5),
            " | ",
            _padLeft(_formatPrice(price), 14),
            " | ",
            _padLeft(_formatFactor(increaseFactorX100), 8),
            " | ",
            _padLeft(_uint2str(tokensInContract / 1e18), 18),
            " | ",
            _padLeft(_uint2str(lotryInContract / 1e18), 18),
            " | ",
            _padLeft(_uint2str(taxThisBuy / 1e18), 13)
        ));
        console.log(row);
    }

    function _logRequirementsRow(
        string memory label,
        uint256 lotrySpent,
        uint256 price,
        uint256 increaseX100,
        uint256 taxCollected,
        uint256 circulating
    ) internal pure {
        string memory row = string(abi.encodePacked(
            _padLeft(label, 9),
            " | ",
            _padLeft(_uint2str(lotrySpent / 1e18), 14),
            " | ",
            _padLeft(_formatPrice(price), 14),
            " | ",
            _padLeft(_formatFactor(increaseX100), 8),
            " | ",
            _padLeft(_uint2str(taxCollected / 1e18), 14),
            " | ",
            _padLeft(_uint2str(circulating / 1e18), 11)
        ));
        console.log(row);
    }

    function _padLeft(string memory str, uint256 length) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        if (strBytes.length >= length) return str;
        
        bytes memory padded = new bytes(length);
        uint256 padding = length - strBytes.length;
        
        for (uint256 i = 0; i < padding; i++) {
            padded[i] = " ";
        }
        for (uint256 i = 0; i < strBytes.length; i++) {
            padded[padding + i] = strBytes[i];
        }
        
        return string(padded);
    }

    function _formatPrice(uint256 price) internal pure returns (string memory) {
        uint256 whole = price / 1e18;
        uint256 decimals = (price % 1e18) / 1e16;
        return string(abi.encodePacked(_uint2str(whole), ".", _padZero(_uint2str(decimals), 2)));
    }

    function _formatFactor(uint256 factorX100) internal pure returns (string memory) {
        uint256 whole = factorX100 / 100;
        uint256 decimals = factorX100 % 100;
        return string(abi.encodePacked(_uint2str(whole), ".", _padZero(_uint2str(decimals), 2), "x"));
    }

    function _padZero(string memory str, uint256 length) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        if (strBytes.length >= length) return str;
        
        bytes memory padded = new bytes(length);
        uint256 padding = length - strBytes.length;
        
        for (uint256 i = 0; i < padding; i++) {
            padded[i] = "0";
        }
        for (uint256 i = 0; i < strBytes.length; i++) {
            padded[padding + i] = strBytes[i];
        }
        
        return string(padded);
    }

    function _uint2str(uint256 _i) internal pure returns (string memory) {
        if (_i == 0) return "0";
        uint256 j = _i;
        uint256 length;
        while (j != 0) {
            length++;
            j /= 10;
        }
        bytes memory bstr = new bytes(length);
        uint256 k = length;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
}
