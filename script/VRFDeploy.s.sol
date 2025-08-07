// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {RandomWalletPicker} from "../contracts/RandomWalletPicker.sol";

/**
 * Deploys the RandomWalletPicker contract to Base Sepolia (or any network)
 *
 * Usage:
 *   forge script script/VRFDeploy.s.sol:VRFDeploy \
 *        --rpc-url $BASE_SEPOLIA_RPC_URL \
 *        --private-key $PRIVATE_KEY \
 *        --broadcast 
 *
 * Required env vars (same names used in the original JS script):
 *   VRF_COORDINATOR_BASE_SEPOLIA – address of Chainlink VRF coordinator
 *   SUBSCRIPTION_ID_BASE_SEPOLIA – uint256 subscription id
 *   KEY_HASH_BASE_SEPOLIA        – bytes32 gas lane key hash
 */
contract VRFDeploy is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address coordinator = vm.envAddress("VRF_COORDINATOR_BASE_SEPOLIA");
        uint256 subId = vm.envUint("SUBSCRIPTION_ID_BASE_SEPOLIA");
        bytes32 keyHash = vm.envBytes32("KEY_HASH_BASE_SEPOLIA");

        vm.startBroadcast(pk);
        RandomWalletPicker picker = new RandomWalletPicker(coordinator, subId, keyHash);
        console2.log("RandomWalletPicker deployed at", address(picker));
        vm.stopBroadcast();
    }
}
