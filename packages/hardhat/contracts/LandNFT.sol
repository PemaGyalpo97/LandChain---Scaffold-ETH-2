// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./LandRegistry.sol";

contract LandNFT is ERC721, ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    LandRegistry public landRegistry;

    enum TokenType { THRAM, PLOT, FRACTION }
    
    struct LandToken {
        uint256 tokenId;
        TokenType tokenType;
        string thramNumber;
        string plotNumber;
        uint256 acres;
        uint256 decimals;
        address[] owners;
        uint256 creationTime;
    }

    mapping(uint256 => LandToken) public landTokens;
    mapping(string => uint256[]) public tokenIdsByThram;
    mapping(string => uint256[]) public tokenIdsByPlot;

    event LandTokenized(
        uint256 indexed tokenId,
        TokenType tokenType,
        string thramNumber,
        string plotNumber,
        uint256 acres,
        uint256 decimals,
        address[] owners
    );

    constructor(address _landRegistry) ERC721("LandNFT", "LNFT") {
        landRegistry = LandRegistry(_landRegistry);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function mintThramToken(string memory _thramNumber, address[] memory _owners) public onlyOwner {
        LandRegistry.LandDetails[] memory parcels = landRegistry.getPlotsByThramNumber(_thramNumber);
        require(parcels.length > 0, "No parcels found for this thram");

        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();
        
        LandToken memory newToken = LandToken({
            tokenId: tokenId,
            tokenType: TokenType.THRAM,
            thramNumber: _thramNumber,
            plotNumber: "",
            acres: 0,
            decimals: 0,
            owners: _owners,
            creationTime: block.timestamp
        });

        _mintToken(tokenId, newToken, _owners);
        tokenIdsByThram[_thramNumber].push(tokenId);
    }

    function mintPlotToken(string memory _plotNumber, address[] memory _owners) public onlyOwner {
        LandRegistry.LandDetails memory parcel = landRegistry.getLandByPlotNumber(_plotNumber);
        require(parcel.landOwnerAddress != address(0), "Plot not found");

        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();
        
        LandToken memory newToken = LandToken({
            tokenId: tokenId,
            tokenType: TokenType.PLOT,
            thramNumber: parcel.thramNumber,
            plotNumber: _plotNumber,
            acres: parcel.totalAreaInAcre,
            decimals: parcel.totalAreaInDecimal,
            owners: _owners,
            creationTime: block.timestamp
        });

        _mintToken(tokenId, newToken, _owners);
        tokenIdsByPlot[_plotNumber].push(tokenId);
    }

    function mintFractionToken(
        string memory _plotNumber,
        uint256 _acres,
        uint256 _decimals,
        address[] memory _owners
    ) public onlyOwner {
        LandRegistry.LandDetails memory parcel = landRegistry.getLandByPlotNumber(_plotNumber);
        require(parcel.landOwnerAddress != address(0), "Plot not found");
        require(
            _acres <= parcel.availableAreaInAcre && 
            _decimals <= parcel.availableAreaInDecimal,
            "Fraction exceeds available area"
        );

        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();
        
        LandToken memory newToken = LandToken({
            tokenId: tokenId,
            tokenType: TokenType.FRACTION,
            thramNumber: parcel.thramNumber,
            plotNumber: _plotNumber,
            acres: _acres,
            decimals: _decimals,
            owners: _owners,
            creationTime: block.timestamp
        });

        _mintToken(tokenId, newToken, _owners);
        tokenIdsByPlot[_plotNumber].push(tokenId);
        
        landRegistry.fractionalizeLand(_plotNumber, _acres, _decimals);
    }

    function _mintToken(uint256 tokenId, LandToken memory tokenData, address[] memory owners) private {
        landTokens[tokenId] = tokenData;
        _safeMint(owners[0], tokenId);
        emit LandTokenized(
            tokenId,
            tokenData.tokenType,
            tokenData.thramNumber,
            tokenData.plotNumber,
            tokenData.acres,
            tokenData.decimals,
            owners
        );
    }

    function addJointOwner(uint256 tokenId, address newOwner) public {
        require(_isApprovedOrOwner(msg.sender, tokenId), "Caller is not owner nor approved");
        landTokens[tokenId].owners.push(newOwner);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
        delete landTokens[tokenId];
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function getTokensByThram(string memory _thramNumber) public view returns (LandToken[] memory) {
        uint256[] memory ids = tokenIdsByThram[_thramNumber];
        LandToken[] memory tokens = new LandToken[](ids.length);
        
        for (uint256 i = 0; i < ids.length; i++) {
            tokens[i] = landTokens[ids[i]];
        }
        return tokens;
    }

    function getTokensByPlot(string memory _plotNumber) public view returns (LandToken[] memory) {
        uint256[] memory ids = tokenIdsByPlot[_plotNumber];
        LandToken[] memory tokens = new LandToken[](ids.length);
        
        for (uint256 i = 0; i < ids.length; i++) {
            tokens[i] = landTokens[ids[i]];
        }
        return tokens;
    }
}