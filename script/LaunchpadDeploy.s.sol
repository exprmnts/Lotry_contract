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

        // address[] memory whitelist = new address[](5);
        // whitelist[0] = 0x1234567890123456789012345678901234567890;
        // whitelist[1] = 0xaBcDef1234567890123456789012345678901234;
        // whitelist[2] = 0x9876543210987654321098765432109876543210;
        // whitelist[3] = 0x5555555555555555555555555555555555555555;
        // whitelist[4] = msg.sender; // Always include deployer

        // console2.log("Whitelist size:", whitelist.length);

        // address tokenAddress = launchpad.launchToken("Example Lottery", "EXLOT", whitelist);

        // console2.log("Token deployed at:", tokenAddress);

        // // Verify whitelist
        // LotryTicket token = LotryTicket(payable(tokenAddress));
        // console2.log("Whitelist enabled:", token.whitelistEnabled());
        // console2.log("Deployer whitelisted:", token.whitelist(msg.sender));
        // console2.log("First address whitelisted:", token.whitelist(whitelist[0]));

        vm.stopBroadcast();
    }
}
