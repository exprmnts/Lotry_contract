// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/LotryStaking.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1_000_000 * 10 ** 18);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract LotryStakingTest is Test {
    LotryStaking public staking;
    MockERC20 public lotryToken;
    MockERC20 public rewardToken1;
    MockERC20 public rewardToken2;

    address public owner = address(1);
    address public user1 = address(2);
    address public user2 = address(3);
    address public user3 = address(4);

    uint256 constant STAKE_AMOUNT = 1000 * 10 ** 18;
    uint256 constant REWARD_AMOUNT = 500 * 10 ** 18;

    function setUp() public {
        // Deploy contracts
        vm.prank(owner);
        staking = new LotryStaking(owner);

        lotryToken = new MockERC20("LOTRY", "LOTRY");
        rewardToken1 = new MockERC20("Reward1", "RWD1");
        rewardToken2 = new MockERC20("Reward2", "RWD2");

        // Distribute tokens
        lotryToken.transfer(user1, 10000 * 10 ** 18);
        lotryToken.transfer(user2, 10000 * 10 ** 18);
        lotryToken.transfer(user3, 10000 * 10 ** 18);

        rewardToken1.transfer(owner, 10000 * 10 ** 18);
        rewardToken2.transfer(owner, 10000 * 10 ** 18);

        // Set stake token
        vm.prank(owner);
        staking.setStakeToken(address(lotryToken));
    }

    // ============ Setup Tests ============

    function testSetStakeToken() public {
        assertEq(address(staking.stakeToken()), address(lotryToken));
    }

    function testCannotSetZeroAddressStakeToken() public {
        vm.prank(owner);
        vm.expectRevert(LotryStaking.ZeroAddress.selector);
        staking.setStakeToken(address(0));
    }

    function testOnlyOwnerCanSetStakeToken() public {
        vm.prank(user1);
        vm.expectRevert();
        staking.setStakeToken(address(lotryToken));
    }

    // ============ Staking Tests ============

    function testStake() public {
        vm.startPrank(user1);
        lotryToken.approve(address(staking), STAKE_AMOUNT);
        staking.stake(STAKE_AMOUNT);
        vm.stopPrank();

        (uint256 amount,,,) = staking.getStakeInfo(user1);
        assertEq(amount, STAKE_AMOUNT);
        assertEq(staking.totalStaked(), STAKE_AMOUNT);
    }

    function testCannotStakeZero() public {
        vm.startPrank(user1);
        lotryToken.approve(address(staking), STAKE_AMOUNT);
        vm.expectRevert(LotryStaking.ZeroAmount.selector);
        staking.stake(0);
        vm.stopPrank();
    }

    function testMultipleUsersStake() public {
        // User1 stakes
        vm.startPrank(user1);
        lotryToken.approve(address(staking), STAKE_AMOUNT);
        staking.stake(STAKE_AMOUNT);
        vm.stopPrank();

        // User2 stakes
        vm.startPrank(user2);
        lotryToken.approve(address(staking), STAKE_AMOUNT * 2);
        staking.stake(STAKE_AMOUNT * 2);
        vm.stopPrank();

        assertEq(staking.totalStaked(), STAKE_AMOUNT * 3);
    }

    function testCannotStakeWhileUnstaking() public {
        // Stake first
        vm.startPrank(user1);
        lotryToken.approve(address(staking), STAKE_AMOUNT * 2);
        staking.stake(STAKE_AMOUNT);

        // Initiate unstake
        staking.initiateUnstake();

        // Try to stake again
        vm.expectRevert(LotryStaking.AlreadyUnstaking.selector);
        staking.stake(STAKE_AMOUNT);
        vm.stopPrank();
    }

    // ============ Reward Tests ============

    function testSetDailyReward() public {
        vm.startPrank(owner);
        rewardToken1.approve(address(staking), REWARD_AMOUNT);
        staking.setDailyReward(address(rewardToken1), REWARD_AMOUNT);
        vm.stopPrank();

        assertEq(staking.currentDay(), 1);
        assertEq(staking.currentDayRewardPool(), REWARD_AMOUNT);

        (address token, uint256 amount, uint256 snapshot) = staking.getDayRewardInfo(1);
        assertEq(token, address(rewardToken1));
        assertEq(amount, REWARD_AMOUNT);
        assertEq(snapshot, 0); // No stakes yet
    }

    function testProRataRewardCalculation() public {
        // User1 stakes 1000
        vm.startPrank(user1);
        lotryToken.approve(address(staking), STAKE_AMOUNT);
        staking.stake(STAKE_AMOUNT);
        vm.stopPrank();

        // User2 stakes 2000
        vm.startPrank(user2);
        lotryToken.approve(address(staking), STAKE_AMOUNT * 2);
        staking.stake(STAKE_AMOUNT * 2);
        vm.stopPrank();

        // Set daily reward (total staked = 3000)
        vm.startPrank(owner);
        rewardToken1.approve(address(staking), REWARD_AMOUNT);
        staking.setDailyReward(address(rewardToken1), REWARD_AMOUNT);
        vm.stopPrank();

        // User1 should get 1/3 of rewards
        uint256 user1Reward = staking.calculateReward(user1, 1);
        assertEq(user1Reward, REWARD_AMOUNT / 3);

        // User2 should get 2/3 of rewards
        uint256 user2Reward = staking.calculateReward(user2, 1);
        assertEq(user2Reward, (REWARD_AMOUNT * 2) / 3);
    }

    function testClaimReward() public {
        // Setup: User1 stakes
        vm.startPrank(user1);
        lotryToken.approve(address(staking), STAKE_AMOUNT);
        staking.stake(STAKE_AMOUNT);
        vm.stopPrank();

        // Set daily reward
        vm.startPrank(owner);
        rewardToken1.approve(address(staking), REWARD_AMOUNT);
        staking.setDailyReward(address(rewardToken1), REWARD_AMOUNT);
        vm.stopPrank();

        // Claim reward
        uint256 balanceBefore = rewardToken1.balanceOf(user1);
        vm.prank(user1);
        staking.claimReward(1);

        uint256 balanceAfter = rewardToken1.balanceOf(user1);
        assertEq(balanceAfter - balanceBefore, REWARD_AMOUNT);
    }

    function testCannotClaimTwice() public {
        // Setup and claim once
        vm.startPrank(user1);
        lotryToken.approve(address(staking), STAKE_AMOUNT);
        staking.stake(STAKE_AMOUNT);
        vm.stopPrank();

        vm.startPrank(owner);
        rewardToken1.approve(address(staking), REWARD_AMOUNT);
        staking.setDailyReward(address(rewardToken1), REWARD_AMOUNT);
        vm.stopPrank();

        vm.startPrank(user1);
        staking.claimReward(1);

        // Try to claim again
        vm.expectRevert(LotryStaking.AlreadyClaimed.selector);
        staking.claimReward(1);
        vm.stopPrank();
    }

    function testCannotClaimInvalidDay() public {
        vm.prank(user1);
        vm.expectRevert(LotryStaking.NoRewardForDay.selector);
        staking.claimReward(999);
    }

    function testMultipleDaysRewards() public {
        // User1 stakes
        vm.startPrank(user1);
        lotryToken.approve(address(staking), STAKE_AMOUNT);
        staking.stake(STAKE_AMOUNT);
        vm.stopPrank();

        // Day 1 reward
        vm.startPrank(owner);
        rewardToken1.approve(address(staking), REWARD_AMOUNT);
        staking.setDailyReward(address(rewardToken1), REWARD_AMOUNT);
        vm.stopPrank();

        // Day 2 reward (different token)
        vm.startPrank(owner);
        rewardToken2.approve(address(staking), REWARD_AMOUNT * 2);
        staking.setDailyReward(address(rewardToken2), REWARD_AMOUNT * 2);
        vm.stopPrank();

        assertEq(staking.currentDay(), 2);

        // Claim both days
        vm.startPrank(user1);
        staking.claimReward(1);
        staking.claimReward(2);
        vm.stopPrank();

        assertEq(rewardToken1.balanceOf(user1), REWARD_AMOUNT);
        assertEq(rewardToken2.balanceOf(user1), REWARD_AMOUNT * 2);
    }

    // ============ Unstaking Tests ============

    function testInitiateUnstake() public {
        // Stake first
        vm.startPrank(user1);
        lotryToken.approve(address(staking), STAKE_AMOUNT);
        staking.stake(STAKE_AMOUNT);

        // Initiate unstake
        staking.initiateUnstake();
        vm.stopPrank();

        (,, bool isUnstaking, uint256 unlockTime) = staking.getStakeInfo(user1);
        assertTrue(isUnstaking);
        assertEq(unlockTime, block.timestamp + 2 weeks);

        // Total staked should decrease
        assertEq(staking.totalStaked(), 0);
    }

    function testCannotUnstakeBeforePeriod() public {
        // Stake and initiate unstake
        vm.startPrank(user1);
        lotryToken.approve(address(staking), STAKE_AMOUNT);
        staking.stake(STAKE_AMOUNT);
        staking.initiateUnstake();

        // Try to unstake immediately
        vm.expectRevert(LotryStaking.UnlockPeriodNotPassed.selector);
        staking.unstake();
        vm.stopPrank();
    }

    function testUnstakeAfterPeriod() public {
        // Stake and initiate unstake
        vm.startPrank(user1);
        lotryToken.approve(address(staking), STAKE_AMOUNT);
        staking.stake(STAKE_AMOUNT);
        staking.initiateUnstake();

        // Fast forward 2 weeks
        vm.warp(block.timestamp + 2 weeks);

        // Unstake
        uint256 balanceBefore = lotryToken.balanceOf(user1);
        staking.unstake();
        uint256 balanceAfter = lotryToken.balanceOf(user1);

        assertEq(balanceAfter - balanceBefore, STAKE_AMOUNT);
        vm.stopPrank();
    }

    function testNoRewardDuringUnstaking() public {
        // User1 stakes
        vm.startPrank(user1);
        lotryToken.approve(address(staking), STAKE_AMOUNT);
        staking.stake(STAKE_AMOUNT);
        vm.stopPrank();

        // User2 stakes
        vm.startPrank(user2);
        lotryToken.approve(address(staking), STAKE_AMOUNT);
        staking.stake(STAKE_AMOUNT);
        vm.stopPrank();

        // User1 initiates unstake
        vm.prank(user1);
        staking.initiateUnstake();

        // Set daily reward (total staked = 1000, only user2)
        vm.startPrank(owner);
        rewardToken1.approve(address(staking), REWARD_AMOUNT);
        staking.setDailyReward(address(rewardToken1), REWARD_AMOUNT);
        vm.stopPrank();

        // User2 should get ALL rewards
        uint256 user2Reward = staking.calculateReward(user2, 1);
        assertEq(user2Reward, REWARD_AMOUNT);

        // User1 should get 0 (unstaking)
        uint256 user1Reward = staking.calculateReward(user1, 1);
        console.log("user1Reward", user1Reward);
        assertEq(user1Reward, 0);
    }

    // ============ Edge Cases ============

    function testFuzzStake(uint256 amount) public {
        vm.assume(amount > 0 && amount <= 10000 * 10 ** 18);

        lotryToken.mint(user1, amount);

        vm.startPrank(user1);
        lotryToken.approve(address(staking), amount);
        staking.stake(amount);
        vm.stopPrank();

        (uint256 stakedAmount,,,) = staking.getStakeInfo(user1);
        assertEq(stakedAmount, amount);
    }

    function testStakeAfterFullUnstakeCycle() public {
        // First cycle
        vm.startPrank(user1);
        lotryToken.approve(address(staking), STAKE_AMOUNT * 2);
        staking.stake(STAKE_AMOUNT);
        staking.initiateUnstake();
        vm.warp(block.timestamp + 2 weeks);
        staking.unstake();

        // Second cycle (should work)
        staking.stake(STAKE_AMOUNT);
        vm.stopPrank();

        (uint256 amount,,,) = staking.getStakeInfo(user1);
        assertEq(amount, STAKE_AMOUNT);
    }

    function testRewardRoundingEdgeCase() public {
        // Create scenario with potential rounding issues
        // User1: 1 wei
        // User2: 999 wei
        // Total: 1000 wei
        // Reward: 999 wei

        vm.startPrank(user1);
        lotryToken.approve(address(staking), 1);
        staking.stake(1);
        vm.stopPrank();

        vm.startPrank(user2);
        lotryToken.approve(address(staking), 999);
        staking.stake(999);
        vm.stopPrank();

        vm.startPrank(owner);
        rewardToken1.approve(address(staking), 999);
        staking.setDailyReward(address(rewardToken1), 999);
        vm.stopPrank();

        // User1 gets floor(999 * 1 / 1000) = 0
        uint256 user1Reward = staking.calculateReward(user1, 1);
        assertEq(user1Reward, 0);

        // User2 gets floor(999 * 999 / 1000) = 998
        uint256 user2Reward = staking.calculateReward(user2, 1);
        assertEq(user2Reward, 998);
    }
}
