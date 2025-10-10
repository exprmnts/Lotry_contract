// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {TokenLaunchpad} from "../contracts/Launchpad.sol";

contract LaunchpadDeploy is Script {
    function run() external {
        vm.startBroadcast();

        // Deploy the launchpad contract with the deployer as initial owner
        TokenLaunchpad launchpad = new TokenLaunchpad(msg.sender);
        console2.log("TokenLaunchpad deployed at", address(launchpad));

        vm.stopBroadcast();
    }
}
