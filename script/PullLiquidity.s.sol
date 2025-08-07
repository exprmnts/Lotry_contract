// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {BondingCurvePool} from "../contracts/Pool.sol";

/**
 * Forge script that pulls liquidity from an existing BondingCurvePool.
 * Mimics the behaviour of scripts/pullLiquidity.js but written in Solidity.
 *
 * Usage (broadcast):
 *   forge script script/PullLiquidity.s.sol:PullLiquidity \
 *        --rpc-url $BASE_SEPOLIA_RPC_URL \
 *        --private-key $PRIVATE_KEY \
 *        --broadcast \
 *        -vvvv
 *
 * Required env vars:
 *   POOL_ADDRESS – address of the deployed BondingCurvePool.
 */
contract PullLiquidity is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address poolAddr = vm.envAddress("POOL_ADDRESS");

        vm.startBroadcast(pk);

        BondingCurvePool pool = BondingCurvePool(payable(poolAddr));

        // Fetch on-chain values to replicate JS script's safety checks
        uint256 ethRaised = pool.ethRaised();
        uint256 contractBalance = poolAddr.balance;

        // If the contract balance is lower than ethRaised, top-up so pullLiquidity doesn't revert
        if (contractBalance < ethRaised) {
            uint256 shortfall = ethRaised - contractBalance;
            uint256 buffer = 1e15; // 0.001 ether
            uint256 valueToSend = shortfall + buffer;
            // add funds to lottery pool
            pool.addToLotteryPool{value: valueToSend}();
        }

        // Execute pullLiquidity
        pool.pullLiquidity();
        vm.stopBroadcast();
    }

    receive() external payable {}
}
