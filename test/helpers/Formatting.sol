// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Vm.sol";

library Formatting {
    function pad(string memory s, uint256 width) internal pure returns (string memory) {
        uint256 len = bytes(s).length;
        if (len >= width) {
            return s;
        }
        string memory padding = "";
        for (uint256 i = 0; i < width - len; i++) {
            padding = string.concat(padding, " ");
        }
        return string.concat(s, padding);
    }

    function formatEther(Vm vm, uint256 weiAmount, uint256 decimals) internal pure returns (string memory) {
        uint256 integerPart = weiAmount / 1e18;
        if (decimals == 0) {
            return vm.toString(integerPart);
        }
        uint256 fractionalPart = (weiAmount % 1e18) / (10**(18 - decimals));

        string memory fractionalString = vm.toString(fractionalPart);

        uint256 originalLength = bytes(fractionalString).length;
        if (fractionalPart == 0) {
            originalLength = 1;
        }
        
        if (originalLength < decimals) {
            string memory padding = "";
            for (uint256 i = 0; i < decimals - originalLength; i++) {
                padding = string.concat(padding, "0");
            }
            fractionalString = string.concat(padding, fractionalString);
        }

        return string.concat(vm.toString(integerPart), ".", fractionalString);
    }

    function formatUsd(Vm vm, uint256 usdAmountWith18Decimals) internal pure returns (string memory) {
        uint256 dollars = usdAmountWith18Decimals / 1e18;
        uint256 cents = (usdAmountWith18Decimals % 1e18) / 1e16;
        string memory centsStr = vm.toString(cents);
        if (cents < 10) {
            centsStr = string.concat("0", centsStr);
        }
        return string.concat("$", vm.toString(dollars), ".", centsStr);
    }

    function formatTokens(Vm vm, uint256 tokenAmount) internal pure returns (string memory) {
        uint256 integerPart = tokenAmount / 1e18;
        return vm.toString(integerPart);
    }

    function formatSmallPrice(Vm vm, uint256 price) internal pure returns (string memory) {
        return formatEther(vm, price, 18);
    }

    function formatPercent(Vm vm, int256 value) internal pure returns (string memory) {
        return string.concat(vm.toString(uint256(value)), "%");
    }

    function slice(string memory s, uint256 start, uint256 end) internal pure returns (string memory) {
        bytes memory b = bytes(s);
        require(end >= start, "slice: end cannot be smaller than start");
        require(b.length >= end, "slice: end cannot be greater than length");
        bytes memory result = new bytes(end - start);
        for(uint i = start; i < end; i++){
            result[i-start] = b[i];
        }
        return string(result);
    }
}
