// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

// import OpenZeppelin Contracts.
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

// import another help function
import "@openzeppelin/contracts/utils/Base64.sol";

import { StringUtils } from "./libraries/StringUtils.sol";
import "hardhat/console.sol";

contract Domains is ERC721URIStorage {
  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;

  // We'll be storing our NFT images on chain as SVGs
  string svgPartOne = '<svg width="512" height="512" viewBox="0 0 2500 2500" fill="none" xmlns="http://www.w3.org/2000/svg"><path fill="url(#a)" d="M0 0h2500v2500H0z"/><path d="M549.5 365.637V563.27a27.499 27.499 0 0 1-14.297 24.123L373.381 675.96a27.499 27.499 0 0 1-26.17.128l-166.179-88.864a27.5 27.5 0 0 1-14.532-24.25v-197.04a27.5 27.5 0 0 1 14.441-24.202l166.177-89.666a27.5 27.5 0 0 1 26.353.129l161.824 89.369a27.5 27.5 0 0 1 14.205 24.073Z" fill="#D9D9D9" fill-opacity=".05" stroke="#FFA629" stroke-width="35"/><defs><linearGradient id="a" x1="1250" y1="2500" x2="1250" y2="-72.5" gradientUnits="userSpaceOnUse"><stop stop-color="#F9941D"/><stop offset=".935" stop-color="#F19D3B" stop-opacity="0"/></linearGradient></defs><text x="999" y="2233" font-size="150" fill="#000" filter="url(#A)" font-family="Plus Jakarta Sans,DejaVu Sans,Noto Color Emoji,Apple Color Emoji,sans-serif" font-weight="bold">';
  string svgPartTwo = '</text></svg>';

  string public tld;
  mapping(string => address) public domains;
  mapping(string => string) public records;
  mapping (uint => string) public names;
  address payable public owner;

  error Unauthorized();
  error AlreadyRegistered();
  error InvalidName(string name);

 // We make the contract "payable" by adding this to the constructor
  constructor(string memory _tld) payable ERC721("Core Name Service", "CNS") {
    owner = payable(msg.sender);
    tld = _tld;
    console.log("%s name service deployed", _tld);
  }

  // This function will give us the price of a domain based on length
  function price(string calldata name) public pure returns(uint) {
    uint len = StringUtils.strlen(name);
    require(len > 0);
    if (len == 3) {
      return 5 * 10**16; // 5 MATIC = 5 000 000 000 000 000 000 (18 decimals). We're going with 0.5 Matic cause the faucets don't give a lot
    } else if (len == 4) {
      return 3 * 10**16; // To charge smaller amounts, reduce the decimals. This is 0.3
    } else {
      return 1 * 10**16;
    }
  }
  function register(string calldata name) public payable {
    require(domains[name] == address(0));

    uint256 _price = price(name);
    require(msg.value >= _price, "Not enough Matic paid");
    if (domains[name] != address(0)) revert AlreadyRegistered();
    if (!valid(name)) revert InvalidName(name);
    // Combine the name passed into the function  with the TLD
    string memory _name = string(abi.encodePacked(name, ".", tld));
    // Create the SVG (image) for the NFT with the name
    string memory finalSvg = string(abi.encodePacked(svgPartOne, _name, svgPartTwo));
    uint256 newRecordId = _tokenIds.current();
    uint256 length = StringUtils.strlen(name);
    string memory strLen = Strings.toString(length);

    console.log("Registering %s.%s on the contract with tokenID %d", name, tld, newRecordId);

    // Create the JSON metadata of our NFT. We do this by combining strings and encoding as base64
    string memory json = Base64.encode(
        abi.encodePacked(
            '{'
                '"name": "', _name,'", '
                '"description": "A domain on the Core name service", '
                '"image": "data:image/svg+xml;base64,', Base64.encode(bytes(finalSvg)), '", '
                '"length": "', strLen, '"'
            '}'
        )
    );

    string memory finalTokenUri = string( abi.encodePacked("data:application/json;base64,", json));

    console.log("\n--------------------------------------------------------");
    console.log("Final tokenURI", finalTokenUri);
    console.log("--------------------------------------------------------\n");

    _safeMint(msg.sender, newRecordId);
    _setTokenURI(newRecordId, finalTokenUri);
    domains[name] = msg.sender;
    names[newRecordId] = name;
    _tokenIds.increment();
  }

  function getAddress(string calldata name) public view returns (address) {
      return domains[name];
  }

  // fetch all domains
  function getAllNames() public view returns (string[] memory) {
    console.log("Getting all names from contract");
    string[] memory allNames = new string[](_tokenIds.current());
      for (uint i = 0; i < _tokenIds.current(); i++) {
    allNames[i] = names[i];
    console.log("Name for token %d is %s", i, allNames[i]);
  }

  return allNames;
  }

  function setRecord(string calldata name, string calldata record) public {
      // Check that the owner is the transaction sender
      require(domains[name] == msg.sender);
      if (msg.sender != domains[name]) revert Unauthorized();
      records[name] = record;
  }

  function getRecord(string calldata name) public view returns(string memory) {
      return records[name];
  }
  // check domin validity
  function valid(string calldata name) public pure returns(bool) {
      return StringUtils.strlen(name) >= 3 && StringUtils.strlen(name) <= 10;
  }

  modifier onlyOwner() {
       require(isOwner());
  _;
  }   

  function isOwner() public view returns (bool) {
       return msg.sender == owner;
  }

  function withdraw() public onlyOwner {
       uint amount = address(this).balance;
  
  (bool success, ) = msg.sender.call{value: amount}("");
  require(success, "Failed to withdraw Matic");
  } 
  
}