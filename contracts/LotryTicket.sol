// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/*
                            ⠀⠀⠀⠀⠀ ⠀⢀⣤⣿⣶⣄⠀⠀⠀⣀⡀⠀⠀⠀⠀ 
                            ⠀⠀⣠⣤⣄⡀⣼⣿⣿⣿⣿⠀⣠⣾⣿⣿⡆⠀⠀⠀  
                            ⠀⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣶⣿⣿⣿⣿⣧⣄⡀⠀  
                            ⠀⠀⠻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡄  
                            ⠀⠀⣀⣤⣽⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠃  
                            ⢰⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣩⡉⠀⠀  
                            ⠹⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣄  
                            ⠀⠀⠉⣸⣿⣿⣿⣿⠏⢸⡏⣿⣿⣿⣿⣿⣿⣿⣿⡏  
                            ⠀⠀⠀⢿⣿⣿⡿⠏⠀⢸⣇⢻⣿⣿⣿⣿⠉⠉⠁⠀  
                            ⠀⠀⠀⠀⠈⠁⠀⠀⠀⠸⣿⡀⠙⠿⠿⠋⠀⠀⠀⠀  
                            ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢹⣿⡀⠀⠀⠀⠀⠀⠀⠀  

                    
                █   █▀█ ▀█▀ █▀█ █▄█   █▀█ █▀█ █▀█ ▀█▀ █▀█ █▀▀ █▀█ █
                █▄▄ █▄█  █  █▀▄  █    █▀▀ █▀▄ █▄█  █  █▄█ █▄▄ █▄█ █▄▄

*/

/**
 * @title Lotry Ticket ERC20 Token
 * @author Arjun C, Aarone George
 * @notice This contract defines the Lotry Ticket ERC20 token, which incorporates a bonding curve for dynamic pricing, a tax mechanism on trades, and features for reward distribution and liquidity management.
 * @dev The token's price is governed by a constant product bonding curve. It includes functions for buying and selling tokens, applying a percentage tax on transactions, and managing the distribution of accumulated funds for rewards and protocol operations.
 */
