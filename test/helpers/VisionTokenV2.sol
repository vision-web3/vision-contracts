// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.28;

import {VisionToken} from "../../src/VisionToken.sol";

contract VisionTokenV2 is VisionToken {
    // keccak256(abi.encode(uint256(keccak256("visiontokenv2.contract.storage")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant VISION_TOKEN_STORAGE_LOCATION_V2 =
        0x55383d0c2c06045e94739c641239b8027cc9d06eb0101eec082de54741c70100;

    /// @notice Extra role for managing the new elements in V2.
    bytes32 public constant EXTRA_ROLE = keccak256("EXTRA_ROLE");

    struct VisionTokenStorageV2 {
        string _extraStr;
        uint256 _extraUint;
        bool _extraBool;
        address _extraAddress;
        address[] _extraArray;
    }

    /**
     * @dev Returns a pointer to the VisionTokenStorageV2 using inline assembly for optimized access.
     * This usage is safe and necessary for accessing namespaced storage in upgradeable contracts.
     */
    // slither-disable-next-line assembly
    function visionTokenStorageV2() private pure returns (VisionTokenStorageV2 storage vts) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            vts.slot := VISION_TOKEN_STORAGE_LOCATION_V2
        }
    }

    /**
     * @dev Initializes the new storage fields in the upgrade.
     * Can only be called once for this version (reinitializer).
     */
    function initializeV2(
        string memory extraStr,
        uint256 extraUint,
        bool extraBool,
        address extraAddress,
        address[] calldata extraArray
    ) public reinitializer(2) {
        VisionTokenStorageV2 storage pts = visionTokenStorageV2();
        pts._extraStr = extraStr;
        pts._extraUint = extraUint;
        pts._extraBool = extraBool;
        pts._extraAddress = extraAddress;

        // Initialize the array
        for (uint256 i = 0; i < extraArray.length; i++) {
            pts._extraArray.push(extraArray[i]);
        }
    }

    // --- Setters ---
    function setExtraStr(string memory newExtraStr) external onlyRole(EXTRA_ROLE) {
        VisionTokenStorageV2 storage pts = visionTokenStorageV2();
        pts._extraStr = newExtraStr;
    }

    function setExtraUint(uint256 newExtraUint) external onlyRole(EXTRA_ROLE) {
        VisionTokenStorageV2 storage pts = visionTokenStorageV2();
        pts._extraUint = newExtraUint;
    }

    function setExtraBool(bool newExtraBool) external onlyRole(EXTRA_ROLE) {
        VisionTokenStorageV2 storage pts = visionTokenStorageV2();
        pts._extraBool = newExtraBool;
    }

    function setExtraAddress(address newExtraAddress) external onlyRole(EXTRA_ROLE) {
        VisionTokenStorageV2 storage pts = visionTokenStorageV2();
        pts._extraAddress = newExtraAddress;
    }

    function setExtraArray(address[] calldata extraArray) external onlyRole(EXTRA_ROLE) {
        VisionTokenStorageV2 storage pts = visionTokenStorageV2();
        pts._extraArray = extraArray;
    }

    // --- Getters ---

    function getExtraStr() external view returns (string memory) {
        VisionTokenStorageV2 storage pts = visionTokenStorageV2();
        return pts._extraStr;
    }

    function getExtraUint() external view returns (uint256) {
        VisionTokenStorageV2 storage pts = visionTokenStorageV2();
        return pts._extraUint;
    }

    function getExtraBool() external view returns (bool) {
        VisionTokenStorageV2 storage pts = visionTokenStorageV2();
        return pts._extraBool;
    }

    function getExtraAddress() external view returns (address) {
        VisionTokenStorageV2 storage pts = visionTokenStorageV2();
        return pts._extraAddress;
    }

    function getExtraArray() external view returns (address[] memory) {
        VisionTokenStorageV2 storage pts = visionTokenStorageV2();
        return pts._extraArray;
    }
}
