.PHONY: help install build test deploy launchpad vrf test-vrf clean coverage env-setup wallet-import wallet-list check-env

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
		--broadcast \
		--verify $(VERBOSITY)
	@echo "$(GREEN)✅ VRF deployment complete!$(NC)"
	@echo "$(YELLOW)⚠️  Remember to add the deployed contract as a consumer to your VRF subscription$(NC)"

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
	@echo "$(BLUE)🎁 Depositing reward tokens...$(NC)"
	@echo "$(YELLOW)   Amount: $(AMOUNT) tokens$(NC)"
	@echo "$(YELLOW)   Step 1: Approving tokens...$(NC)"
	cast send $(REWARD_TOKEN) "approve(address,uint256)" $(TICKET_CA) $(shell echo "$(AMOUNT) * 1000000000000000000" | bc) --rpc-url $(RPC_URL) --account $(WALLET_NAME)
	@echo "$(YELLOW)   Step 2: Depositing tokens...$(NC)"
	cast send $(TICKET_CA) "depositRewardTokens(uint256)" $(shell echo "$(AMOUNT) * 1000000000000000000" | bc) --rpc-url $(RPC_URL) --account $(WALLET_NAME)
	@echo "$(GREEN)✅ Reward tokens deposited!$(NC)"

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

##@ Quick Commands

setup: install build test ## Install, build, and test all contracts
	@echo "$(GREEN)✅ Project setup complete!$(NC)"

deploy-all: deploy-launchpad deploy-vrf ## Deploy both Launchpad and VRF contracts
	@echo "$(GREEN)✅ All deployments complete!$(NC)"
