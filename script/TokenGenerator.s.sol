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
        address[] memory wallets = new address[](1);
        wallets[0] = 0xC8c6e80129C781A491998CAA84106ECa58b6f9a9;
        // wallets[1] = 0x77370Ed38142932f46CFD3147874bdCA88E0d609;
        // wallets[2] = 0x9dbbBfBb5e2b1b2C5754becECa4E1e473b852a65;
        // wallets[3] = 0xb78f711838EFEd4351a8F144057AC27023bE636C;
        // wallets[4] = 0x17983D2abF7B624592e35858482d2f77DE3EDE41;
        // wallets[5] = 0x8Df1Db579c6C66d0E2d5C9A32d8Cfdd30eDE7b50;
        // wallets[6] = 0xf724a560ef324981474C0aAB935A083Fda22D91C;
        // wallets[7] = 0xa28639d4C874D9b3f75031F7bfd20d223404c8C8;
        // wallets[8] = 0xd85395DEf3d633E786291bf9DE54d324eebC7917;
        // wallets[9] = 0x6Fd50cdB870061aAa07edD2b91b77FB148D0c686;
        // wallets[10] = 0x5219aDaEc7B1A0F374B564934918f0c52Bc793dB;
        // wallets[11] = 0xaEb38d671dD7Ed75aBc1C49Ca3215474F462d6c8;
        // wallets[12] = 0xc048B87bf6Affc0f8AF6f3ED8849c1b34bd75b74;
        // wallets[13] = 0x318DF9b6a66A6244cc13ea47e935769e3894Cd6c;
        // wallets[14] = 0x023Bac8f677A27278864B9b36E6b9E80616B4dd1;
        // wallets[15] = 0xb18c4Aa73D459Fb530b3c3c7e199c9dB81A4D68b;
        // wallets[16] = 0x0C82d6C3f6bEdFE87E7f90f357308E25b574b85b;
        // wallets[17] = 0x86596691C02a95bfE8a66E50fe808523A560250e;
        // wallets[18] = 0x3D7545966C6D26c3939e685d72Ec1bad7dC611a9;


        vm.startBroadcast();

        // Deploy the mintable ERC20 token
        MyMintableERC20 token = new MyMintableERC20("Lothery", "LTRY", msg.sender);
        console2.log("MyMintableERC20 deployed at:", address(token));

        uint256 amountToMint = 100_000_000_000 * 10 ** 18; // 100 Billion tokens with 18 decimals

        for (uint256 i = 0; i < wallets.length; i++) {
            token.mint(wallets[i], amountToMint);
            console2.log("Minted", amountToMint, "tokens to", wallets[i]);
        }

        vm.stopBroadcast();
    }
}
