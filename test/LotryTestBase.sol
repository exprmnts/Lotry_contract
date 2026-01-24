// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {LotryTicket} from "../contracts/LotryTicket.sol";
import {LotryLaunch} from "../contracts/LotryLaunch.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title Mock LOTRY Token
 * @notice A simple ERC20 token to simulate the $LOTRY token for testing
 */
contract MockLotryToken is ERC20 {
    constructor() ERC20("LOTRY", "LOTRY") {
        // Mint 1 trillion tokens for testing (with 18 decimals)
        _mint(msg.sender, 1_000_000_000_000 * 1e18);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/**
 * @title Mock Reward Token
 * @notice A simple ERC20 token to simulate reward tokens for testing
 */
contract MockRewardToken is ERC20 {
    constructor() ERC20("Reward Token", "RWD") {
        _mint(msg.sender, 1_000_000_000 * 1e18);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/**
 * @title Mock Non-Returning ERC20 Token
 * @notice Simulates tokens that don't return bool on transfer (like USDT)
 * @dev Used to test SafeERC20 compatibility
 */
contract MockNonReturningToken {
    string public name = "NonReturning";
    string public symbol = "NRT";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    constructor() {
        totalSupply = 1_000_000_000 * 1e18;
        balanceOf[msg.sender] = totalSupply;
    }
    
    function transfer(address to, uint256 amount) external {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        // Intentionally does NOT return bool
    }
    
    function transferFrom(address from, address to, uint256 amount) external {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        // Intentionally does NOT return bool
    }
    
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
}

/**
 * @title Mock Smart Wallet (Simulates contract wallet like Safe/Argent)
 * @notice Tests that funds can be sent to contract wallets
 */
contract MockSmartWallet {
    address public owner;
    
    constructor() {
        owner = msg.sender;
    }
    
    // This contract can receive ERC20 tokens
    function withdrawToken(address token, address to, uint256 amount) external {
        require(msg.sender == owner, "Not owner");
        ERC20(token).transfer(to, amount);
    }
    
    function getTokenBalance(address token) external view returns (uint256) {
        return ERC20(token).balanceOf(address(this));
    }
}

/**
 * @title LotryTicket Test Base
 * @notice Base contract with shared setup and helpers for all test files
 */
abstract contract LotryTestBase is Test {
    // ============ Constants ============
    uint256 constant LOTRY_SCALE = 1e10;
    uint256 constant MIN_BUY = 1;
    uint256 constant INITIAL_SUPPLY = 1_000_000_000 * 1e18; // 1B tokens
    uint256 constant TAX_NUMERATOR = 11;
    uint256 constant TAX_DENOMINATOR = 100;
    address constant PROTOCOL_WALLET = 0xebf3334CEE2fb0acDeeAD2E13A0Af302A2e2FF3c;

    // ============ Contracts ============
    LotryLaunch public launchpad;
    LotryTicket public ticket;
    MockLotryToken public lotryToken;
    MockRewardToken public rewardToken;

    // ============ Actors ============
    address public deployer;
    address public tokenCreator;
    address public buyer1;
    address public buyer2;
    address public buyer3;
    address public winner;
    address public attacker;

    // ============ Events ============
    event TokenCreated(
        address indexed tokenAddress,
        address indexed creator,
        uint256 indexed tokenId,
        uint256 timestamp,
        string name,
        string symbol
    );
    event TradeEvent(address indexed tokenAddress, uint256 lotryPrice);
    event RewardsDistributed(address indexed winner, uint256 winnerPrizeAmount, uint256 protocolAmount);
    event LiquidityPulled(uint256 totalAmountDistributed);

    // ============ Setup ============
    function setUp() public virtual {
        console.log("========================================");
        console.log("           SETTING UP TESTS");
        console.log("========================================");

        // Create actors
        deployer = makeAddr("deployer");
        tokenCreator = makeAddr("tokenCreator");
        buyer1 = makeAddr("buyer1");
        buyer2 = makeAddr("buyer2");
        buyer3 = makeAddr("buyer3");
        winner = makeAddr("winner");
        attacker = makeAddr("attacker");

        console.log("Deployer:", deployer);
        console.log("Token Creator:", tokenCreator);
        console.log("Buyer1:", buyer1);
        console.log("Buyer2:", buyer2);
        console.log("Winner:", winner);

        // Deploy contracts as deployer
        vm.startPrank(deployer);

        // Deploy mock $LOTRY token
        lotryToken = new MockLotryToken();
        console.log("Mock LOTRY Token deployed at:", address(lotryToken));

        // Deploy mock reward token
        rewardToken = new MockRewardToken();
        console.log("Mock Reward Token deployed at:", address(rewardToken));

        // Deploy launchpad
        launchpad = new LotryLaunch(deployer);
        console.log("Launchpad deployed at:", address(launchpad));

        vm.stopPrank();

        // Token creator launches a ticket
        vm.startPrank(tokenCreator);
        address ticketAddress = launchpad.launchToken("Test Ticket", "TCKT");
        ticket = LotryTicket(ticketAddress);
        console.log("LotryTicket deployed at:", address(ticket));
        console.log("Ticket Owner:", ticket.owner());
        vm.stopPrank();

        // Distribute $LOTRY tokens to buyers
        vm.startPrank(deployer);
        uint256 buyerAllocation = 100_000_000_000 * 1e18; // 100B $LOTRY each
        lotryToken.transfer(buyer1, buyerAllocation);
        lotryToken.transfer(buyer2, buyerAllocation);
        lotryToken.transfer(buyer3, buyerAllocation);
        lotryToken.transfer(attacker, buyerAllocation);
        lotryToken.transfer(tokenCreator, buyerAllocation);
        console.log("Distributed LOTRY to buyers for testing:", buyerAllocation / 1e18, "LOTRY each");
        vm.stopPrank();

        console.log("========================================");
        console.log("           SETUP COMPLETE");
        console.log("========================================\n");
    }

    // ============ Helper Functions ============
    function _setupLotryToken() internal {
        vm.prank(tokenCreator);
        ticket.setLotryToken(address(lotryToken));
    }

    function _setupRewardToken() internal {
        vm.prank(tokenCreator);
        ticket.setRewardToken(address(rewardToken));
    }

    function _approveAndBuy(address buyer, uint256 amount) internal {
        vm.startPrank(buyer);
        lotryToken.approve(address(ticket), amount);
        ticket.buy(amount);
        vm.stopPrank();
    }

    function _formatLotry(uint256 amount) internal pure returns (string memory) {
        return string(abi.encodePacked(vm.toString(amount / 1e18), " LOTRY"));
    }

    function _generateTrading(uint256 numTrades, uint256 amountPerTrade) internal {
        for (uint256 i = 0; i < numTrades; i++) {
            address buyer = i % 3 == 0 ? buyer1 : (i % 3 == 1 ? buyer2 : buyer3);
            _approveAndBuy(buyer, amountPerTrade);
        }
    }
}

