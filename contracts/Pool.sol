// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract BondingCurvePool is ERC20, Ownable, ReentrancyGuard{
    // Constants
    uint256 public constant INITIAL_SUPPLY = 1_000_000_000 * 1e18; // 1 Billion tokens with 18 decimals
    uint256 public constant MIN_LOTTERY_POOL = 0.01 ether; // 0.01 ETH minimum
    uint256 public constant MAX_LOTTERY_POOL = 100 ether; // 100 ETH maximum
    uint256 public constant MIN_BUY = 0.001 ether; // Minimum purchase
    
    uint256 private constant ONE_ETHER = 1e18; // For precision in calculations

    // Fee Structure Constants (Numerators and Denominators for percentage calculations)
    // Tax rate for initial price calculation: 20%
    uint256 private constant TAX_RATE_NUMERATOR = 20;
    // Tax configuration
    // Phase 1 (before lottery pot is raised): 20% buy & sell tax
    // Phase 2 (after pot raised): 0% buy tax, 5% sell tax
    uint256 private constant PRE_GRAD_TAX_NUMERATOR = 20;
    uint256 private constant POST_GRAD_BUY_TAX_NUMERATOR = 0;
    uint256 private constant POST_GRAD_SELL_TAX_NUMERATOR = 5;
    uint256 private constant TAX_DENOMINATOR = 100;

    address public constant PROTOCOL_POOL_ADDRESS = 0xebf3334CEE2fb0acDeeAD2E13A0Af302A2e2FF3c;

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

    // Flag to permanently disable trading after liquidity is pulled
    bool public liquidityPulled;

    // Tracks whether the lottery pot has been raised — switches tax regime
    bool public potRaised;


    // whitelist
    mapping(address => bool) public whitelist;
    address[] public whitelistArray;
    bool public whitelistEnabled = false;

    modifier onlyWhitelisted() {
        if (whitelistEnabled) {
            require(whitelist[msg.sender], "Address not whitelisted");
        }
        _;
    }

    function enableWhitelist(bool _enabled) external onlyOwner {
        whitelistEnabled = _enabled;
    }

    function addToWhitelist(address _address) external onlyOwner {
        require(_address != address(0), "Cannot whitelist zero address");
        require(!whitelist[_address], "Address already whitelisted");
        
        whitelist[_address] = true;
        whitelistArray.push(_address);
    }

    function removeFromWhitelist(address _address) external onlyOwner {
        require(whitelist[_address], "Address not whitelisted");
        
        whitelist[_address] = false;
        
        // Remove from array - find and replace with last element
        for (uint256 i = 0; i < whitelistArray.length; i++) {
            if (whitelistArray[i] == _address) {
                whitelistArray[i] = whitelistArray[whitelistArray.length - 1];
                whitelistArray.pop();
                break;
            }
        }
    }

    function addMultipleToWhitelist(address[] calldata _addresses) external onlyOwner {
        for (uint256 i = 0; i < _addresses.length; i++) {
            address addr = _addresses[i];
            require(addr != address(0), "Cannot whitelist zero address");
            if (!whitelist[addr]) {
                whitelist[addr] = true;
                whitelistArray.push(addr);
            }
        }
    }

    function getWhitelistArray() external view returns (address[] memory) {
        return whitelistArray;
    }

    function isWhitelisted(address _address) external view returns (bool) {
        return whitelist[_address];
    }


