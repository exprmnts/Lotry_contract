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
 * @title Lotry Token Launchpad
 * @author @lotrydotfun
 * @notice This contract is for deploying a Lotry Token.
 */
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {LotryTicket} from "./LotryTicket.sol";

contract LotryLaunch is Ownable {
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

    function launchToken(string calldata name, string calldata symbol) public returns (address) {
        LotryTicket newToken = new LotryTicket(name, symbol, msg.sender);

        address tokenAddress = address(newToken);

        emit TokenCreated(tokenAddress, msg.sender, tokenCount, block.timestamp, name, symbol);

        unchecked {
            ++tokenCount;
        }

        return tokenAddress;
    }
}
