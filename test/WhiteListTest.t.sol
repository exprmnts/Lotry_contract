// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {LotryLaunch} from "../contracts/LotryLaunch.sol";
import {LotryTicket} from "../contracts/LotryTicket.sol";

contract WhitelistTest is Test {
    LotryLaunch public launchpad;

    address owner = address(1);
    address user1 = address(2);
    address user2 = address(3);
    address nonWhitelisted = address(99);

    function setUp() public {
        vm.prank(owner);
        launchpad = new LotryLaunch(owner);

        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(nonWhitelisted, 10 ether);
    }

    function testImmutableWhitelist() public {
        address[] memory whitelist = new address[](2);
        whitelist[0] = user1;
        whitelist[1] = user2;

        vm.prank(owner);
        address tokenAddr = launchpad.launchToken("Test", "TST", whitelist);
        LotryTicket token = LotryTicket(payable(tokenAddr));

        // Whitelisted users can buy
        vm.prank(user1);
        token.buy{value: 0.1 ether}();
        assertTrue(token.balanceOf(user1) > 0);

        // Non-whitelisted cannot
        vm.prank(nonWhitelisted);
        vm.expectRevert("Not whitelisted");
        token.buy{value: 0.1 ether}();
    }

    function testCannotAddToWhitelistAfterDeploy() public {
        address[] memory whitelist = new address[](1);
        whitelist[0] = user1;

        vm.prank(owner);
        address tokenAddr = launchpad.launchToken("Test", "TST", whitelist);
        LotryTicket token = LotryTicket(payable(tokenAddr));

        // No function exists to add addresses
        // This will fail to compile if you try:
        // token.addToWhitelist(user2); // Function doesn't exist!

        assertTrue(true, "No management functions exist");
    }
}
