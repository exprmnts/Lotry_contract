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
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

error Ticket__InvalidNetLotryAmount();
error Ticket__InvalidTokenAmount();
error Ticket__ExceedsCirculatingSupply();
error Ticket__TradingDisabled();
error Ticket__BelowMinimumBuy();
error Ticket__ZeroTokenReturn();
error Ticket__InsufficientTokenReserves();
error Ticket__InsufficientTokenBalance();
error Ticket__ZeroLotryReturn();
error Ticket__InsufficientLotryReserves();
error Ticket__FeeExceedsReturn();
error Ticket__NullWinnerAddress();
error Ticket__LiquidityAlreadyPulled();
error Ticket__MismatchedArrayLengths();
error Ticket__ExceedsContractBalance();
error Ticket__InvalidRewardToken();
error Ticket__NoRewardTokenSet();
error Ticket__NoLotryTokenSet();
error Ticket__InvalidLotryToken();
error Ticket__InvalidStakeAddress();
error Ticket__InvalidStakeAmount();

contract LotryTicket is Ownable, ERC20, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 private constant MIN_BUY = 1; // Minimum buy in $LOTRY
    uint256 private constant ONE_ETHER = 1e18;
    uint256 private constant TAX_NUMERATOR = 11;
    uint256 private constant TAX_DENOMINATOR = 100;
    
    // Bonding curve constants derived from Python calculator
    // Virtual tokens (V_T): 66,666,666.666667 tokens (with 18 decimals)
    uint256 private constant VIRTUAL_TOKEN_RESERVE = 66_666_666_666667000000000000; // ~66.67M tokens
    // Virtual $LOTRY (V_E): internal 1.333333333333 (with 18 decimals)
    uint256 private constant VIRTUAL_LOTRY_RESERVE = 1_333333333333000000; // ~1.333... $LOTRY (internal scale)
    // $LOTRY scale factor: 1e10 (external $LOTRY = internal * LOTRY_SCALE)
    // When user sends X $LOTRY tokens, we divide by LOTRY_SCALE to get internal units
    // When contract sends Y internal units, we multiply by LOTRY_SCALE to get $LOTRY tokens
    uint256 private constant LOTRY_SCALE = 1e10;
    
    uint256 private constant INITIAL_SUPPLY = 1_000_000_000_000_000_000_000_000_000; // 1B tokens with 18 decimals
    address private constant PROTOCOL_WALLET_ADDRESS = 0xebf3334CEE2fb0acDeeAD2E13A0Af302A2e2FF3c;

    uint256 public immutable I_CONSTANT_K; // The K in the constant product formula (v_tokens * v_lotry)

    // $LOTRY token used for trading
    address public lotryTokenAddress;
    
    uint256 public lotryRaised; // $LOTRY raised (internal scale, multiply by LOTRY_SCALE for external)
    uint256 public accumulatedPoolFee; // Accumulated fees (internal scale)
    bool public liquidityPulled;

    // Reward Token (separate from $LOTRY)
    address public rewardTokenAddress;
    uint256 public accumulatedRewardTokens;

    event TradeEvent(address indexed tokenAddress, uint256 lotryPrice);
    event RewardsDistributed(address indexed winner, uint256 winnerPrizeAmount, uint256 protocolAmount);
    event LiquidityPulled(uint256 totalAmountDistributed);

    constructor(string memory name, string memory symbol, address initialOwner)
        ERC20(name, symbol)
        Ownable(initialOwner)
    {
        _mint(address(this), INITIAL_SUPPLY);
        I_CONSTANT_K = (balanceOf(address(this)) + VIRTUAL_TOKEN_RESERVE) * VIRTUAL_LOTRY_RESERVE;
    }

    function calculateCurrentPrice() public view returns (uint256) {
        uint256 tokensInContract = balanceOf(address(this));
        uint256 effectiveTokenReserve = VIRTUAL_TOKEN_RESERVE + tokensInContract;
        uint256 effectiveLotryReserve = VIRTUAL_LOTRY_RESERVE + lotryRaised;

        // Returns price in internal $LOTRY per token (multiply by LOTRY_SCALE for display)
        return (effectiveLotryReserve * ONE_ETHER) / effectiveTokenReserve;
    }

    // netLotryAmountInternal is in internal scale (external $LOTRY / LOTRY_SCALE)
    function calculateBuyReturn(uint256 netLotryAmountInternal) public view returns (uint256) {
        if (netLotryAmountInternal <= 0) revert Ticket__InvalidNetLotryAmount();
        return (balanceOf(address(this)) + VIRTUAL_TOKEN_RESERVE)
            - (I_CONSTANT_K / (VIRTUAL_LOTRY_RESERVE + lotryRaised + netLotryAmountInternal));
    }

    function calculateSellReturn(uint256 tokenAmount) public view returns (uint256) {
        if (tokenAmount <= 0) revert Ticket__InvalidTokenAmount();
        uint256 tokensInContract = balanceOf(address(this));
        if (tokenAmount > INITIAL_SUPPLY - tokensInContract) {
            revert Ticket__ExceedsCirculatingSupply();
        }
        return (lotryRaised + VIRTUAL_LOTRY_RESERVE)
            - (I_CONSTANT_K / (VIRTUAL_TOKEN_RESERVE + tokensInContract + tokenAmount));
    }

    // lotryAmountExternal is the amount of $LOTRY tokens the user is spending (in external/token units)
    function buy(uint256 lotryAmountExternal) public nonReentrant {
        if (liquidityPulled) revert Ticket__TradingDisabled();
        if (lotryTokenAddress == address(0)) revert Ticket__NoLotryTokenSet();
        if (lotryAmountExternal < MIN_BUY) revert Ticket__BelowMinimumBuy();

        // Transfer $LOTRY tokens from user to this contract (SafeERC20 for smart wallet compatibility)
        IERC20 lotryToken = IERC20(lotryTokenAddress);
        lotryToken.safeTransferFrom(msg.sender, address(this), lotryAmountExternal);

        // Convert external $LOTRY to internal scale for curve calculations
        uint256 grossLotryInternal = lotryAmountExternal / LOTRY_SCALE;

        uint256 poolFee = (grossLotryInternal * TAX_NUMERATOR) / TAX_DENOMINATOR;
        if (poolFee > 0) {
            accumulatedPoolFee += poolFee;
        }
        uint256 netLotryForCurve = grossLotryInternal - poolFee;

        uint256 tokensToTransfer = calculateBuyReturn(netLotryForCurve);
        if (tokensToTransfer <= 0) revert Ticket__ZeroTokenReturn();
        if (tokensToTransfer > balanceOf(address(this))) {
            revert Ticket__InsufficientTokenReserves();
        }

        // Update state
        lotryRaised += netLotryForCurve;

        _transfer(address(this), msg.sender, tokensToTransfer);
        uint256 currentPrice = calculateCurrentPrice();

        emit TradeEvent(address(this), currentPrice);
    }

    function sell(uint256 tokenAmount) public nonReentrant {
        if (liquidityPulled) revert Ticket__TradingDisabled();
        if (lotryTokenAddress == address(0)) revert Ticket__NoLotryTokenSet();
        if (tokenAmount <= 0) revert Ticket__InvalidTokenAmount();
        if (balanceOf(msg.sender) < tokenAmount) {
            revert Ticket__InsufficientTokenBalance();
        }

        // calculateSellReturn returns internal scale
        uint256 lotryToReturnGrossInternal = calculateSellReturn(tokenAmount);
        if (lotryToReturnGrossInternal <= 0) revert Ticket__ZeroLotryReturn();
        
        // Convert to external scale to check contract's $LOTRY balance
        uint256 lotryToReturnGrossExternal = lotryToReturnGrossInternal * LOTRY_SCALE;
        IERC20 lotryToken = IERC20(lotryTokenAddress);
        if (lotryToReturnGrossExternal > lotryToken.balanceOf(address(this))) {
            revert Ticket__InsufficientLotryReserves();
        }

        uint256 sellFeeInternal = (lotryToReturnGrossInternal * TAX_NUMERATOR) / TAX_DENOMINATOR; // 11%

        accumulatedPoolFee += sellFeeInternal;

        if (lotryToReturnGrossInternal <= sellFeeInternal) revert Ticket__FeeExceedsReturn();
        uint256 lotryToReturnNetInternal = lotryToReturnGrossInternal - sellFeeInternal;

        // Convert net return to external scale for transfer
        uint256 lotryToReturnNetExternal = lotryToReturnNetInternal * LOTRY_SCALE;

        // Update state
        _transfer(msg.sender, address(this), tokenAmount);

        lotryRaised -= lotryToReturnGrossInternal;

        // Transfer $LOTRY tokens to seller (SafeERC20 for smart wallet compatibility)
        lotryToken.safeTransfer(msg.sender, lotryToReturnNetExternal);

        uint256 currentPrice = calculateCurrentPrice();
        emit TradeEvent(address(this), currentPrice);
    }

    function distributeRewards(address winner) public onlyOwner nonReentrant {
        if (winner == address(0)) revert Ticket__NullWinnerAddress();
        if (lotryTokenAddress == address(0)) revert Ticket__NoLotryTokenSet();

        // feesToDistribute is in internal scale
        uint256 feesToDistributeInternal = accumulatedPoolFee;
        accumulatedPoolFee = 0;

        uint256 winnerPrizeInternal = (feesToDistributeInternal * 80) / 100;
        uint256 protocolAmountInternal = feesToDistributeInternal - winnerPrizeInternal;

        // Convert to external scale for $LOTRY transfers
        uint256 winnerPrizeExternal = winnerPrizeInternal * LOTRY_SCALE;
        uint256 protocolAmountExternal = protocolAmountInternal * LOTRY_SCALE;

        IERC20 lotryToken = IERC20(lotryTokenAddress);

        // $LOTRY Transfers (SafeERC20 for smart wallet compatibility)
        if (winnerPrizeExternal > 0) {
            lotryToken.safeTransfer(winner, winnerPrizeExternal);
        }
        if (protocolAmountExternal > 0) {
            lotryToken.safeTransfer(PROTOCOL_WALLET_ADDRESS, protocolAmountExternal);
        }

        // Additional reward token transfer (send all to winner)
        if (rewardTokenAddress != address(0) && accumulatedRewardTokens > 0) {
            uint256 tokenAmount = accumulatedRewardTokens;
            accumulatedRewardTokens = 0;

            IERC20 rewardToken = IERC20(rewardTokenAddress);
            rewardToken.safeTransfer(winner, tokenAmount);
        }

        emit RewardsDistributed(winner, winnerPrizeExternal, protocolAmountExternal);
    }

    // amounts are in external $LOTRY scale (actual token amounts)
    function pullLiquidity(address[] calldata wallets, uint256[] calldata amounts)
        public
        onlyOwner
        nonReentrant
    {
        if (liquidityPulled) revert Ticket__LiquidityAlreadyPulled();
        if (lotryTokenAddress == address(0)) revert Ticket__NoLotryTokenSet();
        liquidityPulled = true;

        if (wallets.length != amounts.length) {
            revert Ticket__MismatchedArrayLengths();
        }

        uint256 totalLotryToDistribute = 0;
        for (uint256 i = 0; i < wallets.length; i++) {
            totalLotryToDistribute += amounts[i];
        }

        IERC20 lotryToken = IERC20(lotryTokenAddress);
        if (totalLotryToDistribute > lotryToken.balanceOf(address(this))) {
            revert Ticket__ExceedsContractBalance();
        }

        // SafeERC20 for smart wallet compatibility
        for (uint256 i = 0; i < wallets.length; i++) {
            if (amounts[i] > 0) {
                lotryToken.safeTransfer(wallets[i], amounts[i]);
            }
        }

        emit LiquidityPulled(totalLotryToDistribute);
    }

    // Function to set the $LOTRY token address (required before trading)
    function setLotryToken(address tokenAddress) external onlyOwner {
        if (tokenAddress == address(0)) revert Ticket__InvalidLotryToken();
        lotryTokenAddress = tokenAddress;
    }

    // Function to set the reward token address
    function setRewardToken(address tokenAddress) external onlyOwner {
        if (tokenAddress == address(0)) revert Ticket__InvalidRewardToken();
        rewardTokenAddress = tokenAddress;
    }

    // Function to deposit reward tokens to the pot (SafeERC20 for smart wallet compatibility)
    function depositRewardTokens(uint256 amount) external nonReentrant {
        if (rewardTokenAddress == address(0)) revert Ticket__NoRewardTokenSet();
        if (amount == 0) revert Ticket__InvalidTokenAmount();

        IERC20 rewardToken = IERC20(rewardTokenAddress);
        rewardToken.safeTransferFrom(msg.sender, address(this), amount);

        accumulatedRewardTokens += amount;
    }

    // Function to deposit $LOTRY tokens to the pool (for external contributions to the prize pool)
    // SafeERC20 for smart wallet compatibility
    function depositLotryTokens(uint256 amountExternal) external nonReentrant {
        if (lotryTokenAddress == address(0)) revert Ticket__NoLotryTokenSet();
        if (amountExternal == 0) revert Ticket__InvalidTokenAmount();

        IERC20 lotryToken = IERC20(lotryTokenAddress);
        lotryToken.safeTransferFrom(msg.sender, address(this), amountExternal);

        // Convert to internal scale and add to pool fee
        uint256 amountInternal = amountExternal / LOTRY_SCALE;
        accumulatedPoolFee += amountInternal;
    }

    // Function to send minted tokens to staking contract (owner only)
    function sendToStaking(address stakeContract, uint256 amount) external onlyOwner nonReentrant {
        if (stakeContract == address(0)) revert Ticket__InvalidStakeAddress();
        if (amount == 0) revert Ticket__InvalidStakeAmount();
        if (amount > balanceOf(address(this))) revert Ticket__InsufficientTokenReserves();

        _transfer(address(this), stakeContract, amount);
    }

    // Function to get the balance of reward tokens in the pot
    function getRewardTokenBalance() external view returns (uint256) {
        if (rewardTokenAddress == address(0)) return 0;
        return accumulatedRewardTokens;
    }

    // Function to get the $LOTRY balance in the contract (external scale)
    function getLotryBalance() external view returns (uint256) {
        if (lotryTokenAddress == address(0)) return 0;
        return IERC20(lotryTokenAddress).balanceOf(address(this));
    }

    // Function to get the accumulated pool fee in external $LOTRY scale
    function getAccumulatedPoolFeeExternal() external view returns (uint256) {
        return accumulatedPoolFee * LOTRY_SCALE;
    }

    // Function to get lotryRaised in external $LOTRY scale
    function getLotryRaisedExternal() external view returns (uint256) {
        return lotryRaised * LOTRY_SCALE;
    }

    // Function to get the current price in external $LOTRY scale
    function calculateCurrentPriceExternal() external view returns (uint256) {
        return calculateCurrentPrice() * LOTRY_SCALE;
    }
}

