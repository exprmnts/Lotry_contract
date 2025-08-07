// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {TokenLaunchpad} from "../contracts/Launchpad.sol";

/**
 * Forge script that deploys the TokenLaunchpad contract.
 *
 * Usage (broadcast, Base Sepolia):
 *   forge script script/LaunchpadDeploy.s.sol:LaunchpadDeploy \
 *        --rpc-url $BASE_SEPOLIA_RPC_URL \
 *        --private-key $PRIVATE_KEY \
 *        --broadcast 
 *
 */
contract LaunchpadDeploy is Script {
    function run() external {
        // Grab the deployer's private key from the environment (required by Forge)
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy the launchpad contract with the deployer as initial owner
        TokenLaunchpad launchpad = new TokenLaunchpad(vm.addr(deployerPrivateKey));
        console2.log("TokenLaunchpad deployed at", address(launchpad));

        vm.stopBroadcast();
    }
}
