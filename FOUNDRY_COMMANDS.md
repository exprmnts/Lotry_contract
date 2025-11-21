- Send ETH to token contract to increase the POT (accumulatedPoolFee)

cast send <LOTRY_TICKET_CONTRACT>  --value 0.1ether --rpc-url $RPC_URL --account <CAST_WALLET>

- To check balance in accumulatedPoolFee

cast call <LOTRY_TICKET_CONTRACT>  "accumulatedPoolFee()(uint256)" --rpc-url $RPC_URL

- To set the reward ERC20

cast send <LOTRY_TICKET_CONTRACT>  "setRewardToken(address)" <REWARD_TOKEN_CONTRACT> --rpc-url $RPC_URL --account <CAST_WALLET>

- To view reward token address

cast call <LOTRY_TICKET_CONTRACT>  "rewardTokenAddress()(address)" --rpc-url $RPC_URL

- To deposit reward token (10 token of 18 decimal)

  - approve first : cast send <REWARD_TOKEN_CONTRACT> "approve(address,uint256)" <LOTRY_TICKET_CONTRACT>  10000000000000000000   --rpc-ur $RPC_URL --account <CAST_WALLET>
 
  - send token: cast send <LOTRY_TICKET_CONTRACT>  "depositRewardTokens(uint256)" 10000000000000000000 --rpc-url $RPC_URL --account <CAST_WALLET> (10 token of 18 decimal)


- To view balance of reward token address

cast call <LOTRY_TICKET_CONTRACT>  "getRewardTokenBalance()(uint256)" --rpc-url $RPC_URL

