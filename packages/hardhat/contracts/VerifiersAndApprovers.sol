// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title VerifiersAndApprovers
 * @dev This contract manages the roles of verifiers and tracks the verification status of land tokens.
 */
contract VerifiersAndApprovers is Ownable {
    struct ApprovalStatus {
        bool bankStatus;
        bool courtStatus;
        bool taxStatus;
        bool isVerified;
    }

    // Mapping of verifier roles to their addresses
    mapping(address => bool) public bankVerifiers;
    mapping(address => bool) public courtVerifiers;
    mapping(address => bool) public taxVerifiers;
    
    // Mapping of each land token ID to its approval status
    mapping(uint256 => ApprovalStatus) public landApprovals;

    // Events for logging actions
    event BankVerified(uint256 indexed tokenId, address verifier);
    event CourtVerified(uint256 indexed tokenId, address verifier);
    event TaxVerified(uint256 indexed tokenId, address verifier);
    event LandFullyVerified(uint256 indexed tokenId);
    event VerifierAdded(address indexed verifier, string vType);
    event VerifierRemoved(address indexed verifier, string vType);

    // Modifiers for access control
    modifier onlyBankVerifier() {
        require(bankVerifiers[msg.sender], "Not authorized as bank verifier");
        _;
    }

    modifier onlyCourtVerifier() {
        require(courtVerifiers[msg.sender], "Not authorized as court verifier");
        _;
    }

    modifier onlyTaxVerifier() {
        require(taxVerifiers[msg.sender], "Not authorized as tax verifier");
        _;
    }

    /**
     * @dev Adds a bank verifier.
     * @param _verifier The address of the verifier to add.
     */
    function addBankVerifier(address _verifier) external onlyOwner {
        require(_verifier != address(0), "Invalid verifier address");
        require(!bankVerifiers[_verifier], "Already a bank verifier");
        bankVerifiers[_verifier] = true;
        emit VerifierAdded(_verifier, "BANK");
    }

    /**
     * @dev Removes a bank verifier.
     * @param _verifier The address of the verifier to remove.
     */
    function removeBankVerifier(address _verifier) external onlyOwner {
        require(bankVerifiers[_verifier], "Not a bank verifier");
        bankVerifiers[_verifier] = false;
        emit VerifierRemoved(_verifier, "BANK");
    }

    /**
     * @dev Adds a court verifier.
     * @param _verifier The address of the verifier to add.
     */
    function addCourtVerifier(address _verifier) external onlyOwner {
        require(_verifier != address(0), "Invalid verifier address");
        require(!courtVerifiers[_verifier], "Already a court verifier");
        courtVerifiers[_verifier] = true;
        emit VerifierAdded(_verifier, "COURT");
    }

    /**
     * @dev Removes a court verifier.
     * @param _verifier The address of the verifier to remove.
     */
    function removeCourtVerifier(address _verifier) external onlyOwner {
        require(courtVerifiers[_verifier], "Not a court verifier");
        courtVerifiers[_verifier] = false;
        emit VerifierRemoved(_verifier, "COURT");
    }

    /**
     * @dev Adds a tax verifier.
     * @param _verifier The address of the verifier to add.
     */
    function addTaxVerifier(address _verifier) external onlyOwner {
        require(_verifier != address(0), "Invalid verifier address");
        require(!taxVerifiers[_verifier], "Already a tax verifier");
        taxVerifiers[_verifier] = true;
        emit VerifierAdded(_verifier, "TAX");
    }

    /**
     * @dev Removes a tax verifier.
     * @param _verifier The address of the verifier to remove.
     */
    function removeTaxVerifier(address _verifier) external onlyOwner {
        require(taxVerifiers[_verifier], "Not a tax verifier");
        taxVerifiers[_verifier] = false;
        emit VerifierRemoved(_verifier, "TAX");
    }

    /**
     * @dev Sets the bank verification status for a land token.
     * @param _tokenId The ID of the token to verify.
     */
    function verifyBankStatus(uint256 _tokenId) external onlyBankVerifier {
        require(!landApprovals[_tokenId].bankStatus, "Bank already verified");
        landApprovals[_tokenId].bankStatus = true;
        emit BankVerified(_tokenId, msg.sender);
        _checkFullVerification(_tokenId);
    }

    /**
     * @dev Sets the court verification status for a land token.
     * @param _tokenId The ID of the token to verify.
     */
    function verifyCourtStatus(uint256 _tokenId) external onlyCourtVerifier {
        require(!landApprovals[_tokenId].courtStatus, "Court already verified");
        landApprovals[_tokenId].courtStatus = true;
        emit CourtVerified(_tokenId, msg.sender);
        _checkFullVerification(_tokenId);
    }

    /**
     * @dev Sets the tax verification status for a land token.
     * @param _tokenId The ID of the token to verify.
     */
    function verifyTaxStatus(uint256 _tokenId) external onlyTaxVerifier {
        require(!landApprovals[_tokenId].taxStatus, "Tax already verified");
        landApprovals[_tokenId].taxStatus = true;
        emit TaxVerified(_tokenId, msg.sender);
        _checkFullVerification(_tokenId);
    }

    /**
     * @dev Checks and sets the full verification status for a land token.
     * @param _tokenId The ID of the token to check.
     */
    function _checkFullVerification(uint256 _tokenId) private {
        ApprovalStatus storage status = landApprovals[_tokenId];
        if (status.bankStatus && status.courtStatus && status.taxStatus && !status.isVerified) {
            status.isVerified = true;
            emit LandFullyVerified(_tokenId);
        }
    }

    /**
     * @dev Returns the full verification status of a land token.
     * @param _tokenId The ID of the token to check.
     * @return bool indicating if the land is fully verified.
     */
    function isLandVerified(uint256 _tokenId) public view returns (bool) {
        return landApprovals[_tokenId].isVerified;
    }
}
