//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "hardhat/console.sol";

contract LandRegistry {
    // State Variables
    address public immutable approver;
    
    // Define a struct to hold the land details
    struct LandDetails {
        address landOwnerAddress;
        string userDid;
        string thramNumber;
        string plotNumber;
        string location;
        uint256 areaInAcre;
        uint256 areaInDecimal;
        uint256 timestamp;
        bool isVerified;
    }

    // Define mappings for efficient lookup
    mapping (string => LandDetails[]) public landsByThramNumber; // Changed to array for one-to-many
    mapping (string => LandDetails) public landsByPlotNumber; // Plot numbers remain unique
    mapping (address => LandDetails[]) public landsByOwner;
    mapping (string => LandDetails[]) public landsByUserDid;

    // Events
    event LandRegistered(
        address indexed landOwnerAddress,
        string indexed userDid,
        string indexed thramNumber,
        string plotNumber,
        string location,
        uint256 areaInAcre,
        uint256 areaInDecimal,
        bool isVerified,
        uint256 timestamp
    );

    event LandVerified(string indexed thramNumber, string indexed plotNumber, bool isVerified);

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
        //require(_areaInAcre > 0 || _areaInDecimal > 0, "Area must be greater than zero");

        // Check if plot number already exists (plots must still be unique)
        require(
            landsByPlotNumber[_plotNumber].landOwnerAddress == address(0),
            "Plot number already registered"
        );

        LandDetails memory newLand = LandDetails({
            landOwnerAddress: _landOwnerAddress,
            userDid: _userDid,
            thramNumber: _thramNumber,
            plotNumber: _plotNumber,
            location: _location,
            areaInAcre: _areaInAcre,
            areaInDecimal: _areaInDecimal,
            timestamp: block.timestamp,
            isVerified: false
        });

        // Store the land details in all mappings
        landsByThramNumber[_thramNumber].push(newLand); // Add to thram array
        landsByPlotNumber[_plotNumber] = newLand; // Plot remains unique
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

        console.log("Land registered successfully to thram:", _thramNumber);
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

    function getPlotsByThramNumber(string memory _thramNumber) public view returns (LandDetails[] memory) {
        //require(bytes(_thramNumber).length > 0, "Thram number cannot be empty");
        require(landsByThramNumber[_thramNumber].length > 0, "No plots found for this thram number");
        return landsByThramNumber[_thramNumber];
    }

    function getLandByPlotNumber(string memory _plotNumber) public view returns (
        address, 
        string memory, 
        string memory, 
        string memory, 
        string memory, 
        uint256, 
        uint256,
        uint256,
        bool
    ) {
        LandDetails memory land = landsByPlotNumber[_plotNumber];
        require(land.landOwnerAddress != address(0), "Land not found");
        return (
            land.landOwnerAddress, 
            land.userDid,
            land.thramNumber, 
            land.plotNumber, 
            land.location, 
            land.areaInAcre, 
            land.areaInDecimal,
            land.timestamp,
            land.isVerified
        );
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