.PHONY: help install build test deploy launchpad vrf test-vrf verify-launchpad verify-vrf verify-staking deploy-staking launch-token verify-token clean coverage env-setup wallet-import wallet-list check-env set-stake-token stake-lotry get-all-staked check-stake-token check-total-staked check-user-stake check-stakers-count check-is-staker withdraw-all-staked

# Default target
.DEFAULT_GOAL := help

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

# Default values
TARGET_ENV ?= $(shell echo $$TARGET_ENV)
RPC_URL ?= $(shell echo $$RPC_URL)
CHAIN_ID ?= $(shell echo $$CHAIN_ID)
ETHERSCAN_API_KEY ?= $(shell echo $$ETHERSCAN_API_KEY)

# Contract addresses for verification
LAUNCHPAD_CA ?= $(shell echo $$LAUNCHPAD_CA)
VRF_CA ?= $(shell echo $$VRF_CA)
STAKING_CA ?= $(shell echo $$STAKING_CA)
VRF_COORDINATOR ?= $(shell echo $$VRF_COORDINATOR)
SUBSCRIPTION_ID ?= $(shell echo $$SUBSCRIPTION_ID)
KEY_HASH ?= $(shell echo $$KEY_HASH)

# Token launch parameters
TOKEN_CA ?= $(shell echo $$TOKEN_CA)
TOKEN_NAME ?= $(shell echo $$TOKEN_NAME)
TOKEN_SYMBOL ?= $(shell echo $$TOKEN_SYMBOL)

# LotryStaking contract parameters
STAKE_TOKEN ?= $(shell echo $$STAKE_TOKEN)
DAILY_REWARD_TOKEN ?= $(shell echo $$DAILY_REWARD_TOKEN) # daily lotry ticket address
DAILY_STAKE_REWARD_TOKEN_DEPOSIT_AMOUNT ?= $(shell echo $$DAILY_STAKE_REWARD_TOKEN_DEPOSIT_AMOUNT)
DAILY_CLAIM_REWARD_TOKEN_DEPOSIT_AMOUNT ?= $(shell echo $$DAILY_CLAIM_REWARD_TOKEN_DEPOSIT_AMOUNT)
DAILY_CLAIM_REWARD_CLAIMABLE_AMOUNT ?= $(shell echo $$DAILY_CLAIM_REWARD_CLAIMABLE_AMOUNT)

# Set WALLET_NAME based on TARGET_ENV
ifeq ($(TARGET_ENV),base)
WALLET_NAME ?= baseWallet
WALLET_ADDR ?= 0x9dbbBfBb5e2b1b2C5754becECa4E1e473b852a65
else
WALLET_NAME ?= baseSepoliaWallet
WALLET_ADDR ?= 0x3513C0F1420b7D4793158Ae5eb5985BBf34d5911
endif
VERBOSITY ?= -vvvvv

##@ Help & Environment

check-env: ## Internal target to check environment variables
	@if [ -z "$(TARGET_ENV)" ]; then \
		echo "$(RED)❌ TARGET_ENV not set!$(NC)"; \
		echo "   Please set TARGET_ENV to either 'base' or 'base_sepolia'"; \
		echo "   Example: export TARGET_ENV=base_sepolia"; \
		exit 1; \
	fi
	@if [ -z "$(RPC_URL)" ]; then \
		echo "$(RED)❌ RPC_URL not set for $(TARGET_ENV)!$(NC)"; \
		echo "   Please set RPC_URL for your target environment"; \
		exit 1; \
	fi
	@echo "$(GREEN)✅ Environment variables set!$(NC)"


help:
	@echo "$(GREEN)                            ⠀⠀⠀⠀ ⠀⢀⣤⣿⣶⣄⠀⠀⠀⣀⡀⠀⠀⠀⠀ $(NC)"
	@echo "$(GREEN)                            ⠀⠀⣠⣤⣄⡀⣼⣿⣿⣿⣿⠀⣠⣾⣿⣿⡆⠀⠀⠀  $(NC)"
	@echo "$(GREEN)                            ⠀⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣶⣿⣿⣿⣿⣧⣄⡀⠀  $(NC)"
	@echo "$(GREEN)                            ⠀⠀⠻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡄  $(NC)"
	@echo "$(GREEN)                            ⠀⠀⣀⣤⣽⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠃  $(NC)"
	@echo "$(GREEN)                            ⢰⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣩⡉⠀⠀  $(NC)"
	@echo "$(GREEN)                            ⠹⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣄  $(NC)"
	@echo "$(GREEN)                            ⠀⠀⠉⣸⣿⣿⣿⣿⠏⢸⡏⣿⣿⣿⣿⣿⣿⣿⣿⡏  $(NC)"
	@echo "$(GREEN)                            ⠀⠀⠀⢿⣿⣿⡿⠏⠀⢸⣇⢻⣿⣿⣿⣿⠉⠉⠁⠀  $(NC)"
	@echo "$(GREEN)                            ⠀⠀⠀⠀⠈⠁⠀⠀⠀⠸⣿⡀⠙⠿⠿⠋⠀⠀⠀⠀  $(NC)"
	@echo "$(GREEN)                            ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢹⣿⡀⠀⠀⠀⠀⠀⠀⠀  $(NC)"
	@echo ""
	@echo "$(GREEN)                     $(NC)"
	@echo "$(GREEN)                █   █▀█ ▀█▀ █▀█ █▄█   █▀█ █▀█ █▀█ ▀█▀ █▀█ █▀▀ █▀█ █$(NC)"
	@echo "$(GREEN)                █▄▄ █▄█  █  █▀▄  █    █▀▀ █▀▄ █▄█  █  █▄█ █▄▄ █▄█ █▄▄$(NC)"
	@echo ""
	@echo "$(GREEN)Usage:$(NC)"
	@echo "  make [target] [VARIABLE=value]"
	@echo ""
	@echo "$(GREEN)Available targets:$(NC)"
	@awk 'BEGIN {FS = ":.*##"; printf ""} /^[a-zA-Z_-]+:.*?##/ { printf "  $(YELLOW)%-25s$(NC) %s\n", $$1, $$2 } /^##@/ { sub(/^##@[ \t]+/, "", $$0); printf "\n$(BLUE)%s$(NC)\n", $$0 } ' $(MAKEFILE_LIST)
	@echo ""

##@ Installation & Setup

