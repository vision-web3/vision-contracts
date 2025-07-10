// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.28;

import {ERC20} from "@solmate/contracts/tokens/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(uint8 decimals) ERC20("Mock Token", "MTK", decimals) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
