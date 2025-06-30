// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./VerifiersAndApprovers.sol";

/**
 * @title EscrowVerification
 * @dev This contract handles the verification and payment process for land sales.
 *      It uses the VerifiersAndApprovers contract to verify the land details.
 *      It uses the ReentrancyGuard to prevent reentrancy attacks.
 */
contract EscrowVerification is Ownable, ReentrancyGuard {
    /**
     * @dev Enum of the different sale statuses.
     */
    enum SaleStatus { NOT_FOR_SALE, PENDING_VERIFICATION, VERIFIED, PAYMENT_COMPLETE }

    /**
     * @dev Struct to store the land sale details.
     */
    struct LandSale {
        address seller;
        address buyer;
        uint256 price;
        SaleStatus status;
        bool paymentStatus;
        uint256 tokenId;
    }

    //* @dev The land NFT contract.
    IERC721 public landNFT;
    VerifiersAndApprovers public verifiersContract;

    /**
     * @dev Mapping of the land sale details.
     */
    mapping(uint256 => LandSale) public landSales;

    /**
     * @dev Mapping of the pending withdrawals.
     */
    mapping(address => uint256) public pendingWithdrawals;

    /**
     * @dev Event emitted when a land is listed for sale.
     */
    event LandListedForSale(uint256 indexed tokenId, address seller, uint256 price);

    /**
     * @dev Event emitted when a land is verified for sale.
     */
    event LandVerifiedForSale(uint256 indexed tokenId);

    /**
     * @dev Event emitted when a payment is made.
     */
    event PaymentMade(uint256 indexed tokenId, address buyer, uint256 amount);

    /**
     * @dev Event emitted when the ownership is transferred.
     */
    event OwnershipTransferred(uint256 indexed tokenId, address from, address to);

    /**
     * @dev Event emitted when a withdrawal is made.
     */
    event Withdrawn(address indexed payee, uint256 amount);

    /**
     * @dev Constructor to initialize the contract.
     * @param _landNFT The address of the land NFT contract.
     * @param _verifiersContract The address of the VerifiersAndApprovers contract.
     */
    constructor(address _landNFT, address _verifiersContract) {
        landNFT = IERC721(_landNFT);
        verifiersContract = VerifiersAndApprovers(_verifiersContract);
    }

    /**
     * @dev Function to list a land for sale.
     * @param _tokenId The token ID of the land.
     * @param _price The price of the land.
     */
    function listLandForSale(uint256 _tokenId, uint256 _price) external {
        require(landNFT.ownerOf(_tokenId) == msg.sender, "Not the owner");
        require(verifiersContract.isLandVerified(_tokenId), "Land not fully verified");
        require(landSales[_tokenId].status == SaleStatus.NOT_FOR_SALE, "Already listed");

        landSales[_tokenId] = LandSale({
            seller: msg.sender,
            buyer: address(0),
            price: _price,
            status: SaleStatus.PENDING_VERIFICATION,
            paymentStatus: false,
            tokenId: _tokenId
        });

        emit LandListedForSale(_tokenId, msg.sender, _price);
    }

    /**
     * @dev Function to verify the land details.
     * @param _tokenId The token ID of the land.
     */
    function verifyLandDetails(uint256 _tokenId) external onlyOwner {
        require(landSales[_tokenId].status == SaleStatus.PENDING_VERIFICATION, "Not pending verification");
        landSales[_tokenId].status = SaleStatus.VERIFIED;
        emit LandVerifiedForSale(_tokenId);
    }

    /**
     * @dev Function to make a payment.
     * @param _tokenId The token ID of the land.
     */
    function makePayment(uint256 _tokenId) external payable nonReentrant {
        LandSale storage sale = landSales[_tokenId];
        require(sale.status == SaleStatus.VERIFIED, "Land not verified for sale");
        require(msg.value == sale.price, "Incorrect payment amount");
        require(!sale.paymentStatus, "Payment already made");

        sale.buyer = msg.sender;
        sale.paymentStatus = true;
        sale.status = SaleStatus.PAYMENT_COMPLETE;
        pendingWithdrawals[sale.seller] += msg.value;

        emit PaymentMade(_tokenId, msg.sender, msg.value);
    }

    /**
     * @dev Function to transfer the ownership after payment.
     * @param _tokenId The token ID of the land.
     */
    function transferOwnershipAfterPayment(uint256 _tokenId) external nonReentrant {
        LandSale storage sale = landSales[_tokenId];
        require(sale.status == SaleStatus.PAYMENT_COMPLETE, "Payment not complete");
        require(sale.paymentStatus, "Payment not verified");

        landNFT.safeTransferFrom(sale.seller, sale.buyer, _tokenId);
        emit OwnershipTransferred(_tokenId, sale.seller, sale.buyer);

        // Reset sale status
        delete landSales[_tokenId];
    }

    /**
     * @dev Function to withdraw the funds.
     */
    function withdraw() external nonReentrant {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "No funds to withdraw");

        pendingWithdrawals[msg.sender] = 0;
        payable(msg.sender).transfer(amount);

        emit Withdrawn(msg.sender, amount);
    }

    /**
     * @dev Function to cancel a sale.
     * @param _tokenId The token ID of the land.
     */
    function cancelSale(uint256 _tokenId) external {
        require(landSales[_tokenId].seller == msg.sender, "Not the seller");
        require(landSales[_tokenId].status != SaleStatus.PAYMENT_COMPLETE, "Sale already completed");

        delete landSales[_tokenId];
    }
}