install: ## Install Foundry dependencies and pull git submodules
	@echo "$(BLUE)📦 Installing Foundry dependencies...$(NC)"
	forge install
	@echo "$(BLUE)📦 Pulling git submodules...$(NC)"
	git submodule update --init --recursive
	@echo "$(GREEN)✅ Installation complete!$(NC)"

build: ## Build the project
	@echo "$(BLUE)🔨 Building project...$(NC)"
	forge build
	@echo "$(GREEN)✅ Build complete!$(NC)"

clean: ## Clean build artifacts and cache
	@echo "$(BLUE)🧹 Cleaning build artifacts...$(NC)"
	forge clean
	@echo "$(GREEN)✅ Clean complete!$(NC)"

##@ Testing

test: ## Run all tests
	@echo "$(BLUE)🧪 Running tests...$(NC)"
	forge test $(VERBOSITY)
	@echo "$(GREEN)✅ Tests complete!$(NC)"

test-fork: check-env ## Run tests on a forked network (requires TARGET_ENV)
	@echo "$(BLUE)🧪 Running forked tests on $(TARGET_ENV)...$(NC)"
	@if [ -z "$(RPC_URL)" ]; then \
		echo "$(RED)❌ RPC_URL not set! Run: export TARGET_ENV=$(TARGET_ENV)$(NC)"; \
		exit 1; \
	fi
	forge test --rpc-url $(RPC_URL) $(VERBOSITY)
	@echo "$(GREEN)✅ Forked tests complete!$(NC)"

coverage: ## Generate test coverage report
	@echo "$(BLUE)📊 Generating coverage report...$(NC)"
	forge coverage
	@echo "$(GREEN)✅ Coverage report generated!$(NC)"

##@ Deployment

deploy-launchpad: check-env ## Deploy Launchpad contract
	@echo "$(BLUE)🚀 Deploying Launchpad contract...$(NC)"
	@echo "$(YELLOW)   Network: $(TARGET_ENV)$(NC)"
	@echo "$(YELLOW)   Wallet: $(WALLET_NAME)$(NC)"
	@echo "$(YELLOW)   Sender: $(WALLET_ADDR)$(NC)"
	@echo "$(YELLOW)   RPC: $(RPC_URL)$(NC)"
	forge script script/LaunchpadDeploy.s.sol:LaunchpadDeploy \
		--rpc-url $(RPC_URL) \
		--account $(WALLET_NAME) \
		--sender $(WALLET_ADDR) \
		--broadcast $(VERBOSITY)
	@echo "$(GREEN)✅ Launchpad deployment complete!$(NC)"

deploy-vrf: check-env ## Deploy VRF (Random Wallet Picker) contract
	@echo "$(BLUE)🎲 Deploying VRF contract...$(NC)"
	@echo "$(YELLOW)   Network: $(TARGET_ENV)$(NC)"
	@echo "$(YELLOW)   Wallet: $(WALLET_NAME)$(NC)"
	@echo "$(YELLOW)   Sender: $(WALLET_ADDR)$(NC)"
	@echo "$(YELLOW)   RPC: $(RPC_URL)$(NC)"
	forge script script/VRFDeploy.s.sol:VRFDeploy \
		--rpc-url $(RPC_URL) \
		--account $(WALLET_NAME) \
		--sender $(WALLET_ADDR) \
		--broadcast $(VERBOSITY)
	@echo "$(GREEN)✅ VRF deployment complete!$(NC)"
	@echo "$(YELLOW)⚠️  Remember to add the deployed contract as a consumer to your VRF subscription$(NC)"

deploy-staking: check-env ## Deploy LotryStaking contract
	@echo "$(BLUE)🏦 Deploying LotryStaking contract...$(NC)"
	@echo "$(YELLOW)   Network: $(TARGET_ENV)$(NC)"
	@echo "$(YELLOW)   Wallet: $(WALLET_NAME)$(NC)"
	@echo "$(YELLOW)   Sender: $(WALLET_ADDR)$(NC)"
	@echo "$(YELLOW)   RPC: $(RPC_URL)$(NC)"
	forge script script/DeployLotryStaking.s.sol:DeployLotryStaking \
		--rpc-url $(RPC_URL) \
		--account $(WALLET_NAME) \
		--sender $(WALLET_ADDR) \
		--broadcast $(VERBOSITY)
	@echo "$(GREEN)✅ LotryStaking deployment complete!$(NC)"
	@echo "$(YELLOW)ℹ️  Remember to call setStakeToken() to set the staking token$(NC)"

##@ Contract Verification

verify-launchpad: check-env ## Verify Launchpad contract
	@if [ -z "$(LAUNCHPAD_CA)" ]; then \
		echo "$(RED)❌ LAUNCHPAD_CA not set!$(NC)"; \
		echo "   Please add to your .env file:"; \
		echo "   $(YELLOW)LAUNCHPAD_CA=0x...$(NC)"; \
		exit 1; \
	fi
	@if [ -z "$(ETHERSCAN_API_KEY)" ]; then \
		echo "$(RED)❌ ETHERSCAN_API_KEY not set!$(NC)"; \
		echo "   Please add to your .env file:"; \
		echo "   $(YELLOW)ETHERSCAN_API_KEY=your_api_key$(NC)"; \
		exit 1; \
	fi
	@if [ -z "$(CHAIN_ID)" ]; then \
		echo "$(RED)❌ CHAIN_ID not set!$(NC)"; \
		echo "   Please add to your .env file:"; \
		echo "   $(YELLOW)CHAIN_ID=8453$(NC) (for Base) or $(YELLOW)CHAIN_ID=84532$(NC) (for Base Sepolia)"; \
		exit 1; \
	fi
	@echo "$(BLUE)✓ Verifying Launchpad contract...$(NC)"
	@echo "$(YELLOW)   Contract: $(LAUNCHPAD_CA)$(NC)"
	@echo "$(YELLOW)   Deployer: $(WALLET_ADDR)$(NC)"
	@echo "$(YELLOW)   Chain ID: $(CHAIN_ID)$(NC)"
	@CONSTRUCTOR_ARGS=$$(cast abi-encode "constructor(address)" $(WALLET_ADDR)); \
	forge verify-contract \
		--chain-id $(CHAIN_ID) \
		--constructor-args $$CONSTRUCTOR_ARGS \
		$(LAUNCHPAD_CA) \
		contracts/LotryLaunch.sol:LotryLaunch \
		--etherscan-api-key $(ETHERSCAN_API_KEY)
	@echo "$(GREEN)✅ Launchpad contract verified!$(NC)"

