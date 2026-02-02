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

    address public owner = address(1);
    address public user1 = address(2);
    address public user2 = address(3);
    address public user3 = address(4);

    uint256 constant STAKE_AMOUNT = 1000 * 10 ** 18;

    // Events (mirrored from LotryStaking for testing)
    event StakeTokenSet(address indexed token);
    event Staked(address indexed user, uint256 amount);

    function setUp() public {
        // Deploy contracts
        vm.prank(owner);
        staking = new LotryStaking(owner);

        lotryToken = new MockERC20("LOTRY", "LOTRY");

        // Distribute tokens
        lotryToken.transfer(user1, 10000 * 10 ** 18);
        lotryToken.transfer(user2, 10000 * 10 ** 18);
        lotryToken.transfer(user3, 10000 * 10 ** 18);

        // Set stake token
        vm.prank(owner);
        staking.setStakeToken(address(lotryToken));
    }

    // ============ Constructor Tests ============

    function testConstructorSetsOwner() public view {
        assertEq(staking.owner(), owner);
    }

    function testConstructorRejectsZeroAddress() public {
        // OpenZeppelin's Ownable throws OwnableInvalidOwner before our custom check
        vm.expectRevert(abi.encodeWithSignature("OwnableInvalidOwner(address)", address(0)));
        new LotryStaking(address(0));
    }

    // ============ Setup Tests ============

    function testSetStakeToken() public view {
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

    function testSetStakeTokenEmitsEvent() public {
        LotryStaking newStaking = new LotryStaking(owner);
        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit StakeTokenSet(address(lotryToken));
        newStaking.setStakeToken(address(lotryToken));
    }

    // ============ Staking Tests ============

    function testStake() public {
        vm.startPrank(user1);
        lotryToken.approve(address(staking), STAKE_AMOUNT);
        staking.stake(STAKE_AMOUNT);
        vm.stopPrank();

        assertEq(staking.getStakeAmount(user1), STAKE_AMOUNT);
        assertEq(staking.totalStaked(), STAKE_AMOUNT);
    }

    function testStakeEmitsEvent() public {
        vm.startPrank(user1);
        lotryToken.approve(address(staking), STAKE_AMOUNT);

        vm.expectEmit(true, false, false, true);
        emit Staked(user1, STAKE_AMOUNT);
        staking.stake(STAKE_AMOUNT);
        vm.stopPrank();
    }

    function testCannotStakeZero() public {
        vm.startPrank(user1);
        lotryToken.approve(address(staking), STAKE_AMOUNT);
        vm.expectRevert(LotryStaking.ZeroAmount.selector);
        staking.stake(0);
        vm.stopPrank();
    }

    function testCannotStakeWithoutStakeTokenSet() public {
        LotryStaking newStaking = new LotryStaking(owner);

        vm.startPrank(user1);
        vm.expectRevert(LotryStaking.ZeroAddress.selector);
        newStaking.stake(STAKE_AMOUNT);
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
        assertEq(staking.getStakeAmount(user1), STAKE_AMOUNT);
        assertEq(staking.getStakeAmount(user2), STAKE_AMOUNT * 2);
    }

    function testUserCanStakeMultipleTimes() public {
        vm.startPrank(user1);
        lotryToken.approve(address(staking), STAKE_AMOUNT * 3);

        staking.stake(STAKE_AMOUNT);
        assertEq(staking.getStakeAmount(user1), STAKE_AMOUNT);

        staking.stake(STAKE_AMOUNT * 2);
        assertEq(staking.getStakeAmount(user1), STAKE_AMOUNT * 3);
        vm.stopPrank();

        // Should still only be one staker entry
        assertEq(staking.getStakersCount(), 1);
    }

    function testStakerAddedToListOnlyOnce() public {
        vm.startPrank(user1);
        lotryToken.approve(address(staking), STAKE_AMOUNT * 2);

        staking.stake(STAKE_AMOUNT);
        assertEq(staking.getStakersCount(), 1);
        assertTrue(staking.isStaker(user1));

        staking.stake(STAKE_AMOUNT);
        assertEq(staking.getStakersCount(), 1); // Still 1
        vm.stopPrank();
    }

    // ============ View Functions Tests ============

    function testGetStakeAmount() public {
        vm.startPrank(user1);
        lotryToken.approve(address(staking), STAKE_AMOUNT);
        staking.stake(STAKE_AMOUNT);
        vm.stopPrank();

        assertEq(staking.getStakeAmount(user1), STAKE_AMOUNT);
        assertEq(staking.getStakeAmount(user2), 0); // Non-staker
    }

    function testGetStakersCount() public {
        assertEq(staking.getStakersCount(), 0);

        vm.startPrank(user1);
        lotryToken.approve(address(staking), STAKE_AMOUNT);
        staking.stake(STAKE_AMOUNT);
        vm.stopPrank();

        assertEq(staking.getStakersCount(), 1);

        vm.startPrank(user2);
        lotryToken.approve(address(staking), STAKE_AMOUNT);
        staking.stake(STAKE_AMOUNT);
        vm.stopPrank();

        assertEq(staking.getStakersCount(), 2);
    }

    function testStakersArray() public {
        vm.startPrank(user1);
        lotryToken.approve(address(staking), STAKE_AMOUNT);
        staking.stake(STAKE_AMOUNT);
        vm.stopPrank();

        vm.startPrank(user2);
        lotryToken.approve(address(staking), STAKE_AMOUNT);
        staking.stake(STAKE_AMOUNT);
        vm.stopPrank();

        assertEq(staking.stakers(0), user1);
        assertEq(staking.stakers(1), user2);
    }

    function testIsStaker() public {
        assertFalse(staking.isStaker(user1));

        vm.startPrank(user1);
        lotryToken.approve(address(staking), STAKE_AMOUNT);
        staking.stake(STAKE_AMOUNT);
        vm.stopPrank();

        assertTrue(staking.isStaker(user1));
        assertFalse(staking.isStaker(user2));
    }

    function testStakedAmountMapping() public {
        vm.startPrank(user1);
        lotryToken.approve(address(staking), STAKE_AMOUNT);
        staking.stake(STAKE_AMOUNT);
        vm.stopPrank();

        assertEq(staking.stakedAmount(user1), STAKE_AMOUNT);
        assertEq(staking.stakedAmount(user2), 0);
    }

    // ============ getAllStakedAmounts Tests ============

    function testGetAllStakedAmountsOnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        staking.getAllStakedAmounts();
    }

    function testGetAllStakedAmountsEmpty() public {
        vm.prank(owner);
        (address[] memory _stakers, uint256[] memory _amounts, uint256 _totalStaked) = staking.getAllStakedAmounts();

        assertEq(_stakers.length, 0);
        assertEq(_amounts.length, 0);
        assertEq(_totalStaked, 0);
    }

    function testGetAllStakedAmounts() public {
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

        // User3 stakes
        vm.startPrank(user3);
        lotryToken.approve(address(staking), STAKE_AMOUNT * 3);
        staking.stake(STAKE_AMOUNT * 3);
        vm.stopPrank();

        vm.prank(owner);
        (address[] memory _stakers, uint256[] memory _amounts, uint256 _totalStaked) = staking.getAllStakedAmounts();

        assertEq(_stakers.length, 3);
        assertEq(_amounts.length, 3);
        assertEq(_totalStaked, STAKE_AMOUNT * 6);

        assertEq(_stakers[0], user1);
        assertEq(_stakers[1], user2);
        assertEq(_stakers[2], user3);

        assertEq(_amounts[0], STAKE_AMOUNT);
        assertEq(_amounts[1], STAKE_AMOUNT * 2);
        assertEq(_amounts[2], STAKE_AMOUNT * 3);
    }

    // ============ Fuzz Tests ============

    function testFuzzStake(uint256 amount) public {
        vm.assume(amount > 0 && amount <= 10000 * 10 ** 18);

        lotryToken.mint(user1, amount);

        vm.startPrank(user1);
        lotryToken.approve(address(staking), amount);
        staking.stake(amount);
        vm.stopPrank();

        assertEq(staking.getStakeAmount(user1), amount);
        assertEq(staking.totalStaked(), amount);
    }

    function testFuzzMultipleStakes(uint256 amount1, uint256 amount2) public {
        vm.assume(amount1 > 0 && amount1 <= 5000 * 10 ** 18);
        vm.assume(amount2 > 0 && amount2 <= 5000 * 10 ** 18);

        lotryToken.mint(user1, amount1 + amount2);

        vm.startPrank(user1);
        lotryToken.approve(address(staking), amount1 + amount2);
        staking.stake(amount1);
        staking.stake(amount2);
        vm.stopPrank();

        assertEq(staking.getStakeAmount(user1), amount1 + amount2);
        assertEq(staking.totalStaked(), amount1 + amount2);
    }

    // ============ Edge Cases ============

    function testMinimumStake() public {
        vm.startPrank(user1);
        lotryToken.approve(address(staking), 1);
        staking.stake(1);
        vm.stopPrank();

        assertEq(staking.getStakeAmount(user1), 1);
        assertEq(staking.totalStaked(), 1);
    }

    function testLargeStake() public {
        uint256 largeAmount = 100000 * 10 ** 18;
        lotryToken.mint(user1, largeAmount);

        vm.startPrank(user1);
        lotryToken.approve(address(staking), largeAmount);
        staking.stake(largeAmount);
        vm.stopPrank();

        assertEq(staking.getStakeAmount(user1), largeAmount);
        assertEq(staking.totalStaked(), largeAmount);
    }

    function testTokensTransferredToContract() public {
        uint256 balanceBefore = lotryToken.balanceOf(address(staking));

        vm.startPrank(user1);
        lotryToken.approve(address(staking), STAKE_AMOUNT);
        staking.stake(STAKE_AMOUNT);
        vm.stopPrank();

        uint256 balanceAfter = lotryToken.balanceOf(address(staking));
        assertEq(balanceAfter - balanceBefore, STAKE_AMOUNT);
    }

    function testUserBalanceDecreasedAfterStake() public {
        uint256 balanceBefore = lotryToken.balanceOf(user1);

        vm.startPrank(user1);
        lotryToken.approve(address(staking), STAKE_AMOUNT);
        staking.stake(STAKE_AMOUNT);
        vm.stopPrank();

        uint256 balanceAfter = lotryToken.balanceOf(user1);
        assertEq(balanceBefore - balanceAfter, STAKE_AMOUNT);
    }
}
