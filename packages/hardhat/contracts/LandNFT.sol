// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title LandNFT
/// @Author: Pema Gyalpo
/// @dev This contract represents the NFT for land sales.
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./LandRegistry.sol";
import "./OwnershipCheck.sol";

/// @dev This contract represents the NFT for land sales.
contract LandNFT is OwnershipCheck, Ownable {
    
    /// @dev Counter for generating unique token ids
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    LandRegistry public landRegistry;

    /// @dev Different types of land
    enum TokenType { THRAM, PLOT, FRACTION }

    /// @dev Owner information
    struct OwnerInfo {
        address ownerAddress;
        string userDid;
        uint256 ownershipPercentage;
    }

    /// @dev Land details
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

    /// @dev Mapping from tokenId to LandToken
    mapping(uint256 => LandToken) private _landTokens;
    mapping(string => uint256[]) private _tokenIdsByThram;
    mapping(string => uint256[]) private _tokenIdsByPlot;

    /// @dev Event emitted when a land token is created
    /// @param tokenId The unique id of the token
    /// @param tokenType The type of the token (thram, plot or fraction)
    /// @param thramNumber The thram number of the plot
    /// @param plotNumber The plot number of the land
    /// @param acres The area of the land in acres
    /// @param decimals The area of the land in decimal (after the decimal point)
    /// @param owners The owners of the land
    /// @param ownershipPercentages The percentage of each owner
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

    /// @dev Constructor for LandNFT
    constructor(address _landRegistry) OwnershipCheck("LandNFT", "LNFT") {
        landRegistry = LandRegistry(_landRegistry);
    }

    /// @dev Function to mint a thram token
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

    /// @dev Function to mint a plot token
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

    /// @dev Function to mint a fraction token
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

    /// @dev Function to mint a token
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

    /// @dev Function to get token details
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

    /// @dev Function to get tokens by thram
    function getTokensByThram(string memory _thramNumber) public view returns (uint256[] memory) {
        return _tokenIdsByThram[_thramNumber];
    }

    /// @dev Function to get tokens by plot
    function getTokensByPlot(string memory _plotNumber) public view returns (uint256[] memory) {
        return _tokenIdsByPlot[_plotNumber];
    }
}