verify-vrf: check-env ## Verify RandomWalletPicker contract
	@if [ -z "$(VRF_CA)" ]; then \
		echo "$(RED)❌ VRF_CA not set!$(NC)"; \
		echo "   Please add to your .env file:"; \
		echo "   $(YELLOW)VRF_CA=0x...$(NC)"; \
		exit 1; \
	fi
	@if [ -z "$(VRF_COORDINATOR)" ]; then \
		echo "$(RED)❌ VRF_COORDINATOR not set!$(NC)"; \
		echo "   Please add to your .env file:"; \
		echo "   $(YELLOW)VRF_COORDINATOR=0x...$(NC)"; \
		exit 1; \
	fi
	@if [ -z "$(SUBSCRIPTION_ID)" ]; then \
		echo "$(RED)❌ SUBSCRIPTION_ID not set!$(NC)"; \
		echo "   Please add to your .env file:"; \
		echo "   $(YELLOW)SUBSCRIPTION_ID=123$(NC)"; \
		exit 1; \
	fi
	@if [ -z "$(KEY_HASH)" ]; then \
		echo "$(RED)❌ KEY_HASH not set!$(NC)"; \
		echo "   Please add to your .env file:"; \
		echo "   $(YELLOW)KEY_HASH=0x...$(NC)"; \
		exit 1; \
	fi
	@if [ -z "$(ETHERSCAN_API_KEY)" ]; then \
		echo "$(RED)❌ ETHERSCAN_API_KEY not set!$(NC)"; \
		echo "   Please add to your .env file:"; \
		echo "   $(YELLOW)ETHERSCAN_API_KEY=your_api_key$(NC)"; \
		exit 1; \
	fi
	@if [ -z "$(CHAIN_ID)" ]; then \
		echo "$(RED)❌ CHAIN_ID not set!$(NC)"; \
		echo "   Please add to your .env file:"; \
		echo "   $(YELLOW)CHAIN_ID=8453$(NC) (for Base) or $(YELLOW)CHAIN_ID=84532$(NC) (for Base Sepolia)"; \
		exit 1; \
	fi
	@echo "$(BLUE)✓ Verifying RandomWalletPicker contract...$(NC)"
	@echo "$(YELLOW)   Contract: $(VRF_CA)$(NC)"
	@echo "$(YELLOW)   VRF Coordinator: $(VRF_COORDINATOR)$(NC)"
	@echo "$(YELLOW)   Subscription ID: $(SUBSCRIPTION_ID)$(NC)"
	@echo "$(YELLOW)   Chain ID: $(CHAIN_ID)$(NC)"
	@CONSTRUCTOR_ARGS=$$(cast abi-encode "constructor(address,uint256,bytes32)" $(VRF_COORDINATOR) $(SUBSCRIPTION_ID) $(KEY_HASH)); \
	forge verify-contract \
		--chain-id $(CHAIN_ID) \
		--constructor-args $$CONSTRUCTOR_ARGS \
		$(VRF_CA) \
		contracts/RandomWalletPicker.sol:RandomWalletPicker \
		--etherscan-api-key $(ETHERSCAN_API_KEY)
	@echo "$(GREEN)✅ RandomWalletPicker contract verified!$(NC)"

verify-staking: check-env ## Verify LotryStaking contract (usage: make verify-staking STAKING_CA=0x...)
	@if [ -z "$(STAKING_CA)" ]; then \
		echo "$(RED)❌ STAKING_CA not set!$(NC)"; \
		echo "   Usage: make verify-staking STAKING_CA=0x..."; \
		echo "   Or add to your .env file: $(YELLOW)STAKING_CA=0x...$(NC)"; \
		exit 1; \
	fi
	@if [ -z "$(ETHERSCAN_API_KEY)" ]; then \
		echo "$(RED)❌ ETHERSCAN_API_KEY not set!$(NC)"; \
		echo "   Please add to your .env file:"; \
		echo "   $(YELLOW)ETHERSCAN_API_KEY=your_api_key$(NC)"; \
		exit 1; \
	fi
	@if [ -z "$(CHAIN_ID)" ]; then \
		echo "$(RED)❌ CHAIN_ID not set!$(NC)"; \
		echo "   Please add to your .env file:"; \
		echo "   $(YELLOW)CHAIN_ID=8453$(NC) (for Base) or $(YELLOW)CHAIN_ID=84532$(NC) (for Base Sepolia)"; \
		exit 1; \
	fi
	@echo "$(BLUE)✓ Verifying LotryStaking contract...$(NC)"
	@echo "$(YELLOW)   Contract: $(STAKING_CA)$(NC)"
	@echo "$(YELLOW)   Owner: $(WALLET_ADDR)$(NC)"
	@echo "$(YELLOW)   Chain ID: $(CHAIN_ID)$(NC)"
	@CONSTRUCTOR_ARGS=$$(cast abi-encode "constructor(address)" $(WALLET_ADDR)); \
	forge verify-contract \
		--chain-id $(CHAIN_ID) \
		--constructor-args $$CONSTRUCTOR_ARGS \
		--compiler-version 0.8.20 \
		--num-of-optimizations 200 \
		--via-ir \
		--watch \
		$(STAKING_CA) \
		contracts/LotryStaking.sol:LotryStaking \
		--etherscan-api-key $(ETHERSCAN_API_KEY)
	@echo "$(GREEN)✅ LotryStaking contract verified!$(NC)"

##@ VRF Operations

test-vrf: check-env ## Test VRF random wallet picker (requires DEPLOYED_VRF_CA env var)
	@if [ -z "$(DEPLOYED_VRF_CA)" ]; then \
		echo "$(RED)❌ DEPLOYED_VRF_CA not set!$(NC)"; \
		echo "   Usage: make test-vrf DEPLOYED_VRF_CA=0x..."; \
		exit 1; \
	fi
	@echo "$(BLUE)🎲 Testing VRF random wallet picker...$(NC)"
	@echo "$(YELLOW)   Contract: $(DEPLOYED_VRF_CA)$(NC)"
	@echo "$(YELLOW)   Network: $(TARGET_ENV)$(NC)"
	forge script script/testScripts/PickRandomWallet.s.sol:PickRandomWallet \
		--rpc-url $(RPC_URL) \
		--account $(WALLET_NAME) \
		--broadcast $(VERBOSITY)
	@echo "$(GREEN)✅ VRF test script executed!$(NC)"
	@echo "$(YELLOW)ℹ️  Note: Script runs synchronously. Check winner later with:$(NC)"
	@echo "   cast call $(DEPLOYED_VRF_CA) \"getPickedWallet()\" --rpc-url $(RPC_URL)"

