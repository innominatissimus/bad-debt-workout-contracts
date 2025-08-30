// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.29;

import "@openzeppelin-contracts-5.4.0/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin-contracts-5.4.0/token/ERC20/IERC20.sol";

contract VaultForBadDebts is ERC4626
{
	constructor(IERC20 _asset) ERC4626(_asset) ERC20("Bad Debt Workout Vault", "BDWV")
	{
		
	}
}