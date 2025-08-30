// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.29;

import "@openzeppelin-contracts-5.4.0/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20
{
	constructor() ERC20("Mock", "MTK")
	{
		_mint(msg.sender, 1e18);
	}
}