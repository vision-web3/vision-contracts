// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// solhint-disable no-console
import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";

import {VanillaERC20} from "../test/helpers/VanillaERC20.sol";

contract DeployVanillaERC20Token is Script {
    /**
     * @notice Deploys VanillaERC20 for test purpose.
     * @dev
     * Example CLI:
     * forge script DeployVanillaERC20Token --rpc-url <your_rpc> --account <your_account> --broadcast \
     *   -vvvv --sig "run(string,string,uint8,uint256,address)" <name> <symbol> <decimals> <initialSupply> <recipient>
     */
    function run(string memory name, string memory symbol, uint8 decimals, uint256 initialSupply, address recipient)
        external
    {
        // Start the broadcast for deploying contracts
        vm.startBroadcast();

        VanillaERC20 token = new VanillaERC20(name, symbol, decimals, initialSupply, recipient);

        // Stop broadcasting
        vm.stopBroadcast();

        // Log the deployed contract accounts
        console.log("Token at:", address(token));
        console.log("name:", token.name());
        console.log("symbol:", token.symbol());
        console.log("decimals:", token.decimals());
        console.log("totalSupply:", token.totalSupply());
    }
}
