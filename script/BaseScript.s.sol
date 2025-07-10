// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// solhint-disable gas-custom-errors
// solhint-disable no-console
import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";

import {VisionToken} from "../src/VisionToken.sol";

contract BaseScript is Script {
    uint256 public constant VISION_TOKEN_DECIMALS = 18;
    uint256 public constant VISION_TOKEN_UNIT = 10 ** VISION_TOKEN_DECIMALS;
    uint256 public constant VISION_TOKEN_SUPPLY = 4_200_000_000 * VISION_TOKEN_UNIT;
    string private constant VISION_TOKEN_NAME = "Vision";
    string private constant VISION_TOKEN_SYMBOL = "VSN";

    // EIP-1967 implementation slot
    bytes32 internal constant ERC1967_IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    // addresses mapping from json file
    mapping(string => address) public accounts;

    // populates accounts mapping with addresses of all accounts from json
    function readAccounts(string memory path) public {
        string memory json = vm.readFile(path);
        string[] memory keys = vm.parseJsonKeys(json, "$");
        // adjust this if keys added/removed to json file
        require(keys.length == 5, "address json keys mismatch");

        for (uint256 i = 0; i < keys.length; i++) {
            address address_ = vm.parseJsonAddress(json, string.concat(".", keys[i]));
            accounts[keys[i]] = address_;
        }
    }

    function logTokenDetails(VisionToken token) public view {
        // reading implementation address directly from the storage slot of ERC1967Utils
        bytes32 raw = vm.load(address(token), ERC1967_IMPLEMENTATION_SLOT);
        address implementation = address(uint160(uint256(raw)));

        // Log the deployed contract accounts
        console.log("VisionToken implementation/logic at:", implementation);
        console.log("VisionToken proxy at:", address(token));
        console.log("name:", token.name());
        console.log("symbol:", token.symbol());
        console.log("decimals:", token.decimals());
        console.log("totalSupply:", token.totalSupply());

        // Roles values
        console.log(" -------- Roles values ------------");
        console.log("DEFAULT_ADMIN_ROLE:");
        console.logBytes32(token.DEFAULT_ADMIN_ROLE());

        console.log("PAUSER_ROLE: keccak256('PAUSER_ROLE')");
        console.logBytes32(token.PAUSER_ROLE());

        console.log("MINTER_ROLE: keccak256('MINTER_ROLE)");
        console.logBytes32(token.MINTER_ROLE());

        console.log("UPGRADER_ROLE: keccak256('UPGRADER_ROLE')");
        console.logBytes32(token.UPGRADER_ROLE());

        console.log(" -------- Roles assignment ------------");
        console.log("admin:", accounts["admin"], token.hasRole(token.DEFAULT_ADMIN_ROLE(), accounts["admin"]));
        console.log("pauser:", accounts["pauser"], token.hasRole(token.PAUSER_ROLE(), accounts["pauser"]));
        console.log("minter:", accounts["minter"], token.hasRole(token.MINTER_ROLE(), accounts["minter"]));
        console.log("upgrader:", accounts["upgrader"], token.hasRole(token.UPGRADER_ROLE(), accounts["upgrader"]));
    }

    function checkTokenState(VisionToken token, VisionToken logic) public view {
        // Load and verify implementation address from ERC1967 slot
        bytes32 raw = vm.load(address(token), ERC1967_IMPLEMENTATION_SLOT);
        address implementation = address(uint160(uint256(raw)));
        require(implementation == address(logic), "Implementation mismatch");

        // Basic metadata checks
        string memory name = token.name();
        string memory symbol = token.symbol();
        uint8 decimals = token.decimals();

        require(keccak256(bytes(name)) == keccak256(bytes(VISION_TOKEN_NAME)), "Token name mismatch");
        require(keccak256(bytes(symbol)) == keccak256(bytes(VISION_TOKEN_SYMBOL)), "Token symbol mismatch");

        require(decimals == VISION_TOKEN_DECIMALS, "Decimals mismatch");

        // Role hashes
        bytes32 defaultAdminRole = token.DEFAULT_ADMIN_ROLE();
        bytes32 pauserRole = token.PAUSER_ROLE();
        bytes32 minterRole = token.MINTER_ROLE();
        bytes32 upgraderRole = token.UPGRADER_ROLE();

        require(defaultAdminRole == 0x00, "DEFAULT_ADMIN_ROLE must be 0x00");
        require(pauserRole == keccak256("PAUSER_ROLE"), "PAUSER_ROLE mismatch");
        require(minterRole == keccak256("MINTER_ROLE"), "MINTER_ROLE mismatch");
        require(upgraderRole == keccak256("UPGRADER_ROLE"), "UPGRADER_ROLE mismatch");

        // Role assignment checks
        require(token.hasRole(defaultAdminRole, accounts["admin"]), "Admin missing DEFAULT_ADMIN_ROLE");
        require(token.hasRole(pauserRole, accounts["pauser"]), "Pauser missing PAUSER_ROLE");
        require(token.hasRole(minterRole, accounts["minter"]), "Minter missing MINTER_ROLE");
        require(token.hasRole(upgraderRole, accounts["upgrader"]), "Upgrader missing UPGRADER_ROLE");
        // solhint-disable-next-line reason-string
        console.log("checkTokenState successful for token/logic:", address(token), address(logic));
    }
}
