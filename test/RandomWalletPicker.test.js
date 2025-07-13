const { expect } = require("chai");
const { ethers } = require("hardhat");

// Array of 10 mock wallet addresses for testing
const MOCK_WALLET_ADDRESSES = [
    "0x1111111111111111111111111111111111111111",
    "0x2222222222222222222222222222222222222222",
    "0x3333333333333333333333333333333333333333",
    "0x4444444444444444444444444444444444444444",
    "0x5555555555555555555555555555555555555555",
    "0x6666666666666666666666666666666666666666",
    "0x7777777777777777777777777777777777777777",
    "0x8888888888888888888888888888888888888888",
    "0x9999999999999999999999999999999999999999",
    "0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
];

// Corresponding stakes for each wallet (e.g., number of tickets)
const MOCK_STAKES = [10, 20, 5, 15, 30, 10, 5, 25, 50, 5]; // Sum = 175

const DEPLOYED_RANDOM_WALLET_PICKER_ADDRESS = "0xe33d4b25588614ef5d0ca49cd2e781e2dcbb9e19";

describe("RandomWalletPicker with Live VRF (Base Sepolia)", function () {
    let randomWalletPicker;
    let owner;

    beforeEach(async function () {
        if (
            DEPLOYED_RANDOM_WALLET_PICKER_ADDRESS ===
            "YOUR_DEPLOYED_RANDOM_WALLET_PICKER_ADDRESS_HERE"
        ) {
            this.skip(); // Skip tests if address is not set
        }
        [owner] = await ethers.getSigners();

        // Explicitly use the factory to attach to the deployed contract.
        // This is more robust and ensures the correct ABI is loaded for event parsing.
        const RandomWalletPickerFactory = await ethers.getContractFactory(
            "RandomWalletPicker",
            owner
        );
        randomWalletPicker = await RandomWalletPickerFactory.attach(
            DEPLOYED_RANDOM_WALLET_PICKER_ADDRESS
        );

        console.log(
            `Connected to RandomWalletPicker at: ${await randomWalletPicker.getAddress()}`
        );
        console.log(`Test signer (owner): ${owner.address}`);
        console.log("Ensure this signer is the owner of the deployed contract for owner-only functions.");
        console.log("Ensure the contract is correctly set up with Chainlink VRF on Base Sepolia and the subscription is funded.");
    });

    describe("Deployment (Querying existing contract)", function () {
        it("Should have the correct owner (ensure test signer is the contract owner)", async function () {
            expect(await randomWalletPicker.owner()).to.equal(owner.address);
        });

        it("Should be able to query the participants array", async function () {
            // This test just ensures we can call the getter. On a live contract, it may not be empty.
            const participants = await randomWalletPicker.getAllParticipants();
            expect(participants).to.be.an('array');
        });
    });

    describe("pickRandomWallet and fulfillRandomWords (Live VRF)", function () {
        it("Should pick a random wallet using live VRF and receive the callback", async function () {
            this.timeout(360000); // 6 minutes timeout for VRF callback

            const inProgress = await randomWalletPicker.s_requestInProgress();
            if (inProgress) {
                console.warn(
                    "WARNING: A request is already in progress. This test may fail if the contract is stuck."
                );
            }

            console.log(
                "\nAttempting to pick a random wallet with weighted stakes..."
            );
            console.log(
                "This will send a transaction and wait for the Chainlink VRF callback."
            );

            // Set up the listener for the WalletPicked event *before* sending the transaction
            const walletPickedPromise = new Promise((resolve, reject) => {
                randomWalletPicker.once(
                    "WalletPicked",
                    (eventRequestId, winnerAddress) => {
                        console.log("\nReceived a WalletPicked event.");
                        console.log(
                            `  --> Event Request ID: ${eventRequestId.toString()}`
                        );
                        console.log(
                            "  --> Picked Wallet Address from event:",
                            winnerAddress
                        );
                        resolve({ eventRequestId, winnerAddress });
                    }
                );
            });

            // Request randomness
            const tx = await randomWalletPicker.pickRandomWallet(
                MOCK_WALLET_ADDRESSES,
                MOCK_STAKES
            );
            console.log(
                `pickRandomWallet transaction sent: ${tx.hash}. Waiting for confirmation...`
            );
            const receipt = await tx.wait(1);
            console.log("pickRandomWallet transaction confirmed.");

            // Get our request ID using the robust queryFilter method.
            console.log(`Searching for RandomnessRequested event in block ${receipt.blockNumber}...`);
            
            // Query from the transaction's block to the latest block to account for RPC node delays.
            const eventFilter = randomWalletPicker.filters.RandomnessRequested();
            const events = await randomWalletPicker.queryFilter(eventFilter, receipt.blockNumber, 'latest');

            console.log(`Found ${events.length} RandomnessRequested event(s) since the transaction's block.`);
            if (events.length > 0) {
                console.log("--- Raw Event Data ---");
                // The event.args object from ethers contains BigInts for uint256 values.
                // JSON.stringify() cannot serialize BigInts, which was causing the test to crash.
                // We use a replacer function to convert BigInts to strings during serialization.
                const replacer = (key, value) => (typeof value === "bigint" ? value.toString() : value);
                events.forEach((event, index) => {
                    console.log(`Event[${index}]:`);
                    console.log(`  tx hash: ${event.transactionHash}`);
                    console.log(`  args: ${JSON.stringify(event.args, replacer)}`);
                });
                console.log("----------------------");
            }

            let ourRequestId;
            for (const event of events) {
                if (event.transactionHash.toLowerCase() === tx.hash.toLowerCase()) {
                    console.log("Matching event found!");
                    ourRequestId = event.args.requestId;
                    break;
                }
            }

            expect(ourRequestId, "Could not find ourRequestId from the RandomnessRequested event").to.not.be.undefined;

            console.log(
                `Randomness requested with our request ID: ${ourRequestId.toString()}`
            );
            console.log(
                "Waiting for Chainlink VRF to fulfill the request..."
            );
            console.log("(This might take a few minutes on Base Sepolia)");

            // Now, wait for the event we were listening for
            const { eventRequestId, winnerAddress } = await walletPickedPromise;

            // Check that the event we received matches our request
            expect(eventRequestId).to.equal(ourRequestId);
            console.log(
                "\nWalletPicked event is for the correct request ID!"
            );

            // Now perform all assertions
            expect(winnerAddress).to.be.properAddress;
            const lowerCaseMockWallets = MOCK_WALLET_ADDRESSES.map((addr) =>
                addr.toLowerCase()
            );
            expect(lowerCaseMockWallets).to.include(winnerAddress.toLowerCase());

            console.log(`Successfully picked wallet: ${winnerAddress}`);

            const storedRandomWord = await randomWalletPicker.s_randomWord();
            console.log(
                "Stored s_randomWord (from Chainlink VRF):",
                storedRandomWord.toString()
            );

            console.log("Verifying with getPickedWallet()...");
            const storedPickedWallet =
                await randomWalletPicker.getPickedWallet();
            expect(storedPickedWallet.toLowerCase()).to.equal(
                winnerAddress.toLowerCase()
            );
            console.log(`getPickedWallet() confirmed: ${storedPickedWallet}`);

            const requestInProgressAfter =
                await randomWalletPicker.s_requestInProgress();
            expect(requestInProgressAfter).to.be.false;
            console.log(
                "s_requestInProgress flag is correctly set to false after fulfillment."
            );
        });
    });
}); 