// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {LotryStaking} from "../contracts/LotryStaking.sol";

contract DeployLotryStaking is Script {
    function run() external {
        vm.startBroadcast();

        LotryStaking staking = new LotryStaking(msg.sender);
        console2.log("LotryStaking deployed at", address(staking));
        console2.log("Owner:", msg.sender);

        vm.stopBroadcast();
    }
}