contract LotryTicket is Ownable, ERC20, ReentrancyGuard {
    uint256 private constant MIN_BUY = 0.00001 ether;
    uint256 private constant ONE_ETHER = 1e18;
    uint256 private constant TAX_NUMERATOR = 20;
    uint256 private constant TAX_DENOMINATOR = 100;
    uint256 private constant VIRTUAL_TOKEN_RESERVE = 17525652865772000000000000; // 17,525,652.865772
    uint256 private constant VIRTUAL_ETH_RESERVE = 1271907066082000000; // 1.271907066082 ETH
    uint256 private constant INITIAL_SUPPLY = 1_000_000_000_000_000_000_000_000_000;
    address private constant PROTOCOL_WALLET_ADDRESS = 0xebf3334CEE2fb0acDeeAD2E13A0Af302A2e2FF3c;

    uint256 public immutable I_CONSTANT_K; // The K in the constant product formula (v_tokens * v_eth)

    uint256 public ethRaised;
    uint256 public accumulatedPoolFee;
    bool public liquidityPulled;

    event TradeEvent(address indexed tokenAddress, uint256 ethPrice);
    event RewardsDistributed(address indexed winner, uint256 winnerPrizeAmount, uint256 protocolAmount);
    event LiquidityPulled(uint256 totalAmountDistributed);

    constructor(string memory name, string memory symbol, address initialOwner)
        ERC20(name, symbol)
        Ownable(initialOwner)
    {
        _mint(address(this), INITIAL_SUPPLY);
        I_CONSTANT_K = (balanceOf(address(this)) + VIRTUAL_TOKEN_RESERVE) * VIRTUAL_ETH_RESERVE;
    }

    function calculateCurrentPrice() public view returns (uint256) {
        uint256 tokensInContract = balanceOf(address(this));
        uint256 effectiveTokenReserve = VIRTUAL_TOKEN_RESERVE + tokensInContract;
        uint256 effectiveEthReserve = VIRTUAL_ETH_RESERVE + ethRaised;

        return (effectiveEthReserve * ONE_ETHER) / effectiveTokenReserve;
    }

    function calculateBuyReturn(uint256 netEthAmount) public view returns (uint256) {
        require(netEthAmount > 0, "Net ETH for curve is zero");
        return (balanceOf(address(this)) + VIRTUAL_TOKEN_RESERVE)
            - (I_CONSTANT_K / (VIRTUAL_ETH_RESERVE + ethRaised + netEthAmount));
    }

    function calculateSellReturn(uint256 tokenAmount) public view returns (uint256) {
        require(tokenAmount > 0, "Token amount must be > 0");
        uint256 tokensInContract = balanceOf(address(this));
        require(tokenAmount <= INITIAL_SUPPLY - tokensInContract, "Cannot sell more than circulating");
        return (ethRaised + VIRTUAL_ETH_RESERVE)
            - (I_CONSTANT_K / (VIRTUAL_TOKEN_RESERVE + tokensInContract + tokenAmount));
    }

    function buy() public payable nonReentrant {
        require(!liquidityPulled, "Trading disabled");
        require(msg.value >= MIN_BUY, "Below minimum buy amount");

        uint256 grossEthAmount = msg.value;

        uint256 poolFee = (grossEthAmount * TAX_NUMERATOR) / TAX_DENOMINATOR;
        if (poolFee > 0) {
            accumulatedPoolFee += poolFee;
        }
        uint256 netEthForCurve = grossEthAmount - poolFee;

        uint256 tokensToTransfer = calculateBuyReturn(netEthForCurve);
        require(tokensToTransfer > 0, "Would receive zero tokens for net ETH");
        require(tokensToTransfer <= balanceOf(address(this)), "Insufficient token reserves");

        // Update state
        ethRaised += netEthForCurve;

        _transfer(address(this), msg.sender, tokensToTransfer);
        uint256 currentPrice = calculateCurrentPrice();

        emit TradeEvent(address(this), currentPrice);
    }

    function sell(uint256 tokenAmount) public nonReentrant {
        require(!liquidityPulled, "Trading disabled");
        require(tokenAmount > 0, "Must sell more than 0 tokens");
        require(balanceOf(msg.sender) >= tokenAmount, "Not enough tokens to sell");

        uint256 ethToReturnGross = calculateSellReturn(tokenAmount);
        require(ethToReturnGross > 0, "Would receive zero ETH");
        require(ethToReturnGross <= address(this).balance, "Insufficient ETH in contract for sale");

        uint256 sellFee = (ethToReturnGross * TAX_NUMERATOR) / TAX_DENOMINATOR; // 20%

        accumulatedPoolFee += sellFee;

        require(ethToReturnGross > sellFee, "Fee exceeds return amount");
        uint256 ethToReturnNet = ethToReturnGross - sellFee;

        // Update state
        _transfer(msg.sender, address(this), tokenAmount);

        ethRaised -= ethToReturnGross;

        payable(msg.sender).transfer(ethToReturnNet);

        uint256 currentPrice = calculateCurrentPrice();
        emit TradeEvent(address(this), currentPrice);
    }

    function distributeRewards(address winner) public onlyOwner nonReentrant {
        require(winner != address(0), "Null winner address");

        uint256 feesToDistribute = accumulatedPoolFee;
        accumulatedPoolFee = 0;

        uint256 winnerPrizeAmount = (feesToDistribute * 80) / 100;
        uint256 protocolAmount = feesToDistribute - winnerPrizeAmount;

        // Transfers
        if (winnerPrizeAmount > 0) {
            payable(winner).transfer(winnerPrizeAmount);
        }
        if (protocolAmount > 0) {
            payable(PROTOCOL_WALLET_ADDRESS).transfer(protocolAmount);
        }

        emit RewardsDistributed(winner, winnerPrizeAmount, protocolAmount);
    }

    function pullLiquidity(address payable[] calldata wallets, uint256[] calldata amounts)
        public
        onlyOwner
        nonReentrant
    {
        require(!liquidityPulled, "Liquidity already pulled");
        liquidityPulled = true;

        require(wallets.length == amounts.length, "Mismatched array lengths");

        uint256 totalEthToDistribute = 0;
        for (uint256 i = 0; i < wallets.length; i++) {
            totalEthToDistribute += amounts[i];
        }

        require(totalEthToDistribute <= address(this).balance, "Total amount exceeds contract balance");

        for (uint256 i = 0; i < wallets.length; i++) {
            if (amounts[i] > 0) {
                (bool sent,) = wallets[i].call{value: amounts[i]}("");
                require(sent, "Failed to send ETH");
            }
        }

        emit LiquidityPulled(totalEthToDistribute);
    }
}
