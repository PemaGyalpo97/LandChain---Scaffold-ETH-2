// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./VerifiersAndApprovers.sol";

contract VerifierSetup {
    VerifiersAndApprovers public verifiersContract;
    address public owner;

    enum VerifierType { BANK, COURT, TAX }

    event VerifierAdded(address indexed verifier, VerifierType vType);
    event VerifierRemoved(address indexed verifier, VerifierType vType);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

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

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "New owner is the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
    
    function batchAddVerifiers(
        address[] calldata verifiers, 
        VerifierType[] calldata vTypes
    ) external onlyOwner {
        require(verifiers.length == vTypes.length, "Array length mismatch");
        
        for (uint i = 0; i < verifiers.length; i++) {
            _addVerifier(verifiers[i], vTypes[i]);
        }
    }

    function batchRemoveVerifiers(
        address[] calldata verifiers, 
        VerifierType[] calldata vTypes
    ) external onlyOwner {
        require(verifiers.length == vTypes.length, "Array length mismatch");
        
        for (uint i = 0; i < verifiers.length; i++) {
            _removeVerifier(verifiers[i], vTypes[i]);
        }
    }

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

    function transferVerifiersOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner address");
        verifiersContract.transferOwnership(newOwner);
    }
}