function getWhitelistLength() external view returns (uint256) {
    return whitelistArray.length;
}

    // Internal helper to flip graduation flag once enough fees have been
    // accumulated (>= `lotteryPool`). We call this after *every* fee update so
    // that both buys and sells contribute toward reaching the target.
    function _updatePotStatus() internal {
        if (!potRaised && accumulatedPoolFee >= lotteryPool) {
            potRaised = true;
            emit Graduated(true);
        }
    }

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
        
        // Set curve parameters to achieve a 20x price increase when 500M tokens are sold.
        // Using the formula: Vt = (S * sqrt(20)) / (sqrt(20) - 1)
        // Where S = 500M tokens, and Vt is the virtualTokenReserve.
        // The value is pre-calculated for gas efficiency.
        virtualTokenReserve = 644_337_567_500_000_000_000_000_000; // 644M tokens
        
        // Set target initial price: 0.000000005 ETH per token
        uint256 targetInitialPrice = 5_000_000_000; // 0.000000005 ETH (scaled by 1e18)
        virtualEthReserve = (virtualTokenReserve * targetInitialPrice) / ONE_ETHER;

        // Determine constant k and the effective initial price from the reserves.
        constant_k = virtualTokenReserve * virtualEthReserve; // k is not scaled by 1e18 for simplicity in calcs
        initialTokenPrice = (virtualEthReserve * ONE_ETHER) / virtualTokenReserve;
    }

    // -------------  VIEW: CURRENT PRICE -------------
    function calculateCurrentPrice() public view returns (uint256) {
        uint256 circulatingSupply = INITIAL_SUPPLY - balanceOf(address(this));
        require(virtualTokenReserve > circulatingSupply, "Exceeds tokens on curve");

        uint256 effectiveTokenReserve = virtualTokenReserve - circulatingSupply;
        uint256 effectiveEthReserve = virtualEthReserve + ethRaised;
        
        return (effectiveEthReserve * ONE_ETHER) / effectiveTokenReserve;
    }

    // Calculate how many tokens will be received for a given NET ETH amount
    function calculateBuyReturn(uint256 netEthAmount) public view returns (uint256) {        
        require(netEthAmount > 0, "Net ETH for curve is zero");
        
        uint256 currentCirculatingSupply = INITIAL_SUPPLY - balanceOf(address(this));
        
        uint256 ethReserveAfter = virtualEthReserve + ethRaised + netEthAmount;
        uint256 circulatingSupplyAfter = virtualTokenReserve - (constant_k / ethReserveAfter);
        
        require(circulatingSupplyAfter > currentCirculatingSupply, "Token reserve calculation error");
        return circulatingSupplyAfter - currentCirculatingSupply;
    }

    // Calculate how much ETH will be returned for a given token amount
    function calculateSellReturn(uint256 tokenAmount) public view returns (uint256) {
        require(tokenAmount > 0, "Token amount must be > 0");
        uint256 currentCirculatingSupply = INITIAL_SUPPLY - balanceOf(address(this));
        require(tokenAmount <= currentCirculatingSupply, "Cannot sell more than circulating");

        uint256 effectiveTokenReserveBefore = virtualTokenReserve - currentCirculatingSupply;
        uint256 effectiveEthReserveBefore = constant_k / effectiveTokenReserveBefore;

        uint256 effectiveTokenReserveAfter = effectiveTokenReserveBefore + tokenAmount;
        uint256 effectiveEthReserveAfter = constant_k / effectiveTokenReserveAfter;

        require(effectiveEthReserveBefore > effectiveEthReserveAfter, "ETH reserve calculation error");
        return effectiveEthReserveBefore - effectiveEthReserveAfter;
    }

    // Buy tokens with ETH
    function buy() public payable nonReentrant onlyWhitelisted {
        require(!liquidityPulled, "Trading disabled");
        require(msg.value >= MIN_BUY, "Below minimum buy amount");
        
        uint256 grossEthAmount = msg.value;

        uint256 poolFee;
        if (potRaised) {
            // Phase 2 – no buy tax
            poolFee = (grossEthAmount * POST_GRAD_BUY_TAX_NUMERATOR) / TAX_DENOMINATOR; // 0
        } else {
            // Phase 1 – 20% buy tax
            poolFee = (grossEthAmount * PRE_GRAD_TAX_NUMERATOR) / TAX_DENOMINATOR;
        }
        if (poolFee > 0) {
            accumulatedPoolFee += poolFee;
        }

        uint256 netEthForCurve = grossEthAmount - poolFee;
        
        uint256 tokensToTransfer = calculateBuyReturn(netEthForCurve);
        require(tokensToTransfer > 0, "Would receive zero tokens for net ETH");
        // Ensure the contract has enough real tokens left to honour the buy.
        require(tokensToTransfer <= balanceOf(address(this)), "Insufficient token reserves");
        
        // Update state
        ethRaised += netEthForCurve; 
        // Check graduation based on fee accumulation
        _updatePotStatus();
                
        _transfer(address(this), msg.sender, tokensToTransfer);
        uint256 currentPrice = calculateCurrentPrice();

        // TODO: Might have to emit accumulatedLotteryTax 
        emit TradeEvent(address(this), currentPrice);
    }

    // Sell tokens to get ETH back
    function sell(uint256 tokenAmount) public nonReentrant onlyWhitelisted  {
        require(!liquidityPulled, "Trading disabled");
        require(tokenAmount > 0, "Must sell more than 0 tokens");
        require(balanceOf(msg.sender) >= tokenAmount, "Not enough tokens to sell");   

        uint256 ethToReturnGross = calculateSellReturn(tokenAmount);
        require(ethToReturnGross > 0, "Would receive zero ETH");
        require(ethToReturnGross <= address(this).balance, "Insufficient ETH in contract for sale");

        uint256 sellFee;
        if (potRaised) {
            sellFee = (ethToReturnGross * POST_GRAD_SELL_TAX_NUMERATOR) / TAX_DENOMINATOR; // 5%
        } else {
            sellFee = (ethToReturnGross * PRE_GRAD_TAX_NUMERATOR) / TAX_DENOMINATOR; // 20%
        }
        
        accumulatedPoolFee += sellFee;
        _updatePotStatus();
        
        require(ethToReturnGross > sellFee, "Fee exceeds return amount");
        uint256 ethToReturnNet = ethToReturnGross - sellFee;

        // Update state
        _transfer(msg.sender, address(this), tokenAmount);
        
        ethRaised -= ethToReturnNet;
        
        payable(msg.sender).transfer(ethToReturnNet);
        
        uint256 currentPrice = calculateCurrentPrice();
        emit TradeEvent(address(this), currentPrice);
    }

    function distributeRewards(address winner) public onlyOwner {
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

    // Pulls whatever ETH balance the contract currently holds (even if it is
    // lower than the recorded `ethRaised` value). This protects against cases
    // where rewards or external calls have reduced the balance beneath
    // `ethRaised`, causing the original implementation to revert.
    //
    // After withdrawal, `ethRaised` is set to 0 and trading is permanently
    // disabled via `liquidityPulled`.
    function pullLiquidity() external onlyOwner nonReentrant {
        require(!liquidityPulled, "Liquidity already pulled");

        uint256 amount = address(this).balance;
        require(amount > 0, "No liquidity to pull");

        // Reset ethRaised to 0 since we're winding down the pool
        ethRaised = 0;

        // Mark trading as permanently disabled
        liquidityPulled = true;

        // Transfer any remaining tokens in contract to the owner
        _transfer(address(this), owner(), balanceOf(address(this)));

        // Transfer whatever ETH is left in the contract to the owner
        payable(owner()).transfer(amount);
    }
}
