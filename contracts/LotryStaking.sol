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
// @notice Staking contract for LOTRY tokens

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract LotryStaking is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ State Variables ============

    IERC20 public stakeToken;
    uint256 public totalStaked;

    // Track all stakers
    address[] public stakers;
    mapping(address => bool) public isStaker;
    mapping(address => uint256) public stakedAmount;

    // ============ Events ============

    event StakeTokenSet(address indexed token);
    event Staked(address indexed user, uint256 amount);

    // ============ Errors ============

    error ZeroAddress();
    error ZeroAmount();

    // ============ Constructor ============

    constructor(address initialOwner) Ownable(initialOwner) {
        if (initialOwner == address(0)) revert ZeroAddress();
    }

    // ============ Admin Functions ============

    // @notice Set the staking token address (LOTRY)
    // @param _stakeToken Address of the LOTRY token
    function setStakeToken(address _stakeToken) external onlyOwner {
        if (_stakeToken == address(0)) revert ZeroAddress();
        stakeToken = IERC20(_stakeToken);
        emit StakeTokenSet(_stakeToken);
    }

    // @notice Get all staked LOTRY amounts from contract (ONLY OWNER)
    // @return _stakers Array of staker addresses
    // @return _amounts Array of staked amounts corresponding to each staker
    // @return _totalStaked Total amount of LOTRY staked in the contract
    function getAllStakedAmounts()
        external
        view
        onlyOwner
        returns (address[] memory _stakers, uint256[] memory _amounts, uint256 _totalStaked)
    {
        uint256 length = stakers.length;
        _stakers = new address[](length);
        _amounts = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            _stakers[i] = stakers[i];
            _amounts[i] = stakedAmount[stakers[i]];
        }

        _totalStaked = totalStaked;
    }

    // ============ User Functions ============

    // @notice Stake LOTRY tokens
    // @param _amount Amount of tokens to stake
    function stake(uint256 _amount) external nonReentrant {
        if (address(stakeToken) == address(0)) revert ZeroAddress();
        if (_amount == 0) revert ZeroAmount();

        // Add to stakers list if first time staking
        if (!isStaker[msg.sender]) {
            stakers.push(msg.sender);
            isStaker[msg.sender] = true;
        }

        // Update state
        stakedAmount[msg.sender] += _amount;
        totalStaked += _amount;

        // Transfer tokens
        stakeToken.safeTransferFrom(msg.sender, address(this), _amount);

        emit Staked(msg.sender, _amount);
    }

    // ============ View Functions ============

    // @notice Get stake amount for a specific user
    // @param _user Address of the user
    // @return Amount staked by the user
    function getStakeAmount(address _user) external view returns (uint256) {
        return stakedAmount[_user];
    }

    // @notice Get total number of stakers
    // @return Number of unique stakers
    function getStakersCount() external view returns (uint256) {
        return stakers.length;
    }
}
