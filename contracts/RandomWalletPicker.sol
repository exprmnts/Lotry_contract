// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/*
                            ⠀⠀⠀⠀⠀⠀⢀⣤⣿⣶⣄⠀⠀⠀⣀⡀⠀⠀⠀⠀ 
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

                    
                █   █▀█ ▀█▀ █▀█ █▄█   █▀█ █▀█ █▀█ ▀█▀ █▀█ █▀▀ █▀█ █
                █▄▄ █▄█  █  █▀▄  █    █▀▀ █▀▄ █▄█  █  █▄█ █▄▄ █▄█ █▄▄

*/

/**
 * @title Random Wallet Picker Contract
 * @author Arjun C, Aarone George
 * @notice This contract is for picking a random wallet based on stakes.
 * @dev This contract uses Chainlink VRF to generate a random number and pick a random ticket/token.
 */
contract RandomWalletPicker is VRFConsumerBaseV2Plus {
    // Chainlink VRF Configuration
    bytes32 immutable I_KEY_HASH;
    uint256 immutable I_SUBSCRIPTION_ID;
    uint32 public iCallbackGasLimit = 200000;
    uint16 public iRequestConfirmations = 3;
    uint32 public iNumWords = 1;

    // Request state
    bool public sRequestInProgress;
    uint256 public sLastRequestId;

    // Data for the current/last request
    address payable[] public sParticipants;
    uint256[] public sStakes;
    uint256 public sTotalStakes;

    // Result variables
    uint256 public sRandomWord;
    address payable public pickedWallet;

    // Events
    event WalletPicked(uint256 indexed requestId, address indexed winner);
    event RandomnessRequested(
        uint256 indexed requestId,
        address requester,
        uint256 totalStakes
    );

    /**
     * @param _vrfCoordinatorAddress VRF Coordinator address
     * @param _subscriptionId Your uint256 subscription ID from vrf.chain.link
     * @param _keyHash The gas lane key hash
     */
    constructor(
        address _vrfCoordinatorAddress,
        uint256 _subscriptionId,
        bytes32 _keyHash
    ) VRFConsumerBaseV2Plus(_vrfCoordinatorAddress) {
        I_KEY_HASH = _keyHash;
        I_SUBSCRIPTION_ID = _subscriptionId;
    }

    /**
     * @notice Requests randomness from Chainlink VRF to pick a wallet based on stakes.
     * @param _newParticipants An array of wallet addresses.
     * @param _newStakes An array of stakes (e.g., number of tokens) for each wallet.
     * @return requestId The ID of the VRF request.
     */
    function pickRandomWallet(
        address payable[] memory _newParticipants,
        uint256[] memory _newStakes
    ) public onlyOwner returns (uint256 requestId) {
        require(!sRequestInProgress, "A request is already in progress");
        require(_newParticipants.length > 0, "No participants provided");
        require(
            _newParticipants.length == _newStakes.length,
            "Participants and stakes must have the same length"
        );

        sRequestInProgress = true;

        delete sParticipants;
        delete sStakes;

        uint256 totalStakes = 0;
        for (uint i = 0; i < _newParticipants.length; i++) {
            require(_newStakes[i] > 0, "Stake must be positive");
            sParticipants.push(_newParticipants[i]);
            sStakes.push(_newStakes[i]);
            totalStakes += _newStakes[i];
        }
        require(totalStakes > 0, "Total stakes must be positive");
        sTotalStakes = totalStakes;

        VRFV2PlusClient.RandomWordsRequest memory req = VRFV2PlusClient
            .RandomWordsRequest({
                keyHash: I_KEY_HASH,
                subId: I_SUBSCRIPTION_ID,
                requestConfirmations: iRequestConfirmations,
                callbackGasLimit: iCallbackGasLimit,
                numWords: iNumWords,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: true})
                )
            });

        requestId = s_vrfCoordinator.requestRandomWords(req);

        sLastRequestId = requestId;
        emit RandomnessRequested(requestId, msg.sender, totalStakes);
        return requestId;
    }

    /**
     * @notice Callback function used by VRF Coordinator to return the random number.
     * @param requestId The ID of the request.
     * @param randomWords The array of random numbers provided by the oracle.
     */
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {
        require(requestId == sLastRequestId, "Invalid request ID");
        require(randomWords.length > 0, "No random words returned");
        require(sParticipants.length > 0, "No participants for this request");

        sRandomWord = randomWords[0];
        uint256 randomNumber = sRandomWord % sTotalStakes;

        uint256 cumulativeStakes = 0;
        address payable winner;
        for (uint i = 0; i < sParticipants.length; i++) {
            cumulativeStakes += sStakes[i];
            if (randomNumber < cumulativeStakes) {
                winner = sParticipants[i];
                break;
            }
        }

        pickedWallet = winner;
        sRequestInProgress = false;

        emit WalletPicked(requestId, pickedWallet);
    }

    // --- Getter Functions ---

    /**
     * @notice Gets the last picked wallet address.
     * @return The address of the last picked wallet.
     */
    function getPickedWallet() public view returns (address payable) {
        return pickedWallet;
    }

    /**
     * @notice Gets all stored participants for the last request.
     * @return An array of participant addresses.
     */
    function getAllParticipants()
        public
        view
        returns (address payable[] memory)
    {
        return sParticipants;
    }

    /**
     * @notice Gets all stored stakes for the last request.
     * @return An array of participant stakes.
     */
    function getAllStakes() public view returns (uint256[] memory) {
        return sStakes;
    }

    /**
     * @notice Gets the VRF configuration parameters.
     * @return VRF coordinator address, subscription ID, and key hash
     */
    function getVrfParams() external view returns (address, uint256, bytes32) {
        return (address(s_vrfCoordinator), I_SUBSCRIPTION_ID, I_KEY_HASH);
    }

    // --- Admin Functions ---

    /**
     * @notice Sets the callback gas limit.
     * @param _newCallbackGasLimit The new gas limit for the callback.
     */
    function setCallbackGasLimit(uint32 _newCallbackGasLimit) public onlyOwner {
        iCallbackGasLimit = _newCallbackGasLimit;
    }

    /**
     * @notice Sets the request confirmations.
     * @param _newRequestConfirmations The new number of confirmations to wait for.
     */
    function setRequestConfirmations(
        uint16 _newRequestConfirmations
    ) public onlyOwner {
        iRequestConfirmations = _newRequestConfirmations;
    }

    /**
     * @notice Sets the number of random words to request.
     * @param _newNumWords The new number of random words.
     */
    function setNumWords(uint32 _newNumWords) public onlyOwner {
        iNumWords = _newNumWords;
    }

    // Fallback function to receive ETH
    receive() external payable {}
}
