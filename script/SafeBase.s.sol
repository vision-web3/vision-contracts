// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.28;
// solhint-disable const-name-snakecase

import {Script} from "forge-std/Script.sol";
import {Safe} from "@safe/Safe.sol";

contract SafeBase is Script {
    string private constant _safeJsonName = "SAFE.json";
    string private constant _rootSerializer = "root";
    string private constant _nonceSerializer = "nonce";
    string private constant _ownersSerializer = "owners";
    string private constant _thresholdSerializer = "threshold";

    function writeSafeInfo(address safeAddress) public {
        string memory finalJson;

        Safe safe = Safe(payable(safeAddress)); // wrap proxy
        string memory safeJson;
        vm.serializeUintToHex(safeJson, _nonceSerializer, safe.nonce());
        vm.serializeAddress(safeJson, _ownersSerializer, safe.getOwners());
        safeJson = vm.serializeUintToHex(safeJson, _thresholdSerializer, safe.getThreshold());

        // Add Safe info item to root
        finalJson = vm.serializeString(_rootSerializer, vm.toString(safeAddress), safeJson);
        // Write the JSON data to a file
        vm.writeJson(finalJson, string.concat(_safeJsonName));
    }
}