check-winner: check-env ## Check the picked wallet from VRF contract (usage: make check-winner DEPLOYED_VRF_CA=0x...)
	@if [ -z "$(DEPLOYED_VRF_CA)" ]; then \
		echo "$(RED)❌ DEPLOYED_VRF_CA not set!$(NC)"; \
		echo "   Usage: make check-winner DEPLOYED_VRF_CA=0x..."; \
		exit 1; \
	fi
	@echo "$(BLUE)🔍 Checking picked wallet...$(NC)"
	@echo "$(YELLOW)   Contract: $(DEPLOYED_VRF_CA)$(NC)"
   cast call $(DEPLOYED_VRF_CA) "getPickedWallet()" --rpc-url $(RPC_URL)
	@echo "$(GREEN)✅ Winner Found!$(NC)"

##@ Token Launch & Verification

launch-token: check-env ## Launch a new token from Launchpad (usage: make launch-token TOKEN_NAME="MyToken" TOKEN_SYMBOL="MTK")
	@if [ -z "$(LAUNCHPAD_CA)" ]; then \
		echo "$(RED)❌ LAUNCHPAD_CA not set!$(NC)"; \
		echo "   Please add to your .env file:"; \
		echo "   $(YELLOW)LAUNCHPAD_CA=0x...$(NC)"; \
		exit 1; \
	fi
	@if [ -z "$(TOKEN_NAME)" ]; then \
		echo "$(RED)❌ TOKEN_NAME not set!$(NC)"; \
		echo "   Usage: make launch-token TOKEN_NAME=\"MyToken\" TOKEN_SYMBOL=\"MTK\""; \
		exit 1; \
	fi
	@if [ -z "$(TOKEN_SYMBOL)" ]; then \
		echo "$(RED)❌ TOKEN_SYMBOL not set!$(NC)"; \
		echo "   Usage: make launch-token TOKEN_NAME=\"MyToken\" TOKEN_SYMBOL=\"MTK\""; \
		exit 1; \
	fi
	@echo "$(BLUE)🚀 Launching new token...$(NC)"
	@echo "$(YELLOW)   Launchpad: $(LAUNCHPAD_CA)$(NC)"
	@echo "$(YELLOW)   Token Name: $(TOKEN_NAME)$(NC)"
	@echo "$(YELLOW)   Token Symbol: $(TOKEN_SYMBOL)$(NC)"
	cast send $(LAUNCHPAD_CA) "launchToken(string,string)" "$(TOKEN_NAME)" "$(TOKEN_SYMBOL)" \
		--rpc-url $(RPC_URL) \
		--account $(WALLET_NAME)
	@echo "$(GREEN)✅ Token launched!$(NC)"
	@echo "$(YELLOW)ℹ️  Check the transaction receipt for the token address$(NC)"
	@echo "$(YELLOW)ℹ️  Or check the TokenCreated event logs$(NC)"

verify-token: check-env ## Verify a LotryTicket token contract (usage: make verify-token TOKEN_CA=0x... TOKEN_NAME="MyToken" TOKEN_SYMBOL="MTK")
	@if [ -z "$(TOKEN_CA)" ]; then \
		echo "$(RED)❌ TOKEN_CA not set!$(NC)"; \
		echo "   Please add to your .env file or pass as parameter:"; \
		echo "   $(YELLOW)TOKEN_CA=0x...$(NC)"; \
		exit 1; \
	fi
	@if [ -z "$(TOKEN_NAME)" ]; then \
		echo "$(RED)❌ TOKEN_NAME not set!$(NC)"; \
		echo "   Usage: make verify-token TOKEN_CA=0x... TOKEN_NAME=\"MyToken\" TOKEN_SYMBOL=\"MTK\""; \
		exit 1; \
	fi
	@if [ -z "$(TOKEN_SYMBOL)" ]; then \
		echo "$(RED)❌ TOKEN_SYMBOL not set!$(NC)"; \
		echo "   Usage: make verify-token TOKEN_CA=0x... TOKEN_NAME=\"MyToken\" TOKEN_SYMBOL=\"MTK\""; \
		exit 1; \
	fi
	@if [ -z "$(ETHERSCAN_API_KEY)" ]; then \
		echo "$(RED)❌ ETHERSCAN_API_KEY not set!$(NC)"; \
		echo "   Please add to your .env file:"; \
		echo "   $(YELLOW)ETHERSCAN_API_KEY=your_api_key$(NC)"; \
		exit 1; \
	fi
	@if [ -z "$(CHAIN_ID)" ]; then \
		echo "$(RED)❌ CHAIN_ID not set!$(NC)"; \
		echo "   Please add to your .env file:"; \
		echo "   $(YELLOW)CHAIN_ID=8453$(NC) (for Base) or $(YELLOW)CHAIN_ID=84532$(NC) (for Base Sepolia)"; \
		exit 1; \
	fi
	@echo "$(BLUE)✓ Verifying LotryTicket token...$(NC)"
	@echo "$(YELLOW)   Contract: $(TOKEN_CA)$(NC)"
	@echo "$(YELLOW)   Name: $(TOKEN_NAME)$(NC)"
	@echo "$(YELLOW)   Symbol: $(TOKEN_SYMBOL)$(NC)"
	@echo "$(YELLOW)   Initial Owner: $(WALLET_ADDR)$(NC)"
	@echo "$(YELLOW)   Chain ID: $(CHAIN_ID)$(NC)"
	@CONSTRUCTOR_ARGS=$$(cast abi-encode "constructor(string,string,address)" "$(TOKEN_NAME)" "$(TOKEN_SYMBOL)" $(WALLET_ADDR)); \
	forge verify-contract \
		--chain-id $(CHAIN_ID) \
		--constructor-args $$CONSTRUCTOR_ARGS \
		$(TOKEN_CA) \
		contracts/LotryTicket.sol:LotryTicket \
		--etherscan-api-key $(ETHERSCAN_API_KEY)
	@echo "$(GREEN)✅ LotryTicket token verified!$(NC)"

