// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract VanillaERC20 is ERC20 {
    uint8 private immutable DECIMALS_;

    constructor(string memory name_, string memory symbol_, uint8 decimals_, uint256 initialSupply, address recipient)
        ERC20(name_, symbol_)
    {
        DECIMALS_ = decimals_;
        _mint(recipient, initialSupply);
    }

    function decimals() public view virtual override returns (uint8) {
        return DECIMALS_;
    }
}
