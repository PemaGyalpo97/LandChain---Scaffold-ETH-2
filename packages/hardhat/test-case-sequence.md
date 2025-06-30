1. Setup Phase (Deploy Contracts)

// Deploy contracts in this order:
1. LandRegistry landRegistry = new LandRegistry(deployerAddress);
2. VerifiersAndApprovers verifiers = new VerifiersAndApprovers();
3. LandNFT landNFT = new LandNFT(address(landRegistry));
4. EscrowVerification escrow = new EscrowVerification(address(landNFT), address(verifiers));

2. Verifier Setup (VerifiersAndApprovers.sol)

// Add verifiers (call as contract owner)
1. verifiers.addBankVerifier(bankVerifierAddress);
2. verifiers.addCourtVerifier(courtVerifierAddress);
3. verifiers.addTaxVerifier(taxVerifierAddress);

// Sample data:
- bankVerifierAddress = 0x123...;
- courtVerifierAddress = 0x456...;
- taxVerifierAddress = 0x789...;

3. Land Registration (LandRegistry.sol)

// Register a new land parcel (call as approver)
1. landRegistry.registerLand(
   "THRAM-001",                // thramNumber
   "PLOT-001",                 // plotNumber
   "Bhutan, Thimphu",          // location
   2,                          // acres
   50,                         // decimals
   [ownerAddress],             // owners
   ["did:owner:123"],          // DIDs
   [10000],                    // percentages (100% in basis points)
   OwnershipType.SINGLE        // ownershipType
);

// Verify the land
2. landRegistry.verifyLand("THRAM-001", "PLOT-001");

// Sample data:
- ownerAddress = 0xABC...;

4. Mint Land NFT (LandNFT.sol)

// Mint a plot NFT (call as contract owner)
1. landNFT.mintPlotToken(
   "PLOT-001",                 // plotNumber
   [ownerAddress],             // owners
   ["did:owner:123"],          // DIDs
   [10000]                     // percentages
);

// Sample tokenId generated: 1

5. Verification Process (VerifiersAndApprovers.sol)

// Bank verification (call as bank verifier)
1. verifiers.verifyBankStatus(1); // tokenId

// Court verification (call as court verifier)
2. verifiers.verifyCourtStatus(1); // tokenId

// Tax verification (call as tax verifier)
3. verifiers.verifyTaxStatus(1); // tokenId

// Check verification status (should return true)
4. verifiers.isLandVerified(1); // tokenId

6. Escrow Process (EscrowVerification.sol)

// Seller lists land for sale
1. escrow.listLandForSale(
   1,                          // tokenId
   1 ether                     // price
);

// Owner verifies sale details
2. escrow.verifyLandDetails(1); // tokenId

// Buyer makes payment (send 1 ETH with transaction)
3. escrow.makePayment{value: 1 ether}(1); // tokenId

// Finalize transfer (can be called by anyone)
4. escrow.transferOwnershipAfterPayment(1); // tokenId

// Seller withdraws funds
5. escrow.withdraw(); // called by seller

7. Cancellation Test (Optional)

// Seller cancels before payment
1. escrow.listLandForSale(1, 1 ether);
2. escrow.cancelSale(1); // called by seller