##@ Token Operations

generate-tokens: check-env ## Generate tokens to the wallets
	@echo "$(BLUE)💰 Generating ERC20 tokens...$(NC)"
	@echo "$(YELLOW)   Network: $(TARGET_ENV)$(NC)"
	@echo "$(YELLOW)   Wallet: $(WALLET_NAME)$(NC)"
	forge script script/TokenGenerator.s.sol:TokenGenerator \
		--rpc-url $(RPC_URL) \
		--account $(WALLET_NAME) \
		--sender $(WALLET_ADDR) \
		--broadcast $(VERBOSITY)
	@echo "$(GREEN)✅ Token generation complete!$(NC)"

##@ LotryTicket Contract Operations

set-lotry-token: check-env ## Set the LOTRY token address (usage: make set-lotry-token TICKET_CA=0x... LOTRY_TOKEN=0x...)
	@if [ -z "$(TICKET_CA)" ]; then \
		echo "$(RED)❌ TICKET_CA not set!$(NC)"; \
		echo "   Usage: make set-lotry-token TICKET_CA=0x... LOTRY_TOKEN=0x..."; \
		exit 1; \
	fi
	@if [ -z "$(LOTRY_TOKEN)" ]; then \
		echo "$(RED)❌ LOTRY_TOKEN not set!$(NC)"; \
		echo "   Usage: make set-lotry-token TICKET_CA=0x... LOTRY_TOKEN=0x..."; \
		exit 1; \
	fi
	@echo "$(BLUE)🎫 Setting LOTRY token address...$(NC)"
	@echo "$(YELLOW)   Ticket Contract: $(TICKET_CA)$(NC)"
	@echo "$(YELLOW)   LOTRY Token: $(LOTRY_TOKEN)$(NC)"
	cast send $(TICKET_CA) "setLotryToken(address)" $(LOTRY_TOKEN) --rpc-url $(RPC_URL) --account $(WALLET_NAME)
	@echo "$(GREEN)✅ LOTRY token address set!$(NC)"

set-reward-token: check-env ## Set the reward token address (usage: make set-reward-token TICKET_CA=0x... REWARD_TOKEN=0x...)
	@if [ -z "$(TICKET_CA)" ]; then \
		echo "$(RED)❌ TICKET_CA not set!$(NC)"; \
		echo "   Usage: make set-reward-token TICKET_CA=0x... REWARD_TOKEN=0x..."; \
		exit 1; \
	fi
	@if [ -z "$(REWARD_TOKEN)" ]; then \
		echo "$(RED)❌ REWARD_TOKEN not set!$(NC)"; \
		echo "   Usage: make set-reward-token TICKET_CA=0x... REWARD_TOKEN=0x..."; \
		exit 1; \
	fi
	@echo "$(BLUE)🎁 Setting reward token address...$(NC)"
	@echo "$(YELLOW)   Ticket Contract: $(TICKET_CA)$(NC)"
	@echo "$(YELLOW)   Reward Token: $(REWARD_TOKEN)$(NC)"
	cast send $(TICKET_CA) "setRewardToken(address)" $(REWARD_TOKEN) --rpc-url $(RPC_URL) --account $(WALLET_NAME)
	@echo "$(GREEN)✅ Reward token address set!$(NC)"

deposit-lotry: check-env ## Deposit LOTRY tokens to pool (usage: make deposit-lotry TICKET_CA=0x... LOTRY_TOKEN=0x... AMOUNT=10)
	@if [ -z "$(TICKET_CA)" ]; then \
		echo "$(RED)❌ TICKET_CA not set!$(NC)"; \
		echo "   Usage: make deposit-lotry TICKET_CA=0x... LOTRY_TOKEN=0x... AMOUNT=10"; \
		exit 1; \
	fi
	@if [ -z "$(LOTRY_TOKEN)" ]; then \
		echo "$(RED)❌ LOTRY_TOKEN not set!$(NC)"; \
		echo "   Usage: make deposit-lotry TICKET_CA=0x... LOTRY_TOKEN=0x... AMOUNT=10"; \
		exit 1; \
	fi
	@if [ -z "$(AMOUNT)" ]; then \
		echo "$(RED)❌ AMOUNT not set!$(NC)"; \
		echo "   Usage: make deposit-lotry TICKET_CA=0x... LOTRY_TOKEN=0x... AMOUNT=10"; \
		echo "   Example: AMOUNT=10 for 10 tokens (automatically multiplied by 1e18)"; \
		exit 1; \
	fi
	@echo "$(BLUE)💰 Depositing LOTRY tokens...$(NC)"
	@echo "$(YELLOW)   Amount: $(AMOUNT) tokens$(NC)"
	@echo "$(YELLOW)   Step 1: Approving tokens...$(NC)"
	cast send $(LOTRY_TOKEN) "approve(address,uint256)" $(TICKET_CA) $(shell echo "$(AMOUNT) * 1000000000000000000" | bc) --rpc-url $(RPC_URL) --account $(WALLET_NAME)
	@echo "$(YELLOW)   Step 2: Depositing tokens...$(NC)"
	cast send $(TICKET_CA) "depositLotryTokens(uint256)" $(shell echo "$(AMOUNT) * 1000000000000000000" | bc) --rpc-url $(RPC_URL) --account $(WALLET_NAME)
	@echo "$(GREEN)✅ LOTRY tokens deposited!$(NC)"

