// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./Pool.sol";

contract TokenLaunchpad is Ownable {

    uint256 public tokenCount;

    event TokenCreated(
        address indexed tokenAddress,
        address indexed creator,
        uint256 indexed tokenId,
        uint256 timestamp,
        string name,
        string symbol
    );

    constructor(address initialOwner) Ownable(initialOwner) {}

    // Function to create a new ERC20 token
    function launchToken(
        string calldata name,
        string calldata symbol
    ) public returns (address) {
        BondingCurvePool newToken = new BondingCurvePool(
            name,
            symbol,
            msg.sender
        );


        address tokenAddress = address(newToken);

        // Emit event about token creation
        emit TokenCreated(
            tokenAddress,
            msg.sender,
            tokenCount,
            block.timestamp,
            name,
            symbol
        );

        unchecked { ++tokenCount; }
        
        return tokenAddress;
    }

}
