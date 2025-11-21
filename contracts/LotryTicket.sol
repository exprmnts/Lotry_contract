// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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

                    
                █   █▀█ ▀█▀ █▀█ █▄█  █▀█ █▀█ █▀█ ▀█▀ █▀█ █▀▀ █▀█ █
                █▄▄ █▄█  █  █▀▄  █   █▀▀ █▀▄ █▄█  █  █▄█ █▄▄ █▄█ █▄▄
*/

/**
 * @title Lotry Ticket ERC20 Token
 * @author @lotrydotfun
 * @notice This contract defines the Lotry Ticket ERC20 token, which incorporates a bonding curve for dynamic pricing, a tax mechanism on trades, and features for reward distribution and liquidity management.
 * @dev The token's price is governed by a constant product bonding curve. It includes functions for buying and selling tokens, applying a percentage tax on transactions, and managing the distribution of accumulated funds for rewards and protocol operations.
 */
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

error Ticket__InvalidNetEthAmount();
error Ticket__InvalidTokenAmount();
error Ticket__ExceedsCirculatingSupply();
error Ticket__TradingDisabled();
error Ticket__BelowMinimumBuy();
error Ticket__ZeroTokenReturn();
error Ticket__InsufficientTokenReserves();
error Ticket__InsufficientTokenBalance();
error Ticket__ZeroEthReturn();
error Ticket__InsufficientEthReserves();
error Ticket__FeeExceedsReturn();
error Ticket__NullWinnerAddress();
error Ticket__LiquidityAlreadyPulled();
error Ticket__MismatchedArrayLengths();
error Ticket__ExceedsContractBalance();
error Ticket__EthTransferFailed();

contract LotryTicket is Ownable, ERC20, ReentrancyGuard {
    uint256 private constant MIN_BUY = 0.00001 ether;
    uint256 private constant ONE_ETHER = 1e18;
    uint256 private constant TAX_NUMERATOR = 20;
    uint256 private constant TAX_DENOMINATOR = 100;
    uint256 private constant VIRTUAL_TOKEN_RESERVE = 17525652865772000000000000; // 17,525,652.865772
    uint256 private constant VIRTUAL_ETH_RESERVE = 203505130573000000; // 0.203505130573 ETH
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
        if (netEthAmount <= 0) revert Ticket__InvalidNetEthAmount();
        return (balanceOf(address(this)) + VIRTUAL_TOKEN_RESERVE)
            - (I_CONSTANT_K / (VIRTUAL_ETH_RESERVE + ethRaised + netEthAmount));
    }

    function calculateSellReturn(uint256 tokenAmount) public view returns (uint256) {
        if (tokenAmount <= 0) revert Ticket__InvalidTokenAmount();
        uint256 tokensInContract = balanceOf(address(this));
        if (tokenAmount > INITIAL_SUPPLY - tokensInContract) {
            revert Ticket__ExceedsCirculatingSupply();
        }
        return (ethRaised + VIRTUAL_ETH_RESERVE)
            - (I_CONSTANT_K / (VIRTUAL_TOKEN_RESERVE + tokensInContract + tokenAmount));
    }

    function buy() public payable nonReentrant {
        if (liquidityPulled) revert Ticket__TradingDisabled();
        if (msg.value < MIN_BUY) revert Ticket__BelowMinimumBuy();

        uint256 grossEthAmount = msg.value;

        uint256 poolFee = (grossEthAmount * TAX_NUMERATOR) / TAX_DENOMINATOR;
        if (poolFee > 0) {
            accumulatedPoolFee += poolFee;
        }
        uint256 netEthForCurve = grossEthAmount - poolFee;

        uint256 tokensToTransfer = calculateBuyReturn(netEthForCurve);
        if (tokensToTransfer <= 0) revert Ticket__ZeroTokenReturn();
        if (tokensToTransfer > balanceOf(address(this))) {
            revert Ticket__InsufficientTokenReserves();
        }

        // Update state
        ethRaised += netEthForCurve;

        _transfer(address(this), msg.sender, tokensToTransfer);
        uint256 currentPrice = calculateCurrentPrice();

        emit TradeEvent(address(this), currentPrice);
    }

    function sell(uint256 tokenAmount) public nonReentrant {
        if (liquidityPulled) revert Ticket__TradingDisabled();
        if (tokenAmount <= 0) revert Ticket__InvalidTokenAmount();
        if (balanceOf(msg.sender) < tokenAmount) {
            revert Ticket__InsufficientTokenBalance();
        }

        uint256 ethToReturnGross = calculateSellReturn(tokenAmount);
        if (ethToReturnGross <= 0) revert Ticket__ZeroEthReturn();
        if (ethToReturnGross > address(this).balance) {
            revert Ticket__InsufficientEthReserves();
        }

        uint256 sellFee = (ethToReturnGross * TAX_NUMERATOR) / TAX_DENOMINATOR; // 20%

        accumulatedPoolFee += sellFee;

        if (ethToReturnGross <= sellFee) revert Ticket__FeeExceedsReturn();
        uint256 ethToReturnNet = ethToReturnGross - sellFee;

        // Update state
        _transfer(msg.sender, address(this), tokenAmount);

        ethRaised -= ethToReturnGross;

        payable(msg.sender).transfer(ethToReturnNet);

        uint256 currentPrice = calculateCurrentPrice();
        emit TradeEvent(address(this), currentPrice);
    }

    function distributeRewards(address winner) public onlyOwner nonReentrant {
        if (winner == address(0)) revert Ticket__NullWinnerAddress();

        uint256 feesToDistribute = accumulatedPoolFee;
        accumulatedPoolFee = 0;

        uint256 winnerPrizeAmount = (feesToDistribute * 80) / 100;
        uint256 protocolAmount = feesToDistribute - winnerPrizeAmount;

        // Transfers
        if (winnerPrizeAmount > 0) {
            (bool sentWinner,) = winner.call{value: winnerPrizeAmount}("");
            if (!sentWinner) revert Ticket__EthTransferFailed();
        }
        if (protocolAmount > 0) {
            (bool sentProtocol,) = PROTOCOL_WALLET_ADDRESS.call{value: protocolAmount}("");
            if (!sentProtocol) revert Ticket__EthTransferFailed();
        }

        emit RewardsDistributed(winner, winnerPrizeAmount, protocolAmount);
    }

    function pullLiquidity(address payable[] calldata wallets, uint256[] calldata amounts)
        public
        onlyOwner
        nonReentrant
    {
        if (liquidityPulled) revert Ticket__LiquidityAlreadyPulled();
        liquidityPulled = true;

        if (wallets.length != amounts.length) {
            revert Ticket__MismatchedArrayLengths();
        }

        uint256 totalEthToDistribute = 0;
        for (uint256 i = 0; i < wallets.length; i++) {
            totalEthToDistribute += amounts[i];
        }

        if (totalEthToDistribute > address(this).balance) {
            revert Ticket__ExceedsContractBalance();
        }

        for (uint256 i = 0; i < wallets.length; i++) {
            if (amounts[i] > 0) {
                (bool sent,) = wallets[i].call{value: amounts[i]}("");
                if (!sent) revert Ticket__EthTransferFailed();
            }
        }

        emit LiquidityPulled(totalEthToDistribute);
    }
}
