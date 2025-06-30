// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./VerifiersAndApprovers.sol";

contract EscrowVerification is Ownable, ReentrancyGuard {
    enum SaleStatus { NOT_FOR_SALE, PENDING_VERIFICATION, VERIFIED, PAYMENT_COMPLETE }

    struct LandSale {
        address seller;
        address buyer;
        uint256 price;
        SaleStatus status;
        bool paymentStatus;
        uint256 tokenId;
    }

    IERC721 public landNFT;
    VerifiersAndApprovers public verifiersContract;

    mapping(uint256 => LandSale) public landSales;
    mapping(address => uint256) public pendingWithdrawals;

    event LandListedForSale(uint256 indexed tokenId, address seller, uint256 price);
    event LandVerifiedForSale(uint256 indexed tokenId);
    event PaymentMade(uint256 indexed tokenId, address buyer, uint256 amount);
    event OwnershipTransferred(uint256 indexed tokenId, address from, address to);
    event Withdrawn(address indexed payee, uint256 amount);

    constructor(address _landNFT, address _verifiersContract) {
        landNFT = IERC721(_landNFT);
        verifiersContract = VerifiersAndApprovers(_verifiersContract);
    }

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

    function verifyLandDetails(uint256 _tokenId) external onlyOwner {
        require(landSales[_tokenId].status == SaleStatus.PENDING_VERIFICATION, "Not pending verification");
        landSales[_tokenId].status = SaleStatus.VERIFIED;
        emit LandVerifiedForSale(_tokenId);
    }

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

    function transferOwnershipAfterPayment(uint256 _tokenId) external nonReentrant {
        LandSale storage sale = landSales[_tokenId];
        require(sale.status == SaleStatus.PAYMENT_COMPLETE, "Payment not complete");
        require(sale.paymentStatus, "Payment not verified");

        landNFT.safeTransferFrom(sale.seller, sale.buyer, _tokenId);
        emit OwnershipTransferred(_tokenId, sale.seller, sale.buyer);

        // Reset sale status
        delete landSales[_tokenId];
    }

    function withdraw() external nonReentrant {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "No funds to withdraw");

        pendingWithdrawals[msg.sender] = 0;
        payable(msg.sender).transfer(amount);

        emit Withdrawn(msg.sender, amount);
    }

    function cancelSale(uint256 _tokenId) external {
        require(landSales[_tokenId].seller == msg.sender, "Not the seller");
        require(landSales[_tokenId].status != SaleStatus.PAYMENT_COMPLETE, "Sale already completed");

        delete landSales[_tokenId];
    }
}