# Lotry.fun - Bonding Curve AMM

[![Foundry](https://img.shields.io/badge/Foundry-1.0+-blue.svg)](https://getfoundry.sh/)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.20-green.svg)](https://soliditylang.org/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A production-ready Automated Market Maker (AMM) implementation using bonding curves for token price discovery, deployed on Base mainnet.

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [Installation](#installation)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Testing](#testing)
- [Usage](#usage)
- [Security](#security)
- [Contributing](#contributing)
- [License](#license)

## 🎯 Overview

This project implements a sophisticated token bonding curve system - a mathematical model used in decentralized finance (DeFi) where token prices are algorithmically determined by supply and demand. As token supply increases, the price follows a predefined mathematical curve, creating a fair and transparent pricing mechanism.

### Production Deployment

**Mainnet Contract:** [0x4aefdb502562a55aae91dfdaf5a11f1724d945d1](https://basescan.org/address/0x4aefdb502562a55aae91dfdaf5a11f1724d945d1)

**Recent Transactions:**

- Token Launch: [View Transaction](https://basescan.org/tx/0x74f1f182fc4b98f12feb20533e4df131641601f4f2ca038429db5c16463a122a)

## ✨ Features

- **ERC20-Compliant Tokens**: Full compatibility with the Ethereum ecosystem
- **Bonding Curve Pricing**: Automated price discovery based on supply
- **Configurable Parameters**: Adjustable reserve ratios and curve parameters
- **Buy/Sell Operations**: Seamless token trading with ETH
- **Chainlink VRF Integration**: Provably fair random number generation
- **Liquidity Management**: Advanced liquidity provision and withdrawal
- **Gas Optimization**: Efficient smart contract design for cost-effective operations

## 🏗️ Architecture

### Core Components

1. **Launchpad.sol** - Main token launch and bonding curve logic
2. **Pool.sol** - Liquidity pool management
3. **RandomWalletPicker.sol** - Chainlink VRF integration for fair selection

### Bonding Curve Implementation

Our system uses a modified Bancor formula for price calculation:

```
Price = Reserve Balance / (Total Supply × Reserve Ratio)
```

For detailed mathematical explanations, see [BONDINGCURVE.md](./BONDINGCURVE.md).

## 🚀 Quick Start

### Prerequisites

- **Foundry**: [Install Foundry](https://getfoundry.sh/)
- **Node.js**: v18+
- **Git**: Latest version
- **Environment Variables**: Properly configured `.env` file

### System Requirements

- **Operating System**: Windows 10+, macOS 10.15+, or Ubuntu 18.04+
- **Memory**: 8GB RAM minimum, 16GB recommended
- **Storage**: 10GB free space
- **Network**: Stable internet connection

## 📦 Installation

### 1. Clone the Repository

```bash
git clone https://github.com/4rjunc/lotry-contract.git
cd lotry-contract
```

### 2. Install Dependencies

```bash
# Install Foundry dependencies
forge install

# Pull gitsubmodules
git submodule update --init --recursive
```

### 3. Build the Project

```bash
forge build
```

### 4. Environment Setup

#### Wallet Setup Using Cast

Before deploying, you need to set up a wallet using Foundry's `cast` tool:

1. **Import your wallet**:

   ```bash
   cast wallet import <wallet name> --private-key <private key>
   ```

2. **List your wallets**:
   ```bash
   cast wallet list
   ```

#### Option A: Using direnv (Recommended)

This project uses `direnv` to manage environment variables for different networks.

1. **Install direnv** (if you haven't already):
   ```bash
   # Ubuntu/Debian
   sudo apt install direnv
   # macOS
   brew install direnv
   ```
2. **Hook direnv into your shell**. Add the following line to your shell's startup file (e.g., `~/.bashrc`, `~/.zshrc`):

   ```bash
   eval "$(direnv hook bash)" # or zsh, fish, etc.
   ```

3. **Set up `.envrc`**. Create a `.envrc` file in the project root with the following content:

   ```bash
   #!/bin/bash
   # Set default environment if not specified
   : ${TARGET_ENV:=base_sepolia}

   # Load the corresponding .env file
   source_env ".env.$TARGET_ENV"
   ```

4. **Allow direnv**. Run the following command in the project root:
   ```bash
   direnv allow .
   ```

Now, `direnv` will automatically load the environment variables from `.env.base_sepolia` by default. To switch environments, you can set the `TARGET_ENV` variable:

```bash
export TARGET_ENV=base
# Your shell will now use variables from .env.base

export TARGET_ENV=sepolia
# Your shell will now use variables from .env.sepolia
```

#### Option B: Manual Environment Variables

If you prefer not to use `direnv`, you can manually load the environment variables from the desired file before running any commands:

```bash
source .env.base_sepolia
forge build
```

## ⚙️ Configuration

### Foundry Configuration

The `foundry.toml` file contains the base configuration for the project, such as source directories and compiler settings. Network-specific configurations like RPC URLs and private keys are managed via `.env` files and loaded into your shell session by `direnv`.

- `foundry.toml` - Foundry project configuration
- `remappings.txt` - Solidity import remappings
- `abis/` - Contract ABIs for integration

## 🚀 Deployment

Make sure you have the correct environment loaded with `direnv` before deploying. Your `.env.<network>` file (e.g., `.env.base_sepolia`) should define and export the following variables:

- `RPC_URL`: The RPC endpoint for your target network.

### Deploying to a Network

1.  **Set your target environment**. For example, to deploy to Base Sepolia, run:

    ```bash
    export TARGET_ENV=base_sepolia
    ```

    `direnv` will automatically load the variables from `.env.base_sepolia`. If it's your first time or you've changed `.envrc`, you may need to run `direnv allow .`.

2.  **Run the deployment scripts**. `forge` will automatically use the `ETH_RPC_URL`, `PRIVATE_KEY`, and `ETHERSCAN_API_KEY` from your environment.

**Deploy Launchpad Contract**

```bash
forge script script/LaunchpadDeploy.s.sol:LaunchpadDeploy --rpc-url $RPC_URL -vvv --keystore ~/.foundry/keystores/<Wallet Name>  --broadcast
```

**Deploy Random Wallet Picker (VRF)**

```bash
forge script script/VRFDeploy.s.sol:VRFDeploy --broadcast --verify
```

Example for `base_sepolia`:

```bash
# 1. Set the environment
export TARGET_ENV=base_sepolia

# 2. Deploy the Launchpad
forge script script/LaunchpadDeploy.s.sol:LaunchpadDeploy --rpc-url $RPC_URL -vvv --keystore ~/.foundry/keystores/baseSepoliaWallet  --broadcast
```

## Chainlink VRF Integration

1. **Create VRF Subscription**

   - Visit [Chainlink VRF](https://vrf.chain.link/sepolia)
   - Connect wallet and create subscription
   - Fund with ETH

2. **Deploy VRF Contract**

   ```bash
   forge script script/VRFDeploy.s.sol:VRFDeploy --rpc-url $RPC_URL -vvv --keystore ~/.foundry keystores/baseSepoliaWallet --broadcast
   ```

3. **Add Consumer to Subscription**
   - Use the deployed contract address as consumer

## 🧪 Testing

### Run All Tests

```bash
forge test
```

### Run Forked Tests

To run tests on a forked network, set your `TARGET_ENV` and run:

```bash
export TARGET_ENV=base
forge test --rpc-url base
```

### Test Coverage

```bash
forge coverage
```

### Testing VRF

Since the test requires onchain interaction and wallet activity we have to put this in /script

```bash
forge script script/PickRandomWallet.s.sol:PickRandomWallet --rpc-url $RPC_URL --keystore ~/.foundry/keystores/baseSepoliaWallet --broadcast -vvv
```

As Foundry script runs as a single, synchronous operation. It can't pause and wait for the Chainlink network to send the fulfillment transaction back. Once the fulfillment transaction has occurred, you can easily check the winner's address by calling the getPickedWallet view function on your contract. This can be done using the `cast call`

```bash
cast call $DEPLOYED_VRF_CA "getPickedWallet()" --rpc-url $RPC_URL
```

## 🔒 Security

### Security Considerations

- **Slippage Protection**: Implement maximum price impact guards
- **Reentrancy Protection**: All external calls are protected
- **Access Control**: Proper role-based access control
- **Input Validation**: Comprehensive parameter validation
- **Emergency Functions**: Pause and emergency withdrawal capabilities

### Audit Status

- ✅ Internal security review completed
- 🔄 External audit in progress
- 📋 Bug bounty program available

### Best Practices

1. **Never share private keys**
2. **Use hardware wallets for production**
3. **Test thoroughly on testnets**
4. **Monitor gas prices for optimal deployment**
5. **Keep dependencies updated**

## 🤝 Contributing

We welcome contributions! Please follow these steps:

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/amazing-feature`
3. **Commit changes**: `git commit -m 'Add amazing feature'`
4. **Push to branch**: `git push origin feature/amazing-feature`
5. **Open a Pull Request**

### Development Guidelines

- Follow Solidity style guide
- Write comprehensive tests
- Update documentation
- Ensure all tests pass
- Follow conventional commit messages

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📞 Support

- **Documentation**: [Project Wiki](https://github.com/yourusername/lotry-contract/wiki)
- **Issues**: [GitHub Issues](https://github.com/yourusername/lotry-contract/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/lotry-contract/discussions)
- **Email**: support@lotry.fun

## 🔄 Roadmap

- [ ] Uniswap V4 integration
- [ ] Advanced bonding curve formulas

---

**From the studios of Experiments. Built with ❤️**

_For technical questions or support, please open an issue or join our community discussions._
