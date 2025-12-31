// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MyMintableERC20 is ERC20, Ownable {
    constructor(string memory name, string memory symbol, address initialOwner)
        ERC20(name, symbol)
        Ownable(initialOwner)
    {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}

contract TokenGenerator is Script {
    function run() external {
        // Manually add wallet addresses here
        address[] memory wallets = new address[](3);
        // wallets[0] = 0xC8c6e80129C781A491998CAA84106ECa58b6f9a9;
        // wallets[1] = 0x77370Ed38142932f46CFD3147874bdCA88E0d609;
        // wallets[2] = 0x9dbbBfBb5e2b1b2C5754becECa4E1e473b852a65;
        // wallets[3] = 0xb78f711838EFEd4351a8F144057AC27023bE636C;


        vm.startBroadcast();

        // Deploy the mintable ERC20 token
        MyMintableERC20 token = new MyMintableERC20("Lothery", "LOTH", msg.sender);
        console2.log("MyMintableERC20 deployed at:", address(token));

        uint256 amountToMint = 100_000_000_000 * 10 ** 18; // 100 Billion tokens with 18 decimals

        for (uint256 i = 0; i < wallets.length; i++) {
            token.mint(wallets[i], amountToMint);
            console2.log("Minted", amountToMint, "tokens to", wallets[i]);
        }

        vm.stopBroadcast();
    }
}
