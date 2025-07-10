// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {VisionToken} from "../src/VisionToken.sol";
import {BaseScript} from "./BaseScript.s.sol";

contract UpgradeVisionToken is BaseScript {
    string public constant ACCOUNTS_PATH = "./ACCOUNTS.json";
    string public constant UPGRADE_ADDRESSES_PATH = "./UPGRADE_ADDRESSES.json";

    /**
     * @notice Deploys a new VisionToken logic (implementation) contract.
     * @dev This function can be called by any account capable of paying gas.
     *      It broadcasts the deployment transaction and saves the deployed
     *      logic contract address to `UPGRADE_ADDRESSES.json` under the key `payment-token-logic`.
     *
     *      Example CLI usage:
     *      forge script UpgradeVisionToken --rpc-url local \
     *        --sig "deployNewVisionTokenLogic()" \
     *        --account local_deployer --broadcast -vvvv
     */
    function deployNewVisionTokenLogic() public {
        vm.startBroadcast();
        VisionToken logic = new VisionToken();
        vm.stopBroadcast();

        // Store the contract address at UPGRADE_ADDRESSES_PATH
        string memory data;
        data = vm.serializeAddress(data, "vision-token-logic", address(logic));
        vm.writeJson(data, UPGRADE_ADDRESSES_PATH);
    }

    /**
     * @notice Simulates an upgrade of a VisionToken proxy to a new logic contract.
     * @dev Reads account roles from ACCOUNTS.json, performs an upgrade via `upgradeToAndCall`
     *      using the upgrader address, then validates the upgraded token state.
     *
     *      Example usage:
     *      forge script UpgradeVisionToken --rpc-url local \
     *        --sig "simulateUpgrade(address,address)" \
     *        0xProxyAddress 0xNewLogicAddress -vv
     *
     * @param proxyAddress The address of the VisionToken proxy contract.
     * @param newLogicAddress The address of the new VisionToken implementation contract.
     *
     * @notice This function is intended to simulate the effect of upgrading a proxy
     *         to a newly deployed logic contract. It helps verify correctness before a real upgrade.
     *         Can only be broadcasted if Foundry holds the keystore for the upgrader address,
     *         typically in local or test deployments.
     */
    function simulateUpgrade(address proxyAddress, address newLogicAddress) external {
        // Reading accounts from accounts json file to run checks
        readAccounts(ACCOUNTS_PATH);

        // Start the broadcast for deploying contracts
        vm.startBroadcast(accounts["upgrader"]);

        VisionToken newLogic = VisionToken(newLogicAddress);

        // Prepare the call data for initializing new functionality if needed
        bytes memory data = ""; // If no new storage added, keep it empty string

        VisionToken proxy = VisionToken(proxyAddress);

        // Perform the upgrade and call
        proxy.upgradeToAndCall(address(newLogic), data);

        // wrap proxy into VisionToken for easy access
        VisionToken token = VisionToken(address(proxy));

        // Stop broadcasting
        vm.stopBroadcast();

        logTokenDetails(token);
        checkTokenState(token, newLogic);
    }
}
