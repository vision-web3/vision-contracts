// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.28;

/* solhint-disable no-console*/
import {console} from "forge-std/console.sol";
import {Safe} from "@safe/Safe.sol";
import {SafeProxyFactory} from "@safe/proxies/SafeProxyFactory.sol";
import {SafeProxy} from "@safe/proxies/SafeProxy.sol";

import {SafeBase} from "./SafeBase.s.sol";
/**
 * @title Deploy treasury contract
 *
 * @notice Deploy the gnosis safe that is the Vision treasury
 *
 * @dev Usage
 * Deploy by any gas paying account:
 * forge script ./script/TreasuryScript.s.sol --account <account> \
 *     --sender <sender> --rpc-url <rpc alias> --slow --force --sig \
 *     "deployTreasury(address[], uint256)" \
 *     <ownerAddresses> <threshold>
 */

contract TreasuryScript is SafeBase {
    function deployTreasury(address[] memory ownerAddresses, uint256 threshold) external {
        vm.startBroadcast();
        (Safe safeMasterCopy, SafeProxyFactory proxyFactory) = deploySafeInfrastracture();
        Safe treasury = deploySafe(proxyFactory, safeMasterCopy, 1, ownerAddresses, threshold);
        console.log("Treasury Safe deployed at:", address(treasury));
        vm.stopBroadcast();

        writeSafeInfo(address(treasury));
    }

    function deploySafeInfrastracture() private returns (Safe, SafeProxyFactory) {
        Safe safeMasterCopy = new Safe();
        console.log("Safe Master Copy deployed at:", address(safeMasterCopy));
        SafeProxyFactory proxyFactory = new SafeProxyFactory();
        console.log("Proxy Factory deployed at:", address(proxyFactory));

        return (safeMasterCopy, proxyFactory);
    }

    function deploySafe(
        SafeProxyFactory proxyFactory,
        Safe safeMasterCopy,
        uint256 saltNonce,
        address[] memory owners,
        uint256 threshold
    ) private returns (Safe) {
        bytes memory setupData = abi.encodeWithSignature(
            "setup(address[],uint256,address,bytes,address,address,uint256,address)",
            owners,
            threshold,
            address(0),
            "",
            address(0),
            address(0),
            0,
            address(0)
        );
        SafeProxy safeProxy =
            proxyFactory.createChainSpecificProxyWithNonce(address(safeMasterCopy), setupData, saltNonce);
        return Safe(payable(address(safeProxy)));
    }
}
