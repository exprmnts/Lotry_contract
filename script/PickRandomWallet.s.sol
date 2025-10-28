// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {RandomWalletPicker} from "../contracts/RandomWalletPicker.sol";

contract PickRandomWallet is Script {
    address payable[] internal WALLET_ADDRESSES;
    uint256[] internal STAKES;

    function run() external {
        // Load the contract address from your .env file
        address deployedVrfCa = vm.envAddress("DEPLOYED_VRF_CA");
        require(deployedVrfCa != address(0), "DEPLOYED_VRF_CA env var not set");
        RandomWalletPicker randomWalletPicker = RandomWalletPicker(
            payable(deployedVrfCa)
        );

        WALLET_ADDRESSES = new address payable[](10);
        WALLET_ADDRESSES[0] = payable(
            0x1111111111111111111111111111111111111111
        );
        WALLET_ADDRESSES[5] = payable(
            0x6666666666666666666666666666666666666666
        );

        STAKES = new uint256[](10);
        STAKES[0] = 10;
        STAKES[1] = 20;
        STAKES[2] = 5;
        STAKES[3] = 15;
        STAKES[4] = 30;
        STAKES[5] = 10;
        STAKES[6] = 5;
        STAKES[7] = 25;
        STAKES[8] = 50;
        STAKES[9] = 5;

        vm.startBroadcast();

        uint256 requestId = randomWalletPicker.pickRandomWallet(
            WALLET_ADDRESSES,
            STAKES
        );

        vm.stopBroadcast();

        console2.log("Successfully sent transaction to pick a random wallet.");
        console2.log("Chainlink VRF Request ID:", requestId);
        console2.log("Monitor the contract for the WalletPicked event.");
    }
}
