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
git clone https://github.com/yourusername/lotry-contract.git
cd lotry-contract
```

### 2. Install Dependencies

```bash
# Install Foundry dependencies
forge install

# Install Chainlink contracts
forge install smartcontractkit/chainlink-brownie-contracts
```

### 3. Build the Project

```bash
forge build
```

### 4. Environment Setup

#### Option A: Using direnv (Recommended)

```bash
# Install direnv
sudo apt install direnv  # Ubuntu/Debian
# or
brew install direnv      # macOS

# Configure shell
eval "$(direnv hook bash)"
echo 'eval "$(direnv hook bash)"' >> ~/.bashrc
source ~/.bashrc

# Allow direnv in project directory
direnv allow .
```

#### Option B: Manual Environment Variables

Create a `.env` file in the project root:

```bash
# Network Configuration
BASE_SEPOLIA_RPC_URL=your_base_sepolia_rpc_url
BASE_MAINNET_RPC_URL=your_base_mainnet_rpc_url

# Deployment Configuration
PRIVATE_KEY=your_private_key_here

# Chainlink VRF Configuration
VRF_COORDINATOR=your_vrf_coordinator_address
LINK_TOKEN=your_link_token_address
VRF_SUBSCRIPTION_ID=your_subscription_id
VRF_KEY_HASH=your_key_hash
```

## ⚙️ Configuration

### Foundry Configuration

The project uses Foundry for development and deployment. Key configuration files:

- `foundry.toml` - Foundry project configuration
- `remappings.txt` - Solidity import remappings
- `abis/` - Contract ABIs for integration

### Network Configuration

Supported networks:
- **Base Sepolia** (Testnet)
- **Base Mainnet** (Production)

## 🚀 Deployment

### Deploy Launchpad Contract

```bash
forge script script/LaunchpadDeploy.s.sol:LaunchpadDeploy \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast
```

### Deploy Random Wallet Picker (VRF)

```bash
forge script script/VRFDeploy.s.sol:VRFDeploy \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast
```

### Pull Liquidity

```bash
forge script script/PullLiquidity.s.sol:PullLiquidity \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast
```

## 🧪 Testing

### Run All Tests

```bash
forge test
```

### Run Specific Test Files

```bash
# Test Random Wallet Picker
forge test test/RandomWalletPicker.test.js --network base_sepolia

# Test with verbose output
forge test -vvv
```

### Test Coverage

```bash
forge coverage
```

## 💡 Usage

### Basic Token Operations

1. **Launch Token**
   ```bash
   # Deploy new token with bonding curve
   forge script script/LaunchpadDeploy.s.sol:LaunchpadDeploy --broadcast
   ```

2. **Buy Tokens**
   ```javascript
   // Example: Buy tokens with 0.1 ETH
   await launchpad.buyTokens({ value: ethers.utils.parseEther("0.1") });
   ```

3. **Sell Tokens**
   ```javascript
   // Example: Sell all tokens
   const balance = await token.balanceOf(user.address);
   await launchpad.sellTokens(balance);
   ```

### Chainlink VRF Integration

1. **Create VRF Subscription**
   - Visit [Chainlink VRF](https://vrf.chain.link/sepolia)
   - Connect wallet and create subscription
   - Fund with LINK tokens (minimum 2 LINK)

2. **Deploy VRF Contract**
   ```bash
   forge script script/VRFDeploy.s.sol:VRFDeploy --broadcast
   ```

3. **Add Consumer to Subscription**
   - Use the deployed contract address as consumer

### Interactive Testing

```bash
# Complete test flow: Launch → Buy → Sell
forge script script/interactSepolia.js --network base_sepolia
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

**Built with ❤️ by the Lotry.fun team**

*For technical questions or support, please open an issue or join our community discussions.*