deposit-reward: check-env ## Deposit reward tokens to pool (usage: make deposit-reward TICKET_CA=0x... REWARD_TOKEN=0x... AMOUNT=100)
	@if [ -z "$(TICKET_CA)" ]; then \
		echo "$(RED)❌ TICKET_CA not set!$(NC)"; \
		echo "   Usage: make deposit-reward TICKET_CA=0x... REWARD_TOKEN=0x... AMOUNT=100"; \
		exit 1; \
	fi
	@if [ -z "$(REWARD_TOKEN)" ]; then \
		echo "$(RED)❌ REWARD_TOKEN not set!$(NC)"; \
		echo "   Usage: make deposit-reward TICKET_CA=0x... REWARD_TOKEN=0x... AMOUNT=100"; \
		exit 1; \
	fi
	@if [ -z "$(AMOUNT)" ]; then \
		echo "$(RED)❌ AMOUNT not set!$(NC)"; \
		echo "   Usage: make deposit-reward TICKET_CA=0x... REWARD_TOKEN=0x... AMOUNT=100"; \
		echo "   Example: AMOUNT=100 for 100 tokens (automatically multiplied by 1e18)"; \
		exit 1; \
	fi
	@echo "$(BLUE)🎁 Depositing reward tokens (USDC)...$(NC)"
	@echo "$(YELLOW)   Amount: $(AMOUNT) tokens$(NC)"
	@echo "$(YELLOW)   Step 1: Approving tokens...$(NC)"
	cast send $(REWARD_TOKEN) "approve(address,uint256)" $(TICKET_CA) $(shell echo "$(AMOUNT) * 1000000" | bc) --rpc-url $(RPC_URL) --account $(WALLET_NAME)
	@echo "$(YELLOW)   Step 2: Depositing tokens...$(NC)"
	cast send $(TICKET_CA) "depositRewardTokens(uint256)" $(shell echo "$(AMOUNT) * 1000000" | bc) --rpc-url $(RPC_URL) --account $(WALLET_NAME)
	@echo "$(GREEN)✅ Reward tokens deposited!$(NC)"

send-to-staking: check-env ## Send minted tokens to staking contract (usage: make send-to-staking TICKET_CA=0x... STAKE_CONTRACT=0x... AMOUNT=1000000)
	@if [ -z "$(TICKET_CA)" ]; then \
		echo "$(RED)❌ TICKET_CA not set!$(NC)"; \
		echo "   Usage: make send-to-staking TICKET_CA=0x... STAKE_CONTRACT=0x... AMOUNT=1000000"; \
		exit 1; \
	fi
	@if [ -z "$(STAKE_CONTRACT)" ]; then \
		echo "$(RED)❌ STAKE_CONTRACT not set!$(NC)"; \
		echo "   Usage: make send-to-staking TICKET_CA=0x... STAKE_CONTRACT=0x... AMOUNT=1000000"; \
		exit 1; \
	fi
	@if [ -z "$(AMOUNT)" ]; then \
		echo "$(RED)❌ AMOUNT not set!$(NC)"; \
		echo "   Usage: make send-to-staking TICKET_CA=0x... STAKE_CONTRACT=0x... AMOUNT=1000000"; \
		echo "   Example: AMOUNT=1000000 for 1M tokens (automatically multiplied by 1e18)"; \
		exit 1; \
	fi
	@echo "$(BLUE)🏦 Sending tokens to staking contract...$(NC)"
	@echo "$(YELLOW)   Ticket Contract: $(TICKET_CA)$(NC)"
	@echo "$(YELLOW)   Stake Contract: $(STAKE_CONTRACT)$(NC)"
	@echo "$(YELLOW)   Amount: $(AMOUNT) tokens$(NC)"
	cast send $(TICKET_CA) "sendToStaking(address,uint256)" $(STAKE_CONTRACT) $(shell echo "$(AMOUNT) * 1000000000000000000" | bc) --rpc-url $(RPC_URL) --account $(WALLET_NAME)
	@echo "$(GREEN)✅ Tokens sent to staking contract!$(NC)"

##@ LotryTicket Contract Views

check-pool-fee: check-env ## Check accumulated pool fee balance (usage: make check-pool-fee TICKET_CA=0x...)
	@if [ -z "$(TICKET_CA)" ]; then \
		echo "$(RED)❌ TICKET_CA not set!$(NC)"; \
		echo "   Usage: make check-pool-fee TICKET_CA=0x..."; \
		exit 1; \
	fi
	@echo "$(BLUE)🔍 Checking accumulated pool fee...$(NC)"
	@echo "$(YELLOW)   Contract: $(TICKET_CA)$(NC)"
	@result=$$(cast call $(TICKET_CA) "accumulatedPoolFee()(uint256)" --rpc-url $(RPC_URL) | sed 's/ \[.*\]//'); \
	formatted=$$(cast --from-wei $$result); \
	echo "$(GREEN)   Raw: $$result wei$(NC)"; \
	echo "$(WHITE)   Formatted: $$formatted LOTRY$(NC)"

check-reward-token-address: check-env ## View reward token address (usage: make check-reward-token-address TICKET_CA=0x...)
	@if [ -z "$(TICKET_CA)" ]; then \
		echo "$(RED)❌ TICKET_CA not set!$(NC)"; \
		echo "   Usage: make check-reward-token-address TICKET_CA=0x..."; \
		exit 1; \
	fi
	@echo "$(BLUE)🔍 Checking reward token address...$(NC)"
	@echo "$(YELLOW)   Contract: $(TICKET_CA)$(NC)"
	cast call $(TICKET_CA) "rewardTokenAddress()(address)" --rpc-url $(RPC_URL)

check-lotry-token-address: check-env ## View LOTRY token address (usage: make check-lotry-token-address TICKET_CA=0x...)
	@if [ -z "$(TICKET_CA)" ]; then \
		echo "$(RED)❌ TICKET_CA not set!$(NC)"; \
		echo "   Usage: make check-lotry-token-address TICKET_CA=0x..."; \
		exit 1; \
	fi
	@echo "$(BLUE)🔍 Checking LOTRY token address...$(NC)"
	@echo "$(YELLOW)   Contract: $(TICKET_CA)$(NC)"
	cast call $(TICKET_CA) "lotryTokenAddress()(address)" --rpc-url $(RPC_URL)

check-reward-balance: check-env ## Check reward token balance in contract (usage: make check-reward-balance TICKET_CA=0x...)
	@if [ -z "$(TICKET_CA)" ]; then \
		echo "$(RED)❌ TICKET_CA not set!$(NC)"; \
		echo "   Usage: make check-reward-balance TICKET_CA=0x..."; \
		exit 1; \
	fi
	@echo "$(BLUE)🔍 Checking reward token balance...$(NC)"
	@echo "$(YELLOW)   Contract: $(TICKET_CA)$(NC)"
	@result=$$(cast call $(TICKET_CA) "getRewardTokenBalance()(uint256)" --rpc-url $(RPC_URL) | sed 's/ \[.*\]//'); \
	formatted=$$(cast --from-wei $$result); \
	echo "$(GREEN)   Raw: $$result wei$(NC)"; \
	echo "$(WHITE)   Formatted: $$formatted tokens$(NC)"

