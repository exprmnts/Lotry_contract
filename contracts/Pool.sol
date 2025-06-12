// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

// import "./RandomWalletPicker.sol";

contract BondingCurvePool is ERC20, Ownable {
    using Math for uint256;

    // Constants
    uint256 public constant INITIAL_SUPPLY = 1_000_000_000 * 1e18; // 1 Billion tokens with 18 decimals
    uint256 public constant MIN_LOTTERY_POOL = 0.01 ether; // 0.01 ETH minimum
    uint256 public constant MAX_LOTTERY_POOL = 100 ether; // 100 ETH maximum
    uint256 public constant MIN_BUY = 0.001 ether; // Minimum purchase
    
    uint256 private constant ONE_ETHER = 1e18; // For precision in calculations

    // Fee Structure Constants (Numerators and Denominators for percentage calculations)
    // Tax rate for initial price calculation: 22.22%
    uint256 private constant TAX_RATE_NUMERATOR = 2222;
    uint256 private constant TAX_RATE_DENOMINATOR = 10000; // 22.22%

    uint256 private constant LOTTERY_POOL_FEE_NUMERATOR = 20;
    uint256 private constant LOTTERY_POOL_FEE_DENOMINATOR = 100; // 20%

    uint256 private constant PROTOCOL_POOL_FEE_NUMERATOR = 111;
    uint256 private constant PROTOCOL_POOL_FEE_DENOMINATOR = 10000; // 1.11%

    uint256 private constant DEV_FEE_NUMERATOR = 111;
    uint256 private constant DEV_FEE_DENOMINATOR = 10000; // 1.11%
    address public constant PROTOCOL_POOL_ADDRESS = 0x0Df21BEAAadce4893A05503Cee6Ece4d1B087449;

    // State variables
    address public devAddress;
    uint256 public initialTokenPrice;
    uint256 public lotteryPool; // Target ETH to be collected
    uint256 public ethRaised; // Total ETH collected by the curve
    uint256 public constant_k; // The K in the constant product formula (v_tokens * v_eth)
    
    // Virtual reserves
    uint256 public virtualTokenReserve;
    uint256 public virtualEthReserve;
    
    // Accumulated Taxes/Fees
    uint256 public accumulatedLotteryTax;
    uint256 public accumulatedProtocolTax;
    uint256 public accumulatedDevTax;
    bool public isLotteryTaxActive = true;
        
    event TokensPurchased(address indexed buyer, uint256 grossEthAmount, uint256 netEthForCurve, uint256 tokensReceived, uint256 lotteryFeeApplied);
    event TokensSold(address indexed seller, uint256 amountTokens, uint256 amountEth);
    event LotteryPoolUpdated(uint256 newLotteryPool);
    event CurveParametersUpdated(uint256 virtualTokenRes, uint256 virtualEthRes, uint256 k);
    event LotteryTaxStatusChanged(bool isActive);
    event RewardsDistributed(
        address indexed winner,
        uint256 lotteryReward,
        uint256 protocolReward,
        uint256 devReward
    );

    constructor(
        string memory name,
        string memory symbol,
        uint256 _initialLotteryPool,
        address _devAddress,
        address initialOwner
    ) ERC20(name, symbol) Ownable(initialOwner) {
        require(_devAddress != address(0), "Dev address cannot be zero");
        devAddress = _devAddress;

        require(
            _initialLotteryPool >= MIN_LOTTERY_POOL,
            "Lottery pool too small"
        );
        require(
            _initialLotteryPool <= MAX_LOTTERY_POOL,
            "Lottery pool too large"
        );

        lotteryPool = _initialLotteryPool;
        _mint(address(this), INITIAL_SUPPLY);
        
        // Calculate the conceptual liquidity pool size.
        uint256 liquidityPool = (lotteryPool * TAX_RATE_DENOMINATOR) / TAX_RATE_NUMERATOR;
        require(liquidityPool > 0, "Liquidity pool must be positive");

        // Set curve parameters to meet the economic requirement: selling 800 million tokens returns 110% of the liquidity pool.
        uint256 V_TOKEN_MULTIPLIER = 10; 
        virtualTokenReserve = INITIAL_SUPPLY * V_TOKEN_MULTIPLIER;

        uint256 tokensToSellForCondition = (INITIAL_SUPPLY * 80) / 100; // 800M tokens
        uint256 targetEthReturn = (liquidityPool * 110) / 100; // 110% of liquidityPool

        // Calculate required virtual ETH reserve to meet the condition:
        // targetEthReturn = virtualEthReserve * (tokensToSellForCondition / (virtualTokenReserve + tokensToSellForCondition))
        // Solving for virtualEthReserve:
        uint256 numerator = targetEthReturn * (virtualTokenReserve + tokensToSellForCondition);
        virtualEthReserve = numerator / tokensToSellForCondition;

        // Determine constant k and the effective initial price from the reserves.
        constant_k = (virtualTokenReserve * virtualEthReserve) / ONE_ETHER;
        initialTokenPrice = (virtualEthReserve * ONE_ETHER) / virtualTokenReserve;

        emit CurveParametersUpdated(virtualTokenReserve, virtualEthReserve, constant_k);
    }
    
    // Calculate current token price based on virtual reserves
    function calculateCurrentPrice() public view returns (uint256) {
        if (virtualTokenReserve == 0) return type(uint256).max; // Indicate effectively infinite price
        return (virtualEthReserve * ONE_ETHER) / virtualTokenReserve; // Price in ETH per token, scaled by 1e18
    }

    // Calculate how many tokens will be received for a given NET ETH amount
    function calculateBuyReturn(uint256 netEthAmount) public view returns (uint256) {        
        require(netEthAmount > 0, "Net ETH for curve is zero");
        if (virtualEthReserve + netEthAmount == 0) return 0;
        
        uint256 k_scaled = constant_k * ONE_ETHER; 
        uint256 newVirtualEthReserve = virtualEthReserve + netEthAmount;
        if (newVirtualEthReserve == 0) return virtualTokenReserve;

        uint256 newVirtualTokenReserve = k_scaled / newVirtualEthReserve;
        
        if (virtualTokenReserve > newVirtualTokenReserve) {
            return virtualTokenReserve - newVirtualTokenReserve;
        }
        return 0;
    }

    // Calculate how much ETH will be returned for a given token amount
    function calculateSellReturn(uint256 tokenAmount) public view returns (uint256) {
        require(tokenAmount > 0, "Token amount must be > 0");
        if (virtualTokenReserve == 0) return virtualEthReserve;
        
        uint256 k_scaled = constant_k * ONE_ETHER;
        uint256 newVirtualTokenReserve = virtualTokenReserve + tokenAmount;
        if (newVirtualTokenReserve == 0) return virtualEthReserve;

        uint256 newVirtualEthReserve = k_scaled / newVirtualTokenReserve;

        if (virtualEthReserve > newVirtualEthReserve) {
            return virtualEthReserve - newVirtualEthReserve;
        }
        return 0;
    }

    // Buy tokens with ETH
    function buy() public payable {
        require(msg.value >= MIN_BUY, "Below minimum buy amount");
        
        uint256 grossEthAmount = msg.value;
        uint256 totalFeesPaid = 0;
        uint256 lotteryFeeApplied = 0;

        // Apply fees
        if (isLotteryTaxActive) {
            lotteryFeeApplied = (grossEthAmount * LOTTERY_POOL_FEE_NUMERATOR) / LOTTERY_POOL_FEE_DENOMINATOR;
            accumulatedLotteryTax += lotteryFeeApplied;
            totalFeesPaid += lotteryFeeApplied;

            if (accumulatedLotteryTax >= lotteryPool) {
                isLotteryTaxActive = false;
                emit LotteryTaxStatusChanged(false);
            }
        }

        uint256 protocolFee = (grossEthAmount * PROTOCOL_POOL_FEE_NUMERATOR) / PROTOCOL_POOL_FEE_DENOMINATOR;
        accumulatedProtocolTax += protocolFee;
        totalFeesPaid += protocolFee;

        uint256 devFee = (grossEthAmount * DEV_FEE_NUMERATOR) / DEV_FEE_DENOMINATOR;
        accumulatedDevTax += devFee;
        totalFeesPaid += devFee;

        require(grossEthAmount > totalFeesPaid, "Fees exceed sent amount");
        uint256 netEthForCurve = grossEthAmount - totalFeesPaid;
        
        uint256 tokensToTransfer = calculateBuyReturn(netEthForCurve);
        require(tokensToTransfer > 0, "Would receive zero tokens for net ETH");
        
        require(tokensToTransfer <= balanceOf(address(this)), "Purchase exceeds available supply");
        
        // Update state
        ethRaised += netEthForCurve; 
        
        virtualEthReserve += netEthForCurve; 
        virtualTokenReserve -= tokensToTransfer;
        
        _transfer(address(this), msg.sender, tokensToTransfer);
                
        emit TokensPurchased(msg.sender, grossEthAmount, netEthForCurve, tokensToTransfer, lotteryFeeApplied);
    }

    // Sell tokens to get ETH back
    function sell(uint256 tokenAmount) public {
        require(tokenAmount > 0, "Must sell more than 0 tokens");
        require(balanceOf(msg.sender) >= tokenAmount, "Not enough tokens to sell");   

        uint256 ethToReturn = calculateSellReturn(tokenAmount);
        require(ethToReturn > 0, "Would receive zero ETH");
        require(ethToReturn <= virtualEthReserve, "Sell amount exceeds curve's virtual ETH reserve");

        // Update state
        _transfer(msg.sender, address(this), tokenAmount);
        
        ethRaised -= ethToReturn;

        virtualTokenReserve += tokenAmount;
        virtualEthReserve -= ethToReturn;
        
        payable(msg.sender).transfer(ethToReturn);
        
        emit TokensSold(msg.sender, tokenAmount, ethToReturn);
    }

    // Fund the lottery pool with ETH
    function addToLotteryPool() external payable {
        _addToLotteryPoolInternal(msg.value);
    }

    function _addToLotteryPoolInternal(uint256 _value) internal {
        require(_value > 0, "Must add positive ETH amount to lottery pool");
        require(lotteryPool + _value <= MAX_LOTTERY_POOL, "Would exceed maximum lottery pool");
        
        lotteryPool += _value;
        
        emit LotteryPoolUpdated(lotteryPool);
    }

    function distributeRewards(address winner) public onlyOwner {
        require(winner != address(0), "Winner address cannot be zero");

        // Readings from storage to memory
        uint256 totalLotteryTax = accumulatedLotteryTax;
        uint256 protocolTax = accumulatedProtocolTax;
        uint256 devTax = accumulatedDevTax;

        // Reset accumulated values in storage
        accumulatedLotteryTax = 0;
        accumulatedProtocolTax = 0;
        accumulatedDevTax = 0;

        // Calculations
        uint256 winnerPrizeAmount;
        uint256 remainderForProtocol = 0;

        if (totalLotteryTax >= lotteryPool) {
            // Target met or exceeded. Winner gets the fixed prize.
            winnerPrizeAmount = lotteryPool;
            remainderForProtocol = totalLotteryTax - lotteryPool;
        } else {
            // Target not met. Winner gets whatever has been collected.
            winnerPrizeAmount = totalLotteryTax;
        }

        uint256 totalForProtocol = remainderForProtocol + protocolTax;

        // Transfers
        if (winnerPrizeAmount > 0) {
            payable(winner).transfer(winnerPrizeAmount);
        }
        if (totalForProtocol > 0) {
            payable(PROTOCOL_POOL_ADDRESS).transfer(totalForProtocol);
        }
        if (devTax > 0) {
            payable(devAddress).transfer(devTax);
        }

        emit RewardsDistributed(winner, winnerPrizeAmount, totalForProtocol, devTax);
    }
}
