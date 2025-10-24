// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {LotryTicket} from "../contracts/LotryTicket.sol";

contract WhitelistTest is Test {
    LotryTicket public lotry;

    address owner = address(1);
    address user1 = address(2);
    address user2 = address(3);
    address user3 = address(4);

    function setUp() public {
        vm.startPrank(owner);
        lotry = new LotryTicket("Test Lotry", "TLOT", owner);
        vm.stopPrank();

        // Give test users some ETH
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);
    }

    function testWhitelistBuySuccess() public {
        // Add user1 to whitelist
        vm.prank(owner);
        lotry.addToWhitelist(user1);

        // User1 should be able to buy
        vm.prank(user1);
        lotry.buy{value: 0.1 ether}();

        assertTrue(lotry.balanceOf(user1) > 0, "User1 should have tokens");
    }

    function testWhitelistBuyFail() public {
        vm.prank(owner);
        lotry.toggleWhitelist(true);
        // User2 is NOT whitelisted

        // User2 should NOT be able to buy
        vm.prank(user2);
        vm.expectRevert("Not whitelisted");
        lotry.buy{value: 0.1 ether}();
    }

    function testWhitelistSellSuccess() public {
        // Add user1 to whitelist and let them buy
        vm.prank(owner);
        lotry.addToWhitelist(user1);

        vm.prank(user1);
        lotry.buy{value: 0.1 ether}();

        uint256 balance = lotry.balanceOf(user1);

        // User1 should be able to sell
        vm.prank(user1);
        lotry.sell(balance / 2);

        assertTrue(lotry.balanceOf(user1) < balance, "User1 should have less tokens after sell");
    }

    function testWhitelistToggle() public {
        // Disable whitelist
        vm.prank(owner);
        lotry.toggleWhitelist(false);

        // Now anyone can buy without being whitelisted
        vm.prank(user2);
        lotry.buy{value: 0.1 ether}();

        assertTrue(lotry.balanceOf(user2) > 0, "User2 should have tokens");
    }

    function testBatchWhitelist() public {
        address[] memory users = new address[](3);
        users[0] = user1;
        users[1] = user2;
        users[2] = user3;

        // Add multiple users at once
        vm.prank(owner);
        lotry.addToWhitelistBatch(users);

        // All should be whitelisted
        assertTrue(lotry.whitelist(user1), "User1 should be whitelisted");
        assertTrue(lotry.whitelist(user2), "User2 should be whitelisted");
        assertTrue(lotry.whitelist(user3), "User3 should be whitelisted");
    }

    function testRemoveFromWhitelist() public {
        // Add then remove
        vm.startPrank(owner);
        lotry.toggleWhitelist(true);
        lotry.addToWhitelist(user1);
        lotry.removeFromWhitelist(user1);
        vm.stopPrank();

        // User1 should NOT be able to buy
        vm.prank(user1);
        vm.expectRevert("Not whitelisted");
        lotry.buy{value: 0.1 ether}();
    }
}