check-lotry-balance: check-env ## Check LOTRY token balance in contract (usage: make check-lotry-balance TICKET_CA=0x...)
	@if [ -z "$(TICKET_CA)" ]; then \
		echo "$(RED)❌ TICKET_CA not set!$(NC)"; \
		echo "   Usage: make check-lotry-balance TICKET_CA=0x..."; \
		exit 1; \
	fi
	@echo "$(BLUE)🔍 Checking LOTRY token balance...$(NC)"
	@echo "$(YELLOW)   Contract: $(TICKET_CA)$(NC)"
	@result=$$(cast call $(TICKET_CA) "getLotryBalance()(uint256)" --rpc-url $(RPC_URL) | sed 's/ \[.*\]//'); \
	formatted=$$(cast --from-wei $$result); \
	echo "$(GREEN)   Raw: $$result wei$(NC)"; \
	echo "$(WHITE)   Formatted: $$formatted LOTRY$(NC)"

check-current-price: check-env ## Check current token price (usage: make check-current-price TICKET_CA=0x...)
	@if [ -z "$(TICKET_CA)" ]; then \
		echo "$(RED)❌ TICKET_CA not set!$(NC)"; \
		echo "   Usage: make check-current-price TICKET_CA=0x..."; \
		exit 1; \
	fi
	@echo "$(BLUE)🔍 Checking current price...$(NC)"
	@echo "$(YELLOW)   Contract: $(TICKET_CA)$(NC)"
	@result=$$(cast call $(TICKET_CA) "calculateCurrentPriceExternal()(uint256)" --rpc-url $(RPC_URL) | sed 's/ \[.*\]//'); \
	formatted=$$(cast --from-wei $$result); \
	echo "$(GREEN)   Raw: $$result wei$(NC)"; \
	echo "$(WHITE)   Formatted: $$formatted LOTRY per token$(NC)"

check-lotry-raised: check-env ## Check total LOTRY raised (usage: make check-lotry-raised TICKET_CA=0x...)
	@if [ -z "$(TICKET_CA)" ]; then \
		echo "$(RED)❌ TICKET_CA not set!$(NC)"; \
		echo "   Usage: make check-lotry-raised TICKET_CA=0x..."; \
		exit 1; \
	fi
	@echo "$(BLUE)🔍 Checking LOTRY raised...$(NC)"
	@echo "$(YELLOW)   Contract: $(TICKET_CA)$(NC)"
	@result=$$(cast call $(TICKET_CA) "getLotryRaisedExternal()(uint256)" --rpc-url $(RPC_URL) | sed 's/ \[.*\]//'); \
	formatted=$$(cast --from-wei $$result); \
	echo "$(GREEN)   Raw: $$result wei$(NC)"; \
	echo "$(WHITE)   Formatted: $$formatted LOTRY$(NC)"

##@ LotryStaking Contract Operations

set-stake-token: check-env ## Set the staking token address (usage: make set-stake-token STAKING_CA=0x... STAKE_TOKEN=0x...)
	@if [ -z "$(STAKING_CA)" ]; then \
		echo "$(RED)❌ STAKING_CA not set!$(NC)"; \
		echo "   Usage: make set-stake-token STAKING_CA=0x... STAKE_TOKEN=0x..."; \
		exit 1; \
	fi
	@if [ -z "$(STAKE_TOKEN)" ]; then \
		echo "$(RED)❌ STAKE_TOKEN not set!$(NC)"; \
		echo "   Usage: make set-stake-token STAKING_CA=0x... STAKE_TOKEN=0x..."; \
		exit 1; \
	fi
	@echo "$(BLUE)🏦 Setting stake token address...$(NC)"
	@echo "$(YELLOW)   Staking Contract: $(STAKING_CA)$(NC)"
	@echo "$(YELLOW)   Stake Token: $(STAKE_TOKEN)$(NC)"
	cast send $(STAKING_CA) "setStakeToken(address)" $(STAKE_TOKEN) --rpc-url $(RPC_URL) --account $(WALLET_NAME)
	@echo "$(GREEN)✅ Stake token address set!$(NC)"

stake-lotry: check-env ## Stake LOTRY tokens (usage: make stake-lotry STAKING_CA=0x... STAKE_TOKEN=0x... AMOUNT=1000)
	@if [ -z "$(STAKING_CA)" ]; then \
		echo "$(RED)❌ STAKING_CA not set!$(NC)"; \
		echo "   Usage: make stake-lotry STAKING_CA=0x... STAKE_TOKEN=0x... AMOUNT=1000"; \
		exit 1; \
	fi
	@if [ -z "$(STAKE_TOKEN)" ]; then \
		echo "$(RED)❌ STAKE_TOKEN not set!$(NC)"; \
		echo "   Usage: make stake-lotry STAKING_CA=0x... STAKE_TOKEN=0x... AMOUNT=1000"; \
		exit 1; \
	fi
	@if [ -z "$(AMOUNT)" ]; then \
		echo "$(RED)❌ AMOUNT not set!$(NC)"; \
		echo "   Usage: make stake-lotry STAKING_CA=0x... STAKE_TOKEN=0x... AMOUNT=1000"; \
		echo "   Example: AMOUNT=1000 for 1000 tokens (automatically multiplied by 1e18)"; \
		exit 1; \
	fi
	@echo "$(BLUE)🏦 Staking LOTRY tokens...$(NC)"
	@echo "$(YELLOW)   Amount: $(AMOUNT) tokens$(NC)"
	@echo "$(YELLOW)   Step 1: Approving tokens...$(NC)"
	cast send $(STAKE_TOKEN) "approve(address,uint256)" $(STAKING_CA) $(shell echo "$(AMOUNT) * 1000000000000000000" | bc) --rpc-url $(RPC_URL) --account $(WALLET_NAME)
	@echo "$(YELLOW)   Step 2: Staking tokens...$(NC)"
	cast send $(STAKING_CA) "stake(uint256)" $(shell echo "$(AMOUNT) * 1000000000000000000" | bc) --rpc-url $(RPC_URL) --account $(WALLET_NAME)
	@echo "$(GREEN)✅ LOTRY tokens staked!$(NC)"

