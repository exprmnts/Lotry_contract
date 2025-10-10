// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/RandomWalletPicker.sol";

contract PickRandomWallet is Script {
    // Array of 10 mock wallet addresses for the transaction
    address payable[] internal MOCK_WALLET_ADDRESSES;
    // Corresponding stakes for each wallet
    uint256[] internal MOCK_STAKES;

    function run() external {
        // Load the contract address from your .env file
        address deployedVrfCa = vm.envAddress("DEPLOYED_VRF_CA");
        require(deployedVrfCa != address(0), "DEPLOYED_VRF_CA env var not set");
        RandomWalletPicker randomWalletPicker = RandomWalletPicker(payable(deployedVrfCa));

        // Initialize mock wallet addresses
        MOCK_WALLET_ADDRESSES = new address payable[](10);
        MOCK_WALLET_ADDRESSES[0] = payable(0x1111111111111111111111111111111111111111);
        MOCK_WALLET_ADDRESSES[1] = payable(0x2222222222222222222222222222222222222222);
        MOCK_WALLET_ADDRESSES[2] = payable(0x3333333333333333333333333333333333333333);
        MOCK_WALLET_ADDRESSES[3] = payable(0x4444444444444444444444444444444444444444);
        MOCK_WALLET_ADDRESSES[4] = payable(0x5555555555555555555555555555555555555555);
        MOCK_WALLET_ADDRESSES[5] = payable(0x6666666666666666666666666666666666666666);
        MOCK_WALLET_ADDRESSES[6] = payable(0x7777777777777777777777777777777777777777);
        MOCK_WALLET_ADDRESSES[7] = payable(0x8888888888888888888888888888888888888888);
        MOCK_WALLET_ADDRESSES[8] = payable(0x9999999999999999999999999999999999999999);
        MOCK_WALLET_ADDRESSES[9] = payable(0xaAaAaAaaAaAaAaaAaAAAAAAAAaaaAaAaAaaAaaAa);

        // Initialize mock stakes
        MOCK_STAKES = new uint256[](10);
        MOCK_STAKES[0] = 10;
        MOCK_STAKES[1] = 20;
        MOCK_STAKES[2] = 5;
        MOCK_STAKES[3] = 15;
        MOCK_STAKES[4] = 30;
        MOCK_STAKES[5] = 10;
        MOCK_STAKES[6] = 5;
        MOCK_STAKES[7] = 25;
        MOCK_STAKES[8] = 50;
        MOCK_STAKES[9] = 5; // Sum = 175

        // Start broadcasting a transaction using the wallet provided in the command line
        vm.startBroadcast();

        // Call the owner-only function
        uint256 requestId = randomWalletPicker.pickRandomWallet(
            MOCK_WALLET_ADDRESSES,
            MOCK_STAKES
        );

        // Stop broadcasting
        vm.stopBroadcast();

        console2.log("Successfully sent transaction to pick a random wallet.");
        console2.log("Chainlink VRF Request ID:", requestId);
        console2.log("Monitor the contract for the WalletPicked event.");
    }
}
