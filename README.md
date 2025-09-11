## Contract Deployed in Base Mainnet: [CLICK HERE](https://basescan.org/address/0x4aefdb502562a55aae91dfdaf5a11f1724d945d1)

Mainnet Transactions:
- Token Launch: [CLICK HERE](https://basescan.org/tx/0x74f1f182fc4b98f12feb20533e4df131641601f4f2ca038429db5c16463a122a)
    

# Bonding Curve AMM

A simple Automated Market Maker (AMM) implementation that uses a bonding curve to determine token prices.

## Overview

This project implements a token bonding curve - a mathematical concept used in decentralized finance (DeFi) where the price of a token is determined by its supply. As the token supply increases, so does the price, following a predefined formula.

## Features

- ERC20-compliant token
- Continuous token issuance based on bonding curve formula
- Configurable reserve ratio parameter
- Buy tokens with ETH
- Sell tokens back for ETH
- Automatic price calculation
- Bonding Curve equation similar to pump.fun

## How It Works

### [Bonding Curve Explained](./BONDINGCURVE.md) 

## Getting Started

### Prerequisites

- Node.js v18+
- npm or yarn
- Hardhat

### Installation

1. Clone the repository
```bash
git clone https://github.com/yourusername/bonding-curve-amm.git
cd bonding-curve-amm
```

2. Install dependencies
```bash
npm install
# or
yarn install
```

3. Create a `.env` file (optional for custom configurations)
```bash
cp .env.example .env
```

### Running Tests

Run the test suite to verify the contract's functionality:

```bash
npx hardhat test
```

You should see output similar to:
```
Initial Supply: 10000.0
Initial Token Price: 0.005
--- BUYING TOKENS ---
Tokens Purchased: 4000.0
Price After Buy: 0.006
Reserve Balance: 12.0
--- SELLING TOKENS ---
Remaining Tokens: 2000.0
Tokens Sold: 2000.0
Price After Sell: 0.0055
Reserve Balance: 11.0
```

### Deploying to a Local Network

1. Start a local Hardhat node
```bash
npx hardhat node
```

2. Deploy the contract
```bash
npx hardhat run scripts/deploy.js --network localhost
```

## Understanding the Math

### Bancor Formula

Our implementation uses a simplified version of the Bancor formula for computational efficiency. The classic Bancor formula is:

```
Return = Supply * ((1 + Deposit/Reserve)^(ReserveRatio) - 1)
```

For small transactions, we approximate this with:
```
Return = Deposit * Supply / (Reserve * ReserveRatio)
```

### Example Calculation

With:
- Reserve balance: 10 ETH
- Total supply: 10,000 tokens
- Reserve ratio: 20%

The token price would be:
```
Price = 10 * 10^18 / (10000 * 20/100) = 0.005 ETH per token
```

If someone buys with 2 ETH, they would receive:
```
Tokens = 2 * 10000 / (10 * 20/100) = 10000 tokens
```

## Chainlink VRF
### Deploy
```npx hardhat run scripts/vrf_deploy.js --network base_sepolia```

then,
### Test
```npx hardhat test .\test\RandomWalletPicker.test.js --network base_sepolia```

### Pull Liquidity
```npx hardhat run scripts/pullLiquidity.js --network base_sepolia```

### Creating a Chainlink VRF Subscription

1. Visit ![Chainlink VRF](https://vrf.chain.link/sepolia)
2. Connect your wallet
3. Click "Create Subscription"
4. Fund your subscription with LINK tokens (minimum 2 LINK recommended)
5. After deploying your contract, you'll need to add it as a consumer to your subscription.

### Interact with testnet

One token Launch -> Buy token for 0.1 ETH -> Sell all tokens

```npx hardhat run scripts/interactSepolia.js --network base_sepolia```

## Security Considerations

- The contract lacks slippage protection
- Large purchases or sales can significantly move the price
- Consider implementing maximum price impact guards for production use

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## TODO
- set a freeze function while migrating to uniswap

## How to setup graph for lotry

- Create subgrap in thegraph.com
- Do this 

```

󰄛 ❯ graph init lotry-main
✔ Network · Base Chain · base · https://base.blockscout.com
✔ Source · Smart Contract · ethereum
✔ Subgraph slug · lotry-main
✔ Directory to create the subgraph in · lotry-main
✔ Contract address · 0x15851248D2c77F3F70f912A9eCEC701a71f56b16
✔ Fetching ABI from Sourcify API...
✖ Failed to fetch ABI: Failed to fetch ABI: Error: NOTOK - Contract source code not verified
✔ Do you want to retry? (Y/n) · false
✔ Fetching start block from Contract API...
✖ Failed to fetch contract name: Name not found
✔ Do you want to retry? (Y/n) · false
✔ ABI file (path) · ./abis/TokenLaunchpad.json
✔ Start block · 35376931
✔ Contract name · TokenLaunchpad
✔ Index contract events as entities (Y/n) · true
  Generate subgraph
  Write subgraph to directory
✔ Create subgraph scaffold
✔ Initialize networks config
✔ Initialize subgraph repository
✔ Install dependencies with yarn
✔ Generate ABI and schema types with yarn codegen
✔ Add another contract? (y/N) · true
✔
Contract address · 0xD8EF7B0e27466DcF76f511e92D5a3E7828543c6b
✖ Failed to fetch ABI: Failed to fetch ABI: Error: NOTOK - Contract source code not verified
✔ Do you want to retry? (Y/n) · false
✔ ABI file (path) · ../abis/BondingCurvePool.json
✔ Contract Name · BondingCurvePool
✔ Running codegen

Subgraph lotry-main created in lotry-main

Next steps:

  1. Run `graph auth` to authenticate with your deploy key.

  2. Type `cd lotry-main` to enter the subgraph.

  3. Run `yarn deploy` to deploy the subgraph.

Make sure to visit the documentation on https://thegraph.com/docs/ for further information.
```

- cd to graph's folder 
- use this `.yaml` change address, block number 

```
specVersion: 1.3.0
indexerHints:
  prune: auto
schema:
  file: ./schema.graphql
dataSources:
  - kind: ethereum
    name: TokenLaunchpad
    network: base
    source:
      address: "0x15851248D2c77F3F70f912A9eCEC701a71f56b16"
      abi: TokenLaunchpad
      startBlock: 35376931
    mapping:
      kind: ethereum/events
      apiVersion: 0.0.9
      language: wasm/assemblyscript
      entities:
        - OwnershipTransferred
        - TokenCreated
      abis:
        - name: TokenLaunchpad
          file: ./abis/TokenLaunchpad.json
      eventHandlers:
        - event: OwnershipTransferred(indexed address,indexed address)
          handler: handleOwnershipTransferred
        - event: TokenCreated(indexed address,string,string)
          handler: handleTokenCreated
      file: ./src/token-launchpad.ts
templates:
  - name: BondingCurvePool
    kind: ethereum/contract
    network: base
    source:
      abi: BondingCurvePool
    mapping:
      kind: ethereum/events
      apiVersion: 0.0.9
      language: wasm/assemblyscript
      file: ./src/bonding-curve-pool.ts
      entities:
        - TradeEvent
      abis:
        - name: BondingCurvePool
          file: ./abis/BondingCurvePool.json
      eventHandlers:
        - event: TradeEvent(indexed address,uint256)
          handler: handleTradeEvent
```

- `graph codegen && graph build`
- add these lines in `src/token-launchpad.ts` 

```
import { BondingCurvePool as BondingCurvePoolTemplate } from "../generated/templates"
BondingCurvePoolTemplate.create(event.params.tokenAddress)
```

- `graph deploy lotry-main`
