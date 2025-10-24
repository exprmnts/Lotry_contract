// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract LotryTicket is ERC20, Ownable, ReentrancyGuard {
    // ⠀⠀⠀⠀ ⠀⠀⢀⣤⣿⣶⣄⠀⠀⠀⣀⡀⠀⠀⠀⠀  //
    // ⠀⠀⣠⣤⣄⡀⣼⣿⣿⣿⣿⠀⣠⣾⣿⣿⡆⠀⠀⠀  //
    // ⠀⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣶⣿⣿⣿⣿⣧⣄⡀⠀  //
    // ⠀⠀⠻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡄  //
    // ⠀⠀⣀⣤⣽⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠃  //
    // ⢰⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣩⡉⠀⠀  //
    // ⠹⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣄  //
    // ⠀⠀⠉⣸⣿⣿⣿⣿⠏⢸⡏⣿⣿⣿⣿⣿⣿⣿⣿⡏  //
    // ⠀⠀⠀⢿⣿⣿⡿⠏⠀⢸⣇⢻⣿⣿⣿⣿⠉⠉⠁⠀  //
    // ⠀⠀⠀⠀⠈⠁⠀⠀⠀⠸⣿⡀⠙⠿⠿⠋⠀⠀⠀⠀  //
    // ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢹⣿⡀⠀⠀⠀⠀⠀⠀⠀  //

    uint256 public constant INITIAL_SUPPLY = 1_000_000_000_000_000_000_000_000_000;
    uint256 public constant MIN_BUY = 0.00001 ether;

    uint256 private constant ONE_ETHER = 1e18; // For precision in calculations

    // Fee Structure: 20% buy & sell tax
    uint256 private constant TAX_NUMERATOR = 20;
    uint256 private constant TAX_DENOMINATOR = 100;

    address public constant PROTOCOL_POOL_ADDRESS = 0xebf3334CEE2fb0acDeeAD2E13A0Af302A2e2FF3c;

    // State variables
    uint256 public ethRaised; // Total ETH in Liquidity
    uint256 public constant_k; // The K in the constant product formula (v_tokens * v_eth)

    // Virtual reserves
    uint256 public virtualTokenReserve = 17525652865772000000000000; // 17,525,652.865772
    uint256 public virtualEthReserve = 203505130573000000; // 0.203505130573 ETH

    // Accumulated Taxes/Fees
    uint256 public accumulatedPoolFee;

    // Flag to permanently disable trading after liquidity is pulled
    bool public liquidityPulled;

    // whitelist
    mapping(address => bool) public whitelist;
    bool public whitelistEnabled = true;

    // whitelist modifier
    modifier onlyWhitelisted() {
        if (whitelistEnabled) {
            require(whitelist[msg.sender], "Not whitelisted");
        }
        _;
    }

    // Events
    event TradeEvent(address indexed tokenAddress, uint256 ethPrice);
    event RewardsDistributed(address indexed winner, uint256 winnerPrizeAmount, uint256 protocolAmount);
    event LiquidityPulled(uint256 totalAmountDistributed);

    constructor(string memory name, string memory symbol, address initialOwner, address[] memory initialWhitelist)
        ERC20(name, symbol)
        Ownable(initialOwner)
    {
        _mint(address(this), INITIAL_SUPPLY);
        constant_k = (balanceOf(address(this)) + virtualTokenReserve) * virtualEthReserve;

        whitelist[address(this)] = true;

        // Add initial whitelist addresses
        for (uint256 i = 0; i < initialWhitelist.length; i++) {
            whitelist[initialWhitelist[i]] = true;
        }
    }

    function calculateCurrentPrice() public view returns (uint256) {
        uint256 tokensInContract = balanceOf(address(this));
        uint256 effectiveTokenReserve = virtualTokenReserve + tokensInContract;
        uint256 effectiveEthReserve = virtualEthReserve + ethRaised;

        return (effectiveEthReserve * ONE_ETHER) / effectiveTokenReserve;
    }

    // Calculate how many tokens will be received for a given NET ETH amount
    function calculateBuyReturn(uint256 netEthAmount) public view returns (uint256) {
        require(netEthAmount > 0, "Net ETH for curve is zero");
        return (balanceOf(address(this)) + virtualTokenReserve)
            - (constant_k / (virtualEthReserve + ethRaised + netEthAmount));
    }

    // Calculate how much ETH will be returned for a given token amount
    function calculateSellReturn(uint256 tokenAmount) public view returns (uint256) {
        require(tokenAmount > 0, "Token amount must be > 0");
        uint256 tokensInContract = balanceOf(address(this));
        require(tokenAmount <= INITIAL_SUPPLY - tokensInContract, "Cannot sell more than circulating");
        return (ethRaised + virtualEthReserve) - (constant_k / (virtualTokenReserve + tokensInContract + tokenAmount));
    }

    // Buy tokens with ETH
    function buy() public payable nonReentrant onlyWhitelisted {
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
        // Ensure the contract has enough real tokens left to honour the buy.
        require(tokensToTransfer <= balanceOf(address(this)), "Insufficient token reserves");

        // Update state
        ethRaised += netEthForCurve;

        _transfer(address(this), msg.sender, tokensToTransfer);
        uint256 currentPrice = calculateCurrentPrice();

        emit TradeEvent(address(this), currentPrice);
    }

    // Sell tokens to get ETH back
    function sell(uint256 tokenAmount) public nonReentrant onlyWhitelisted {
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
            payable(PROTOCOL_POOL_ADDRESS).transfer(protocolAmount);
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
