// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {RandomWalletPicker} from "../contracts/RandomWalletPicker.sol";

contract VRFDeploy is Script {
    function run() external {
        address coordinator = vm.envAddress("VRF_COORDINATOR");
        uint256 subId = vm.envUint("SUBSCRIPTION_ID");
        bytes32 keyHash = vm.envBytes32("KEY_HASH");

        vm.startBroadcast();
        RandomWalletPicker picker = new RandomWalletPicker(coordinator, subId, keyHash);
        console2.log("RandomWalletPicker deployed at", address(picker));
        vm.stopBroadcast();
    }
}
