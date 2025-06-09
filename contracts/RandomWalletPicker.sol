// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract RandomWalletPicker is VRFConsumerBaseV2Plus {
    // Chainlink VRF Configuration
    bytes32 immutable i_keyHash;
    uint256 immutable i_subscriptionId;
    uint32 public i_callbackGasLimit = 200000;
    uint16 public i_requestConfirmations = 3;
    uint32 public i_numWords = 1;

    // Request state
    bool public s_requestInProgress;
    uint256 public s_lastRequestId;

    // Data for the current/last request
    address payable[] public s_participants;
    uint256[] public s_stakes;
    uint256 public s_totalStakes;

    // Result variables
    uint256 public s_randomWord;
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
        i_keyHash = _keyHash;
        i_subscriptionId = _subscriptionId;
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
        require(!s_requestInProgress, "A request is already in progress");
        require(_newParticipants.length > 0, "No participants provided");
        require(
            _newParticipants.length == _newStakes.length,
            "Participants and stakes must have the same length"
        );

        s_requestInProgress = true;

        delete s_participants;
        delete s_stakes;

        uint256 totalStakes = 0;
        for (uint i = 0; i < _newParticipants.length; i++) {
            require(_newStakes[i] > 0, "Stake must be positive");
            s_participants.push(_newParticipants[i]);
            s_stakes.push(_newStakes[i]);
            totalStakes += _newStakes[i];
        }
        require(totalStakes > 0, "Total stakes must be positive");
        s_totalStakes = totalStakes;

        VRFV2PlusClient.RandomWordsRequest memory req = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_keyHash,
            subId: i_subscriptionId,
            requestConfirmations: i_requestConfirmations,
            callbackGasLimit: i_callbackGasLimit,
            numWords: i_numWords,
            extraArgs: VRFV2PlusClient._argsToBytes(
                VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
            )
        });

        requestId = s_vrfCoordinator.requestRandomWords(req);

        s_lastRequestId = requestId;
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
        require(requestId == s_lastRequestId, "Invalid request ID");
        require(randomWords.length > 0, "No random words returned");
        require(s_participants.length > 0, "No participants for this request");

        s_randomWord = randomWords[0];
        uint256 randomNumber = s_randomWord % s_totalStakes;

        uint256 cumulativeStakes = 0;
        address payable winner;
        for (uint i = 0; i < s_participants.length; i++) {
            cumulativeStakes += s_stakes[i];
            if (randomNumber < cumulativeStakes) {
                winner = s_participants[i];
                break;
            }
        }

        pickedWallet = winner;
        s_requestInProgress = false;

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
        return s_participants;
    }

    /**
     * @notice Gets all stored stakes for the last request.
     * @return An array of participant stakes.
     */
    function getAllStakes() public view returns (uint256[] memory) {
        return s_stakes;
    }

    /**
     * @notice Gets the VRF configuration parameters.
     * @return VRF coordinator address, subscription ID, and key hash
     */
    function getVrfParams() external view returns (address, uint256, bytes32) {
        return (address(s_vrfCoordinator), i_subscriptionId, i_keyHash);
    }

    // --- Admin Functions ---

    /**
     * @notice Sets the callback gas limit.
     * @param _newCallbackGasLimit The new gas limit for the callback.
     */
    function setCallbackGasLimit(uint32 _newCallbackGasLimit) public onlyOwner {
        i_callbackGasLimit = _newCallbackGasLimit;
    }

    /**
     * @notice Sets the request confirmations.
     * @param _newRequestConfirmations The new number of confirmations to wait for.
     */
    function setRequestConfirmations(uint16 _newRequestConfirmations)
        public
        onlyOwner
    {
        i_requestConfirmations = _newRequestConfirmations;
    }

    /**
     * @notice Sets the number of random words to request.
     * @param _newNumWords The new number of random words.
     */
    function setNumWords(uint32 _newNumWords) public onlyOwner {
        i_numWords = _newNumWords;
    }

    // Fallback function to receive ETH
    receive() external payable {}
}
