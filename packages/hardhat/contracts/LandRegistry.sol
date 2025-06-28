//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

contract LandRegistry {
    // State Variables
    address public immutable approver;
    address public immutable owner;
    
    // Define a struct to hold the land details
    struct LandDetails {
        address landOwnerAddress;
        string userDid;
        string thramNumber;
        string plotNumber;
        string location;
        uint256 totalAreaInAcre;
        uint256 totalAreaInDecimal;
        uint256 availableAreaInAcre;
        uint256 availableAreaInDecimal;
        uint256 timestamp;
        bool isVerified;
    }

    // Define mappings for efficient lookup
    mapping (string => LandDetails[]) public landsByThramNumber;
    mapping (string => LandDetails) public landsByPlotNumber;
    mapping (address => LandDetails[]) public landsByOwner;
    mapping (string => LandDetails[]) public landsByUserDid;

    // Events
    event LandRegistered(
        address indexed landOwnerAddress,
        string indexed userDid,
        string indexed thramNumber,
        string plotNumber,
        string location,
        uint256 totalAreaInAcre,
        uint256 totalAreaInDecimal,
        bool isVerified,
        uint256 timestamp
    );

    event LandVerified(string indexed thramNumber, string indexed plotNumber, bool isVerified);
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
        address _landOwnerAddress,
        string memory _userDid
    ) public onlyApprover {
        require(_landOwnerAddress != address(0), "Invalid owner address");
        require(bytes(_thramNumber).length > 0, "Thram number cannot be empty");
        require(bytes(_plotNumber).length > 0, "Plot number cannot be empty");
        require(bytes(_userDid).length > 0, "User DID cannot be empty");
        require(_areaInAcre > 0 || _areaInDecimal > 0, "Area must be greater than zero");
        require(landsByPlotNumber[_plotNumber].landOwnerAddress == address(0), "Plot number already registered");

        LandDetails memory newLand = LandDetails({
            landOwnerAddress: _landOwnerAddress,
            userDid: _userDid,
            thramNumber: _thramNumber,
            plotNumber: _plotNumber,
            location: _location,
            totalAreaInAcre: _areaInAcre,
            totalAreaInDecimal: _areaInDecimal,
            availableAreaInAcre: _areaInAcre,
            availableAreaInDecimal: _areaInDecimal,
            timestamp: block.timestamp,
            isVerified: false
        });

        // Store the land details in all mappings
        landsByThramNumber[_thramNumber].push(newLand);
        landsByPlotNumber[_plotNumber] = newLand;
        landsByOwner[_landOwnerAddress].push(newLand);
        landsByUserDid[_userDid].push(newLand);

        emit LandRegistered(
            _landOwnerAddress, 
            _userDid,
            _thramNumber, 
            _plotNumber, 
            _location, 
            _areaInAcre, 
            _areaInDecimal, 
            false, 
            block.timestamp
        );
    }

    function verifyLand(string memory _thramNumber, string memory _plotNumber) public onlyApprover {
        LandDetails storage landByPlot = landsByPlotNumber[_plotNumber];
        
        require(landByPlot.landOwnerAddress != address(0), "Land not found by plot number");
        require(keccak256(bytes(landByPlot.thramNumber)) == keccak256(bytes(_thramNumber)), 
            "Plot number doesn't belong to this thram");

        landByPlot.isVerified = true;
        
        // Update verification status in all mappings
        for (uint i = 0; i < landsByThramNumber[_thramNumber].length; i++) {
            if (keccak256(bytes(landsByThramNumber[_thramNumber][i].plotNumber)) == keccak256(bytes(_plotNumber))) {
                landsByThramNumber[_thramNumber][i].isVerified = true;
                break;
            }
        }
        
        emit LandVerified(_thramNumber, _plotNumber, true);
    }

    function fractionalizeLand(
        string memory _plotNumber,
        uint256 _acresToFractionalize,
        uint256 _decimalsToFractionalize
    ) public onlyApprover {
        LandDetails storage land = landsByPlotNumber[_plotNumber];
        require(land.landOwnerAddress != address(0), "Land not found");
        require(
            _acresToFractionalize <= land.availableAreaInAcre &&
            _decimalsToFractionalize <= land.availableAreaInDecimal,
            "Cannot fractionalize more than available"
        );

        land.availableAreaInAcre -= _acresToFractionalize;
        land.availableAreaInDecimal -= _decimalsToFractionalize;

        emit LandFractionalized(_plotNumber, _acresToFractionalize, _decimalsToFractionalize);
    }

    function getPlotsByThramNumber(string memory _thramNumber) public view returns (LandDetails[] memory) {
        require(landsByThramNumber[_thramNumber].length > 0, "No plots found for this thram number");
        return landsByThramNumber[_thramNumber];
    }

    function getLandByPlotNumber(string memory _plotNumber) public view returns (LandDetails memory) {
        LandDetails memory land = landsByPlotNumber[_plotNumber];
        require(land.landOwnerAddress != address(0), "Land not found");
        return land;
    }

    function getLandsByUserDid(string memory _userDid) public view returns (LandDetails[] memory) {
        require(bytes(_userDid).length > 0, "User DID cannot be empty");
        require(landsByUserDid[_userDid].length > 0, "No lands found for this user DID");
        return landsByUserDid[_userDid];
    }

    function getLandsByOwner(address _owner) public view returns (LandDetails[] memory) {
        return landsByOwner[_owner];
    }
}