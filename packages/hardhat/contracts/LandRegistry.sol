// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract LandRegistry is Ownable {
    enum OwnershipType { SINGLE, JOINT, HOUSEHOLD_HEAD }

    struct OwnerInfo {
        address ownerAddress;
        string userDid;
        uint256 ownershipPercentage;
    }

    struct LandDetails {
        OwnerInfo[] owners;
        string thramNumber;
        string plotNumber;
        string location;
        uint256 totalAreaInAcre;
        uint256 totalAreaInDecimal;
        uint256 availableAreaInAcre;
        uint256 availableAreaInDecimal;
        uint256 timestamp;
        bool isVerified;
        OwnershipType ownershipType;
    }

    struct BasicLandInfo {
        string thramNumber;
        string plotNumber;
        string location;
        uint256 totalAreaInAcre;
        uint256 totalAreaInDecimal;
        uint256 availableAreaInAcre;
        uint256 availableAreaInDecimal;
        uint256 timestamp;
        bool isVerified;
        OwnershipType ownershipType;
    }

    address public immutable approver;
    uint256 public totalLandsRegistered;

    mapping(string => LandDetails[]) public landsByThramNumber;
    mapping(string => LandDetails) public landsByPlotNumber;
    mapping(address => LandDetails[]) public landsByOwner;
    mapping(string => LandDetails[]) public landsByUserDid;

    event LandRegistered(
        string indexed thramNumber,
        string indexed plotNumber,
        address[] owners,
        string[] userDids,
        uint256 totalAreaInAcre,
        uint256 totalAreaInDecimal,
        OwnershipType ownershipType
    );

    event LandVerified(string indexed thramNumber, string indexed plotNumber);
    event LandFractionalized(string indexed plotNumber, uint256 acres, uint256 decimals);

    modifier onlyApprover() {
        require(msg.sender == approver, "Caller is not the approver");
        _;
    }

    constructor(address _approver) {
        require(_approver != address(0), "Invalid approver address");
        approver = _approver;
    }

    function registerLand(
        string memory _thramNumber,
        string memory _plotNumber,
        string memory _location,
        uint256 _areaInAcre,
        uint256 _areaInDecimal,
        address[] memory _landOwnerAddresses,
        string[] memory _userDids,
        uint256[] memory _ownershipPercentages,
        OwnershipType _ownershipType
    ) public onlyApprover {
        require(_landOwnerAddresses.length == _userDids.length, "Addresses and DIDs length mismatch");
        require(_landOwnerAddresses.length == _ownershipPercentages.length, "Addresses and percentages length mismatch");
        require(_landOwnerAddresses.length > 0, "At least one owner required");
        require(bytes(_thramNumber).length > 0, "Thram number cannot be empty");
        require(bytes(_plotNumber).length > 0, "Plot number cannot be empty");
        require(_areaInAcre > 0 || _areaInDecimal > 0, "Area must be greater than zero");
        require(landsByPlotNumber[_plotNumber].owners.length == 0, "Plot number already registered");

        uint256 totalPercentage;
        for (uint i = 0; i < _ownershipPercentages.length; i++) {
            require(_landOwnerAddresses[i] != address(0), "Invalid owner address");
            require(bytes(_userDids[i]).length > 0, "User DID cannot be empty");
            totalPercentage += _ownershipPercentages[i];
        }
        require(totalPercentage == 10000, "Ownership percentages must sum to 100%");

        LandDetails storage newLand = landsByPlotNumber[_plotNumber];

        newLand.thramNumber = _thramNumber;
        newLand.plotNumber = _plotNumber;
        newLand.location = _location;
        newLand.totalAreaInAcre = _areaInAcre;
        newLand.totalAreaInDecimal = _areaInDecimal;
        newLand.availableAreaInAcre = _areaInAcre;
        newLand.availableAreaInDecimal = _areaInDecimal;
        newLand.timestamp = block.timestamp;
        newLand.isVerified = false;
        newLand.ownershipType = _ownershipType;

        for (uint i = 0; i < _landOwnerAddresses.length; i++) {
            newLand.owners.push(OwnerInfo({
                ownerAddress: _landOwnerAddresses[i],
                userDid: _userDids[i],
                ownershipPercentage: _ownershipPercentages[i]
            }));
        }

        landsByThramNumber[_thramNumber].push(newLand);

        for (uint i = 0; i < _landOwnerAddresses.length; i++) {
            landsByOwner[_landOwnerAddresses[i]].push(newLand);
            landsByUserDid[_userDids[i]].push(newLand);
        }

        totalLandsRegistered++;

        emit LandRegistered(
            _thramNumber,
            _plotNumber,
            _landOwnerAddresses,
            _userDids,
            _areaInAcre,
            _areaInDecimal,
            _ownershipType
        );
    }

    function getPlotsByThramNumber(string memory _thramNumber) public view returns (LandDetails[] memory) {
        return landsByThramNumber[_thramNumber];
    }

    function getLandOwnersByPlotNumber(string memory _plotNumber) public view returns (
        address[] memory ownerAddresses,
        string[] memory userDids
    ) {
        LandDetails storage land = landsByPlotNumber[_plotNumber];
        require(land.owners.length > 0, "Land not found");

        ownerAddresses = new address[](land.owners.length);
        userDids = new string[](land.owners.length);

        for (uint i = 0; i < land.owners.length; i++) {
            ownerAddresses[i] = land.owners[i].ownerAddress;
            userDids[i] = land.owners[i].userDid;
        }
    }

    function getLandInfoByPlotNumber(string memory _plotNumber) public view returns (BasicLandInfo memory) {
        LandDetails storage land = landsByPlotNumber[_plotNumber];
        require(land.owners.length > 0, "Land not found");

        return BasicLandInfo({
            thramNumber: land.thramNumber,
            plotNumber: land.plotNumber,
            location: land.location,
            totalAreaInAcre: land.totalAreaInAcre,
            totalAreaInDecimal: land.totalAreaInDecimal,
            availableAreaInAcre: land.availableAreaInAcre,
            availableAreaInDecimal: land.availableAreaInDecimal,
            timestamp: land.timestamp,
            isVerified: land.isVerified,
            ownershipType: land.ownershipType
        });
    }

    function getLandByPlotNumber(string memory _plotNumber) public view returns (LandDetails memory) {
        LandDetails storage land = landsByPlotNumber[_plotNumber];
        require(land.owners.length > 0, "Land not found");
        return land;
    }

    function verifyLand(string memory _thramNumber, string memory _plotNumber) public onlyApprover {
        LandDetails storage land = landsByPlotNumber[_plotNumber];
        require(land.owners.length > 0, "Land not found");
        require(keccak256(bytes(land.thramNumber)) == keccak256(bytes(_thramNumber)),
            "Plot doesn't belong to this thram");

        land.isVerified = true;
        emit LandVerified(_thramNumber, _plotNumber);
    }

    function fractionalizeLand(
        string memory _plotNumber,
        uint256 _acresToFractionalize,
        uint256 _decimalsToFractionalize
    ) public onlyApprover {
        LandDetails storage land = landsByPlotNumber[_plotNumber];
        require(land.owners.length > 0, "Land not found");
        require(
            _acresToFractionalize <= land.availableAreaInAcre &&
            _decimalsToFractionalize <= land.availableAreaInDecimal,
            "Cannot fractionalize more than available"
        );

        land.availableAreaInAcre -= _acresToFractionalize;
        land.availableAreaInDecimal -= _decimalsToFractionalize;
        emit LandFractionalized(_plotNumber, _acresToFractionalize, _decimalsToFractionalize);
    }
}