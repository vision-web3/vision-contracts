// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {VisionToken} from "../src/VisionToken.sol";

import {BaseScript} from "./BaseScript.s.sol";

contract DeployVisionToken is BaseScript {
    string public constant ACCOUNTS_PATH = "./ACCOUNTS.json";
    string public constant ADDRESSES_PATH = "./ADDRESSES.json";

    /**
     * @notice Deploys and initializes a UUPS-upgradeable VisionToken via proxy.
     * @dev Reads roles from `./ACCOUNTS.json` and writes deployed addresses to `./ADDRESSES.json`.
     *
     * Accounts JSON must include: admin, pauser, minter, upgrader, treasury.
     * Stores to ADDRESSES.json: payment-token-logic, payment-token-proxy.
     *
     * Example CLI:
     * forge script DeployVisionToken --rpc-url <your_rpc> --account <your_account> --broadcast  -vvvv
     */
    function run() external {
        // Start the broadcast for deploying contracts
        vm.startBroadcast();

        // Reading accounts from accounts json file
        readAccounts(ACCOUNTS_PATH);

        // Step 1: Deploy the VisionToken implementation contract
        VisionToken logic = new VisionToken();

        // Step 2: Encode the initializer function call
        bytes memory initData = abi.encodeWithSelector(
            VisionToken.initialize.selector,
            VISION_TOKEN_SUPPLY,
            accounts["treasury"],
            accounts["admin"],
            accounts["pauser"],
            accounts["minter"],
            accounts["upgrader"]
        );

        // Step 3: Deploy the UUPS Proxy pointing to the implementation
        ERC1967Proxy proxy = new ERC1967Proxy(address(logic), initData);

        // wrap proxy into VisionToken for easy access
        VisionToken token = VisionToken(address(proxy));

        // Stop broadcasting
        vm.stopBroadcast();

        logTokenDetails(token);
        checkTokenState(token, logic);

        // Store the contract addresses at ADDRESSES_PATH
        string memory data;
        vm.serializeAddress(data, "vision-token-logic", address(logic));
        data = vm.serializeAddress(data, "vision-token-proxy", address(proxy));
        vm.writeJson(data, ADDRESSES_PATH);
    }
}
