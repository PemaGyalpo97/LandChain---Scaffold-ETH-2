// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./VerifiersAndApprovers.sol";

/**
 * @title VerifierSetup
 * @dev Contract to manage the setup of verifiers for the land registry.
 */
contract VerifierSetup {
    // The VerifiersAndApprovers contract
    VerifiersAndApprovers public verifiersContract;

    // The owner of the contract
    address public owner;

    // Enum for the different types of verifiers
    enum VerifierType { BANK, COURT, TAX }

    // Event emitted when a verifier is added
    event VerifierAdded(address indexed verifier, VerifierType vType);

    // Event emitted when a verifier is removed
    event VerifierRemoved(address indexed verifier, VerifierType vType);

    // Event emitted when ownership of the contract is transferred
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Modifier to restrict access to the owner of the contract.
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    /**
     * @dev Constructor to initialize the contract.
     * @param _verifiersContract The address of the VerifiersAndApprovers contract.
     */
    constructor(address _verifiersContract) {
        require(_verifiersContract != address(0), "Invalid verifiers contract address");
        owner = msg.sender;
        verifiersContract = VerifiersAndApprovers(_verifiersContract);
        
        // Verify ownership of the verifiers contract
        try verifiersContract.owner() returns (address currentOwner) {
            require(currentOwner == msg.sender, "Deployer must own VerifiersAndApprovers contract");
        } catch {
            revert("Verifiers contract ownership check failed");
        }
    }

    /**
     * @dev Transfers ownership of the contract to a new owner.
     * @param newOwner The address of the new owner.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "New owner is the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
    
    /**
     * @dev Adds a list of verifiers to the contract.
     * @param verifiers The list of verifiers to add.
     * @param vTypes The list of types for the verifiers.
     */
    function batchAddVerifiers(
        address[] calldata verifiers, 
        VerifierType[] calldata vTypes
    ) external onlyOwner {
        require(verifiers.length == vTypes.length, "Array length mismatch");
        
        for (uint i = 0; i < verifiers.length; i++) {
            _addVerifier(verifiers[i], vTypes[i]);
        }
    }

    /**
     * @dev Removes a list of verifiers from the contract.
     * @param verifiers The list of verifiers to remove.
     * @param vTypes The list of types for the verifiers.
     */
    function batchRemoveVerifiers(
        address[] calldata verifiers, 
        VerifierType[] calldata vTypes
    ) external onlyOwner {
        require(verifiers.length == vTypes.length, "Array length mismatch");
        
        for (uint i = 0; i < verifiers.length; i++) {
            _removeVerifier(verifiers[i], vTypes[i]);
        }
    }

    /**
     * @dev Adds a single verifier to the contract.
     * @param verifier The address of the verifier to add.
     * @param vType The type of the verifier.
     */
    function _addVerifier(address verifier, VerifierType vType) internal {
        require(verifier != address(0), "Invalid verifier address");

        if (vType == VerifierType.BANK) {
            verifiersContract.addBankVerifier(verifier);
        } else if (vType == VerifierType.COURT) {
            verifiersContract.addCourtVerifier(verifier);
        } else if (vType == VerifierType.TAX) {
            verifiersContract.addTaxVerifier(verifier);
        }

        emit VerifierAdded(verifier, vType);
    }

    /**
     * @dev Removes a single verifier from the contract.
     * @param verifier The address of the verifier to remove.
     * @param vType The type of the verifier.
     */
    function _removeVerifier(address verifier, VerifierType vType) internal {
        if (vType == VerifierType.BANK) {
            verifiersContract.removeBankVerifier(verifier);
        } else if (vType == VerifierType.COURT) {
            verifiersContract.removeCourtVerifier(verifier);
        } else if (vType == VerifierType.TAX) {
            verifiersContract.removeTaxVerifier(verifier);
        }

        emit VerifierRemoved(verifier, vType);
    }

    /**
     * @dev Transfers ownership of the VerifiersAndApprovers contract to a new owner.
     * @param newOwner The address of the new owner.
     */
    function transferVerifiersOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner address");
        verifiersContract.transferOwnership(newOwner);
    }
}
