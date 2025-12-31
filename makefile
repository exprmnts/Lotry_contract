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

##@ General

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
	@awk 'BEGIN {FS = ":.*##"; printf ""} /^[a-zA-Z_-]+:.*?##/ { printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2 } /^##@/ { sub(/^##@[ \t]+/, "", $$0); printf "\n$(BLUE)%s$(NC)\n", $$0 } ' $(MAKEFILE_LIST)
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

deploy-launchpad: check-env ## Deploy Launchpad contract (optional: sender=<wallet address>)
	@echo "$(BLUE)🚀 Deploying Launchpad contract...$(NC)"
	@echo "$(YELLOW)   Network: $(TARGET_ENV)$(NC)"
	@echo "$(YELLOW)   Wallet: $(WALLET_NAME)$(NC)"
	@if [ -n "$(sender)" ]; then \
		echo "$(YELLOW)   Sender: $(sender)$(NC)"; \
	fi
	@echo "$(YELLOW)   RPC: $(RPC_URL)$(NC)"
	@if [ -n "$(sender)" ]; then \
		forge script script/LaunchpadDeploy.s.sol:LaunchpadDeploy \
			--rpc-url $(RPC_URL) \
			--account $(WALLET_NAME) \
			--sender $(sender) \
			--broadcast $(VERBOSITY); \
	else \
		forge script script/LaunchpadDeploy.s.sol:LaunchpadDeploy \
			--rpc-url $(RPC_URL) \
			--account $(WALLET_NAME) \
			--broadcast $(VERBOSITY); \
	fi
	@echo "$(GREEN)✅ Launchpad deployment complete!$(NC)"

deploy-vrf: check-env ## Deploy VRF (Random Wallet Picker) contract (optional: sender=<wallet address>)
	@echo "$(BLUE)🎲 Deploying VRF contract...$(NC)"
	@echo "$(YELLOW)   Network: $(TARGET_ENV)$(NC)"
	@echo "$(YELLOW)   Wallet: $(WALLET_NAME)$(NC)"
	@if [ -n "$(sender)" ]; then \
		echo "$(YELLOW)   Sender: $(sender)$(NC)"; \
	fi
	@echo "$(YELLOW)   RPC: $(RPC_URL)$(NC)"
	@if [ -n "$(sender)" ]; then \
		forge script script/VRFDeploy.s.sol:VRFDeploy \
			--rpc-url $(RPC_URL) \
			--account $(WALLET_NAME) \
			--sender $(sender) \
			--broadcast \
			--verify $(VERBOSITY); \
	else \
		forge script script/VRFDeploy.s.sol:VRFDeploy \
			--rpc-url $(RPC_URL) \
			--account $(WALLET_NAME) \
			--broadcast \
			--verify $(VERBOSITY); \
	fi
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

##@ Quick Commands

setup: install build test ## Install, build, and test all contracts
	@echo "$(GREEN)✅ Project setup complete!$(NC)"

deploy-all: deploy-launchpad deploy-vrf ## Deploy both Launchpad and VRF contracts
	@echo "$(GREEN)✅ All deployments complete!$(NC)"
