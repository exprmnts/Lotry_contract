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

                    
                █   █▀█ ▀█▀ █▀█ █▄█   █▀█ █▀█ █▀█ ▀█▀ █▀█ █▀▀ █▀█ █
                █▄▄ █▄█  █  █▀▄  █    █▀▀ █▀▄ █▄█  █  █▄█ █▄▄ █▄█ █▄▄

*/

/**
 * @title Lotry Staking
 * @author @lotrydotfun
 * @notice This contract is for staking a Lotry Token. Pro-rata reward distribution based on stake percentage
 */
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract LotryStaking is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ State Variables ============

    IERC20 public stakeToken;
    IERC20 public currentRewardToken;

    uint256 public constant UNLOCK_PERIOD = 2 weeks;

    uint256 public totalStaked;
    uint256 public currentDayRewardPool;
    uint256 public currentDay;

    struct StakeInfo {
        uint256 amount;
        uint256 unstakeInitiatedAt;
        bool isUnstaking;
    }

    struct DayReward {
        IERC20 rewardToken;
        uint256 rewardAmount;
        uint256 totalStakedSnapshot;
        mapping(address => bool) hasClaimed;
    }

    mapping(address => StakeInfo) public stakes;
    mapping(uint256 => DayReward) public dayRewards;

    // ============ Events ============

    event StakeTokenSet(address indexed token);
    event RewardTokenSet(uint256 indexed day, address indexed token, uint256 amount);
    event Staked(address indexed user, uint256 amount);
    event UnstakeInitiated(address indexed user, uint256 amount, uint256 unlockTime);
    event Unstaked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 indexed day, uint256 amount);

    // ============ Errors ============

    error ZeroAddress();
    error ZeroAmount();
    error InsufficientStake();
    error AlreadyUnstaking();
    error NotUnstaking();
    error UnlockPeriodNotPassed();
    error AlreadyClaimed();
    error NoRewardForDay();
    error NoStakeAtSnapshot();
    error TransferFailed();
    // ============ Constructor ============

    constructor(address initialOwner) Ownable(initialOwner) {
        if (initialOwner == address(0)) revert ZeroAddress();
    }
}
