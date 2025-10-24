// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {LotryLaunch} from "../contracts/LotryLaunch.sol";
import {LotryTicket} from "../contracts/LotryTicket.sol";

contract LaunchpadDeploy is Script {
    function run() external {
        vm.startBroadcast();

        LotryLaunch launchpad = new LotryLaunch(msg.sender);
        console2.log("LotryLaunch deployed at:", address(launchpad));

        vm.stopBroadcast();
    }
}
