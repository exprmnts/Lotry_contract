// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {RandomWalletPicker} from "../../contracts/RandomWalletPicker.sol";

contract PickRandomWallet is Script {
    address payable[] internal walletAddresses;
    uint256[] internal stakes;

    function run() external {
        // Load the contract address from your .env file
        address deployedVrfCa = vm.envAddress("DEPLOYED_VRF_CA");
        require(deployedVrfCa != address(0), "DEPLOYED_VRF_CA env var not set");
        RandomWalletPicker randomWalletPicker = RandomWalletPicker(payable(deployedVrfCa));

        walletAddresses = new address payable[](10);
        walletAddresses[0] = payable(0x1111111111111111111111111111111111111111);
        walletAddresses[1] = payable(0x2222222222222222222222222222222222222222);
        walletAddresses[2] = payable(0x3333333333333333333333333333333333333333);
        walletAddresses[3] = payable(0x4444444444444444444444444444444444444444);
        walletAddresses[4] = payable(0x5555555555555555555555555555555555555555);
        walletAddresses[5] = payable(0x6666666666666666666666666666666666666666);
        walletAddresses[6] = payable(0x7777777777777777777777777777777777777777);
        walletAddresses[7] = payable(0x8888888888888888888888888888888888888888);
        walletAddresses[8] = payable(0x9999999999999999999999999999999999999999);
        walletAddresses[9] = payable(0xaAaAaAaaAaAaAaaAaAAAAAAAAaaaAaAaAaaAaaAa);

        stakes = new uint256[](10);
        stakes[0] = 10;
        stakes[1] = 20;
        stakes[2] = 5;
        stakes[3] = 15;
        stakes[4] = 30;
        stakes[5] = 10;
        stakes[6] = 5;
        stakes[7] = 25;
        stakes[8] = 50;
        stakes[9] = 5;

        vm.startBroadcast();

        uint256 requestId = randomWalletPicker.pickRandomWallet(walletAddresses, stakes);

        vm.stopBroadcast();

        console2.log("Successfully sent transaction to pick a random wallet.");
        console2.log("Chainlink VRF Request ID:", requestId);
        console2.log("Monitor the contract for the WalletPicked event.");
    }
}
