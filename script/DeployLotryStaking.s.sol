// script/DeployLotryStaking.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/LotryStaking.sol";

contract DeployLotryStaking is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        LotryStaking staking = new LotryStaking(owner);

        console.log("LotryStaking deployed at:", address(staking));
        console.log("Owner:", owner);

        vm.stopBroadcast();
    }
}
