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

// @title Lotry Staking
// @author @lotrydotfun
// @notice This contract is for staking a Lotry Token. Pro-rata reward distribution based on stake percentage

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

    // ============ Admin Functions ============

    // @notice Set the staking token address
    // @param _stakeToken Address of the token to be staked
    function setStakeToken(address _stakeToken) external onlyOwner {
        if (_stakeToken == address(0)) revert ZeroAddress();
        stakeToken = IERC20(_stakeToken);
        emit StakeTokenSet(_stakeToken);
    }

    // @notice Set daily reward token and deposit rewards
    // @param _rewardToken Address of the reward token
    // @param _amount Amount of reward tokens to distribute
    function setDailyReward(address _rewardToken, uint256 _amount) external onlyOwner nonReentrant {
        if (_rewardToken == address(0)) revert ZeroAddress();
        if (_amount == 0) revert ZeroAmount();

        // increment day
        currentDay++;

        // set reward token and pool
        IERC20 rewardToken = IERC20(_rewardToken);
        currentRewardToken = rewardToken;
        currentDayRewardPool = _amount;

        // store day snapshot
        DayReward storage dayReward = dayRewards[currentDay];
        dayReward.rewardToken = rewardToken;
        dayReward.rewardAmount = _amount;
        dayReward.totalStakedSnapshot = totalStaked;

        // transfer reward tokens to contract
        rewardToken.safeTransferFrom(msg.sender, address(this), _amount);

        emit RewardTokenSet(currentDay, _rewardToken, _amount);
    }

    // ============ User Functions ============

    // @notice Stake LOTRY tokens
    // @param _amount Amount of tokens to stake
    function stake(uint256 _amount) external nonReentrant {
        if (address(stakeToken) == address(0)) revert ZeroAddress();
        if (_amount == 0) revert ZeroAmount();

        StakeInfo storage stakeInfo = stakes[msg.sender];

        // can't stake if in unstaking period
        if (stakeInfo.isUnstaking) revert AlreadyUnstaking();

        // update state
        stakeInfo.amount += _amount;
        totalStaked += _amount;

        // transfer tokens
        stakeToken.safeTransferFrom(msg.sender, address(this), _amount);

        emit Staked(msg.sender, _amount);
    }

    // @notice (starts 2-week unlock period)
    function initiateUnstake() external nonReentrant {
        StakeInfo storage stakeInfo = stakes[msg.sender];

        if (stakeInfo.amount == 0) revert InsufficientStake();
        if (stakeInfo.isUnstaking) revert AlreadyUnstaking();

        // Start unstaking period
        stakeInfo.isUnstaking = true;
        stakeInfo.unstakeInitiatedAt = block.timestamp;

        // remove from total staked (no longer eligible for rewards)
        totalStaked -= stakeInfo.amount;

        uint256 unlockTime = block.timestamp + UNLOCK_PERIOD;
        emit UnstakeInitiated(msg.sender, stakeInfo.amount, unlockTime);
    }

    // @notice Unstake tokens after unlock period, this has to be called by staker to claim the tokens
    function unstake() external nonReentrant {
        StakeInfo storage stakeInfo = stakes[msg.sender];

        if (!stakeInfo.isUnstaking) revert NotUnstaking();
        if (block.timestamp < stakeInfo.unstakeInitiatedAt + UNLOCK_PERIOD) {
            revert UnlockPeriodNotPassed();
        }

        uint256 amount = stakeInfo.amount;

        // reset stake info
        delete stakes[msg.sender];

        // transfer tokens back
        stakeToken.safeTransfer(msg.sender, amount);

        emit Unstaked(msg.sender, amount);
    }

    // @notice Claim rewards for a specific day
    // @param _day Day number to claim rewards for
    function claimReward(uint256 _day) external nonReentrant {
        if (_day == 0 || _day > currentDay) revert NoRewardForDay();

        DayReward storage dayReward = dayRewards[_day];

        if (dayReward.hasClaimed[msg.sender]) revert AlreadyClaimed();
        if (dayReward.totalStakedSnapshot == 0) revert NoStakeAtSnapshot();

        StakeInfo storage stakeInfo = stakes[msg.sender];

        // User must have had stake at the snapshot AND not be unstaking
        // Note: If user initiated unstake after this day's snapshot, their stake
        // was included in the snapshot, so they can claim
        if (stakeInfo.amount == 0) revert NoStakeAtSnapshot();

        // calculate pro-rata reward
        uint256 userReward = (dayReward.rewardAmount * stakeInfo.amount) / dayReward.totalStakedSnapshot;

        // mark as claimed
        dayReward.hasClaimed[msg.sender] = true;

        // transfer reward
        dayReward.rewardToken.safeTransfer(msg.sender, userReward);

        emit RewardClaimed(msg.sender, _day, userReward);
    }

    // @notice Get user's stake info
    function getStakeInfo(address _user)
        external
        view
        returns (uint256 amount, uint256 unstakeInitiatedAt, bool isUnstaking, uint256 unlockTime)
    {
        StakeInfo storage stakeInfo = stakes[_user];
        amount = stakeInfo.amount;
        unstakeInitiatedAt = stakeInfo.unstakeInitiatedAt;
        isUnstaking = stakeInfo.isUnstaking;

        if (isUnstaking) {
            unlockTime = unstakeInitiatedAt + UNLOCK_PERIOD;
        }
    }

    // @notice Calculate pending reward for a user for a specific day
    function calculateReward(address _user, uint256 _day) external view returns (uint256) {
        if (_day == 0 || _day > currentDay) return 0;

        DayReward storage dayReward = dayRewards[_day];
        if (dayReward.totalStakedSnapshot == 0) return 0;
        if (dayReward.hasClaimed[_user]) return 0;

        StakeInfo storage stakeInfo = stakes[_user];
        if (stakeInfo.amount == 0) return 0;

        return (dayReward.rewardAmount * stakeInfo.amount) / dayReward.totalStakedSnapshot;
    }

    // @notice  Check if user has claimed reward for a day
    function hasClaimed(address _user, uint256 _day) external view returns (bool) {
        return dayRewards[_day].hasClaimed[_user];
    }

    // @notice get staking rewards of a day
    function getDayRewardInfo(uint256 _day)
        external
        view
        returns (address rewardToken, uint256 rewardAmount, uint256 totalStakedSnapshot)
    {
        DayReward storage dayReward = dayRewards[_day];
        rewardToken = address(dayReward.rewardToken);
        rewardAmount = dayReward.rewardAmount;
        totalStakedSnapshot = dayReward.totalStakedSnapshot;
    }
}
