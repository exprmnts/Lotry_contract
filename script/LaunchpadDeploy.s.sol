// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {LotryLaunch} from "../contracts/LotryLaunch.sol";
import {LotryTicket} from "../contracts/LotryTicket.sol";

contract LaunchpadDeploy is Script {
    function run() external {
        vm.startBroadcast();

        LotryLaunch launchpad = new LotryLaunch(msg.sender);
        console2.log("TokenLaunchpad deployed at", address(launchpad));

        // Launch a token through the launchpad
        // address tokenAddress = launchpad.launchToken("CAT", "CAT");
        // console2.log("Token deployed at", tokenAddress);

        vm.stopBroadcast();
    }
}
