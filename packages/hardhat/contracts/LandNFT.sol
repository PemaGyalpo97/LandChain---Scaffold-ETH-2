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

    struct OwnerInfo {
        address ownerAddress;
        string userDid;
        uint256 ownershipPercentage;
    }

    struct LandToken {
        uint256 tokenId;
        TokenType tokenType;
        string thramNumber;
        string plotNumber;
        uint256 acres;
        uint256 decimals;
        OwnerInfo[] owners;
        uint256 creationTime;
    }

    mapping(uint256 => LandToken) private _landTokens;
    mapping(string => uint256[]) private _tokenIdsByThram;
    mapping(string => uint256[]) private _tokenIdsByPlot;

    event LandTokenized(
        uint256 indexed tokenId,
        TokenType tokenType,
        string thramNumber,
        string plotNumber,
        uint256 acres,
        uint256 decimals,
        address[] owners,
        uint256[] ownershipPercentages
    );

    constructor(address _landRegistry) ERC721("LandNFT", "LNFT") {
        landRegistry = LandRegistry(_landRegistry);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
        delete _landTokens[tokenId];
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function mintThramToken(
        string memory _thramNumber,
        address[] memory _owners,
        string[] memory _userDids,
        uint256[] memory _percentages
    ) public onlyOwner {
        LandRegistry.LandDetails[] memory parcels = landRegistry.getPlotsByThramNumber(_thramNumber);
        require(parcels.length > 0, "No parcels found for this thram");
        require(_owners.length == _userDids.length && _owners.length == _percentages.length, "Input arrays length mismatch");

        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();

        LandToken storage newToken = _landTokens[tokenId];
        newToken.tokenId = tokenId;
        newToken.tokenType = TokenType.THRAM;
        newToken.thramNumber = _thramNumber;
        newToken.plotNumber = "";
        newToken.acres = 0;
        newToken.decimals = 0;
        newToken.creationTime = block.timestamp;

        for (uint i = 0; i < _owners.length; i++) {
            newToken.owners.push(OwnerInfo({
                ownerAddress: _owners[i],
                userDid: _userDids[i],
                ownershipPercentage: _percentages[i]
            }));
        }

        _mintToken(tokenId, newToken);
        _tokenIdsByThram[_thramNumber].push(tokenId);
    }

    function mintPlotToken(
        string memory _plotNumber,
        address[] memory _owners,
        string[] memory _userDids,
        uint256[] memory _percentages
    ) public onlyOwner {
        require(_owners.length == _userDids.length && _owners.length == _percentages.length, "Input arrays length mismatch");

        LandRegistry.LandDetails memory land = landRegistry.getLandByPlotNumber(_plotNumber);
        require(land.owners.length > 0, "Plot not found");

        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();

        LandToken storage newToken = _landTokens[tokenId];
        newToken.tokenId = tokenId;
        newToken.tokenType = TokenType.PLOT;
        newToken.thramNumber = land.thramNumber;
        newToken.plotNumber = land.plotNumber;
        newToken.acres = land.totalAreaInAcre;
        newToken.decimals = land.totalAreaInDecimal;
        newToken.creationTime = block.timestamp;

        for (uint i = 0; i < _owners.length; i++) {
            newToken.owners.push(OwnerInfo({
                ownerAddress: _owners[i],
                userDid: _userDids[i],
                ownershipPercentage: _percentages[i]
            }));
        }

        _mintToken(tokenId, newToken);
        _tokenIdsByPlot[_plotNumber].push(tokenId);
    }

    function mintFractionToken(
        string memory _plotNumber,
        uint256 _acres,
        uint256 _decimals,
        address[] memory _owners,
        string[] memory _userDids,
        uint256[] memory _percentages
    ) public onlyOwner {
        require(_owners.length == _userDids.length && _owners.length == _percentages.length, "Input arrays length mismatch");

        LandRegistry.LandDetails memory land = landRegistry.getLandByPlotNumber(_plotNumber);
        require(land.owners.length > 0, "Plot not found");
        require(
            _acres <= land.availableAreaInAcre &&
            _decimals <= land.availableAreaInDecimal,
            "Fraction exceeds available area"
        );

        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();

        LandToken storage newToken = _landTokens[tokenId];
        newToken.tokenId = tokenId;
        newToken.tokenType = TokenType.FRACTION;
        newToken.thramNumber = land.thramNumber;
        newToken.plotNumber = land.plotNumber;
        newToken.acres = _acres;
        newToken.decimals = _decimals;
        newToken.creationTime = block.timestamp;

        for (uint i = 0; i < _owners.length; i++) {
            newToken.owners.push(OwnerInfo({
                ownerAddress: _owners[i],
                userDid: _userDids[i],
                ownershipPercentage: _percentages[i]
            }));
        }

        _mintToken(tokenId, newToken);
        _tokenIdsByPlot[_plotNumber].push(tokenId);

        landRegistry.fractionalizeLand(_plotNumber, _acres, _decimals);
    }

    function _mintToken(uint256 tokenId, LandToken storage tokenData) private {
        for (uint i = 0; i < tokenData.owners.length; i++) {
            _safeMint(tokenData.owners[i].ownerAddress, tokenId);
        }

        address[] memory owners = new address[](tokenData.owners.length);
        uint256[] memory percentages = new uint256[](tokenData.owners.length);
        for (uint i = 0; i < tokenData.owners.length; i++) {
            owners[i] = tokenData.owners[i].ownerAddress;
            percentages[i] = tokenData.owners[i].ownershipPercentage;
        }

        emit LandTokenized(
            tokenId,
            tokenData.tokenType,
            tokenData.thramNumber,
            tokenData.plotNumber,
            tokenData.acres,
            tokenData.decimals,
            owners,
            percentages
        );
    }

    function getToken(uint256 tokenId) public view returns (
        uint256,
        TokenType,
        string memory,
        string memory,
        uint256,
        uint256,
        address[] memory,
        string[] memory,
        uint256[] memory,
        uint256
    ) {
        LandToken storage token = _landTokens[tokenId];
        require(token.tokenId != 0, "Token does not exist");

        address[] memory owners = new address[](token.owners.length);
        string[] memory dids = new string[](token.owners.length);
        uint256[] memory percentages = new uint256[](token.owners.length);

        for (uint i = 0; i < token.owners.length; i++) {
            owners[i] = token.owners[i].ownerAddress;
            dids[i] = token.owners[i].userDid;
            percentages[i] = token.owners[i].ownershipPercentage;
        }

        return (
            token.tokenId,
            token.tokenType,
            token.thramNumber,
            token.plotNumber,
            token.acres,
            token.decimals,
            owners,
            dids,
            percentages,
            token.creationTime
        );
    }

    function getTokensByThram(string memory _thramNumber) public view returns (uint256[] memory) {
        return _tokenIdsByThram[_thramNumber];
    }

    function getTokensByPlot(string memory _plotNumber) public view returns (uint256[] memory) {
        return _tokenIdsByPlot[_plotNumber];
    }
}