withdraw-all-staked: check-env ## Withdraw all staked tokens to admin wallet (owner only) (usage: make withdraw-all-staked STAKING_CA=0x...)
	@if [ -z "$(STAKING_CA)" ]; then \
		echo "$(RED)❌ STAKING_CA not set!$(NC)"; \
		echo "   Usage: make withdraw-all-staked STAKING_CA=0x..."; \
		exit 1; \
	fi
	@echo "$(BLUE)💸 Withdrawing all staked tokens to admin wallet...$(NC)"
	@echo "$(YELLOW)   Staking Contract: $(STAKING_CA)$(NC)"
	@echo "$(YELLOW)   Admin Wallet: $(WALLET_ADDR)$(NC)"
	cast send $(STAKING_CA) "withdrawAll()" --rpc-url $(RPC_URL) --account $(WALLET_NAME)
	@echo "$(GREEN)✅ All staked tokens withdrawn to admin wallet!$(NC)"

##@ LotryStaking Contract Views

get-all-staked: check-env ## Get all stakers and their staked amounts (owner only) (usage: make get-all-staked STAKING_CA=0x...)
	@if [ -z "$(STAKING_CA)" ]; then \
		echo "$(RED)❌ STAKING_CA not set!$(NC)"; \
		echo "   Usage: make get-all-staked STAKING_CA=0x..."; \
		exit 1; \
	fi
	@echo "$(BLUE)🔍 Getting all staked amounts...$(NC)"
	@echo "$(YELLOW)   Contract: $(STAKING_CA)$(NC)"
	@echo "$(YELLOW)   Caller (owner): $(WALLET_ADDR)$(NC)"
	@echo ""
	cast call $(STAKING_CA) "getAllStakedAmounts()(address[],uint256[],uint256)" --from $(WALLET_ADDR) --rpc-url $(RPC_URL)

check-stake-token: check-env ## Check stake token address (usage: make check-stake-token STAKING_CA=0x...)
	@if [ -z "$(STAKING_CA)" ]; then \
		echo "$(RED)❌ STAKING_CA not set!$(NC)"; \
		echo "   Usage: make check-stake-token STAKING_CA=0x..."; \
		exit 1; \
	fi
	@echo "$(BLUE)🔍 Checking stake token address...$(NC)"
	@echo "$(YELLOW)   Contract: $(STAKING_CA)$(NC)"
	cast call $(STAKING_CA) "stakeToken()(address)" --rpc-url $(RPC_URL)

check-total-staked: check-env ## Check total staked amount (usage: make check-total-staked STAKING_CA=0x...)
	@if [ -z "$(STAKING_CA)" ]; then \
		echo "$(RED)❌ STAKING_CA not set!$(NC)"; \
		echo "   Usage: make check-total-staked STAKING_CA=0x..."; \
		exit 1; \
	fi
	@echo "$(BLUE)🔍 Checking total staked...$(NC)"
	@echo "$(YELLOW)   Contract: $(STAKING_CA)$(NC)"
	@result=$$(cast call $(STAKING_CA) "totalStaked()(uint256)" --rpc-url $(RPC_URL) | sed 's/ \[.*\]//'); \
	formatted=$$(cast --from-wei $$result); \
	echo "$(GREEN)   Raw: $$result wei$(NC)"; \
	echo "$(WHITE)   Formatted: $$formatted LOTRY$(NC)"

check-user-stake: check-env ## Check user's staked amount (usage: make check-user-stake STAKING_CA=0x... USER_ADDR=0x...)
	@if [ -z "$(STAKING_CA)" ]; then \
		echo "$(RED)❌ STAKING_CA not set!$(NC)"; \
		echo "   Usage: make check-user-stake STAKING_CA=0x... USER_ADDR=0x..."; \
		exit 1; \
	fi
	@if [ -z "$(USER_ADDR)" ]; then \
		echo "$(RED)❌ USER_ADDR not set!$(NC)"; \
		echo "   Usage: make check-user-stake STAKING_CA=0x... USER_ADDR=0x..."; \
		exit 1; \
	fi
	@echo "$(BLUE)🔍 Checking user stake amount...$(NC)"
	@echo "$(YELLOW)   Contract: $(STAKING_CA)$(NC)"
	@echo "$(YELLOW)   User: $(USER_ADDR)$(NC)"
	@result=$$(cast call $(STAKING_CA) "getStakeAmount(address)(uint256)" $(USER_ADDR) --rpc-url $(RPC_URL) | sed 's/ \[.*\]//'); \
	formatted=$$(cast --from-wei $$result); \
	echo "$(GREEN)   Raw: $$result wei$(NC)"; \
	echo "$(WHITE)   Formatted: $$formatted LOTRY$(NC)"

check-stakers-count: check-env ## Check total number of stakers (usage: make check-stakers-count STAKING_CA=0x...)
	@if [ -z "$(STAKING_CA)" ]; then \
		echo "$(RED)❌ STAKING_CA not set!$(NC)"; \
		echo "   Usage: make check-stakers-count STAKING_CA=0x..."; \
		exit 1; \
	fi
	@echo "$(BLUE)🔍 Checking stakers count...$(NC)"
	@echo "$(YELLOW)   Contract: $(STAKING_CA)$(NC)"
	cast call $(STAKING_CA) "getStakersCount()(uint256)" --rpc-url $(RPC_URL)

check-is-staker: check-env ## Check if address is a staker (usage: make check-is-staker STAKING_CA=0x... USER_ADDR=0x...)
	@if [ -z "$(STAKING_CA)" ]; then \
		echo "$(RED)❌ STAKING_CA not set!$(NC)"; \
		echo "   Usage: make check-is-staker STAKING_CA=0x... USER_ADDR=0x..."; \
		exit 1; \
	fi
	@if [ -z "$(USER_ADDR)" ]; then \
		echo "$(RED)❌ USER_ADDR not set!$(NC)"; \
		echo "   Usage: make check-is-staker STAKING_CA=0x... USER_ADDR=0x..."; \
		exit 1; \
	fi
	@echo "$(BLUE)🔍 Checking if user is a staker...$(NC)"
	@echo "$(YELLOW)   Contract: $(STAKING_CA)$(NC)"
	@echo "$(YELLOW)   User: $(USER_ADDR)$(NC)"
	cast call $(STAKING_CA) "isStaker(address)(bool)" $(USER_ADDR) --rpc-url $(RPC_URL)

##@ Quick Commands

setup: install build test ## Install, build, and test all contracts
	@echo "$(GREEN)✅ Project setup complete!$(NC)"

deploy-all: deploy-launchpad deploy-vrf deploy-staking ## Deploy Launchpad, VRF, and Staking contracts
	@echo "$(GREEN)✅ All deployments complete!$(NC)"
