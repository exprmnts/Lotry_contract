// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// import "./RandomWalletPicker.sol";

contract BondingCurvePool is ERC20, Ownable, ReentrancyGuard{
    using Math for uint256;

    // Constants
    uint256 public constant INITIAL_SUPPLY = 1_000_000_000 * 1e18; // 1 Billion tokens with 18 decimals
    uint256 public constant RESERVED_SUPPLY = 200_000_000 * 1e18; // 200M tokens reserved
    uint256 public constant MIN_LOTTERY_POOL = 0.01 ether; // 0.01 ETH minimum
    uint256 public constant MAX_LOTTERY_POOL = 100 ether; // 100 ETH maximum
    uint256 public constant MIN_BUY = 0.001 ether; // Minimum purchase
    
    uint256 private constant ONE_ETHER = 1e18; // For precision in calculations

    // Fee Structure Constants (Numerators and Denominators for percentage calculations)
    // Tax rate for initial price calculation: 20%
    uint256 private constant TAX_RATE_NUMERATOR = 20;
    uint256 private constant PRE_GRADUATION_TAX_NUMERATOR = 20;
    uint256 private constant TAX_DENOMINATOR = 100;

    address public constant PROTOCOL_POOL_ADDRESS = 0x0Df21BEAAadce4893A05503Cee6Ece4d1B087449;
    address public constant REWARD_DISTRIBUTOR = 0x3513C0F1420b7D4793158Ae5eb5985BBf34d5911;

    // State variables
    uint256 public initialTokenPrice;
    uint256 public lotteryPool; // Target ETH to be collected
    uint256 public ethRaised; // Total ETH collected by the curve
    uint256 public constant_k; // The K in the constant product formula (v_tokens * v_eth)
    
    // Virtual reserves
    uint256 public virtualTokenReserve;
    uint256 public virtualEthReserve;
    
    // Accumulated Taxes/Fees
    uint256 public accumulatedPoolFee;

    // Events for buy and sell
    event TradeEvent(address indexed tokenAddress, uint256 ethPrice);
    event RewardsDistributed(address indexed winner, uint256 winnerPrizeAmount, uint256 protocolAmount);
    event Graduated(bool status);

    constructor(
        string memory name,
        string memory symbol,
        uint256 _initialLotteryPool,
        address initialOwner
    ) ERC20(name, symbol) Ownable(initialOwner) {

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
        uint256 liquidityPool = (lotteryPool * TAX_DENOMINATOR) / TAX_RATE_NUMERATOR;
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
        require(balanceOf(address(this)) + tokenAmount <= INITIAL_SUPPLY, "Sell exceeds initial supply");
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
        uint256 poolFee = 0;

        // Apply fees
        poolFee = (grossEthAmount * PRE_GRADUATION_TAX_NUMERATOR) / TAX_DENOMINATOR;
        accumulatedPoolFee += poolFee;

        require(grossEthAmount > poolFee, "Fees exceed sent amount");
        uint256 netEthForCurve = grossEthAmount - poolFee;
        
        uint256 tokensToTransfer = calculateBuyReturn(netEthForCurve);
        require(tokensToTransfer > 0, "Would receive zero tokens for net ETH");
        
        require(balanceOf(address(this)) - tokensToTransfer >= RESERVED_SUPPLY, "Sale exceeds allowable supply");
        
        // Update state
        ethRaised += netEthForCurve; 
        
        virtualEthReserve += netEthForCurve; 
        virtualTokenReserve -= tokensToTransfer;
        
        _transfer(address(this), msg.sender, tokensToTransfer);
        uint256 currentPrice = calculateCurrentPrice();

        // TODO: Might have to emit accumulatedLotteryTax 
        emit TradeEvent(address(this), currentPrice);
    }

    // Sell tokens to get ETH back
    function sell(uint256 tokenAmount) public {
        require(tokenAmount > 0, "Must sell more than 0 tokens");
        require(balanceOf(msg.sender) >= tokenAmount, "Not enough tokens to sell");   

        uint256 ethToReturnGross = calculateSellReturn(tokenAmount);
        require(ethToReturnGross > 0, "Would receive zero ETH");
        require(ethToReturnGross <= virtualEthReserve, "Sell amount exceeds curve's virtual ETH reserve");

        uint256 sellFee = 0;
        sellFee = (ethToReturnGross * PRE_GRADUATION_TAX_NUMERATOR) / TAX_DENOMINATOR;
        
        accumulatedPoolFee += sellFee;
        
        require(ethToReturnGross > sellFee, "Fee exceeds return amount");
        uint256 ethToReturnNet = ethToReturnGross - sellFee;

        // Update state
        _transfer(msg.sender, address(this), tokenAmount);
        
        ethRaised -= ethToReturnNet;

        virtualTokenReserve += tokenAmount;
        virtualEthReserve -= ethToReturnNet;
        
        payable(msg.sender).transfer(ethToReturnNet);
        
        uint256 currentPrice = calculateCurrentPrice();
        emit TradeEvent(address(this), currentPrice);
    }

    // Fund the lottery pool with ETH
    function addToLotteryPool() external payable {
        _addToLotteryPoolInternal(msg.value);
    }

    function _addToLotteryPoolInternal(uint256 _value) internal {
        require(_value > 0, "Must add positive ETH amount to lottery pool");
        require(lotteryPool + _value <= MAX_LOTTERY_POOL, "Would exceed maximum lottery pool");
        
        lotteryPool += _value;
    }

    function distributeRewards(address winner) public onlyOwner {
        //require(msg.sender == REWARD_DISTRIBUTOR, "Caller is not the reward distributor");
        require(winner != address(0), "Winner address cannot be zero");

        uint256 feesToDistribute = accumulatedPoolFee;
        accumulatedPoolFee = 0;

        uint256 winnerPrizeAmount = (feesToDistribute * 80) / 100;
        uint256 protocolAmount = feesToDistribute - winnerPrizeAmount;

        // Transfers
        if (winnerPrizeAmount > 0) {
            payable(winner).transfer(winnerPrizeAmount);
        }
        if (protocolAmount > 0) {
            payable(PROTOCOL_POOL_ADDRESS).transfer(protocolAmount);
        }

        emit RewardsDistributed(winner, winnerPrizeAmount, protocolAmount);
    }

    // pull liquidity 
    // TODO: add nonReentrant
    function pullLiquidity() external onlyOwner {
    uint256 amount = ethRaised;
    require(amount > 0, "No liquidity to pull");
    require(address(this).balance >= amount, "Insufficient contract balance");
    
    // Reset ethRaised to 0 since we're pulling all liquidity
    ethRaised = 0;
    
    // Transfer to the actual owner
    payable(owner()).transfer(amount);
  }
}
