// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.29;

import "@openzeppelin-contracts-5.4.0/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin-contracts-5.4.0/token/ERC20/IERC20.sol";
import "@openzeppelin-contracts-5.4.0/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-contracts-5.4.0/access/Ownable.sol";
import "@kei-fi-aave-v3-origin-1.0.0/core/contracts/interfaces/IPoolAddressesProvider.sol";
import "@kei-fi-aave-v3-origin-1.0.0/core/contracts/interfaces/IPool.sol";

contract VaultForBadDebts is ERC4626, Ownable
{	
	using SafeERC20 for IERC20;
	
	IPoolAddressesProvider public badDebtPoolAddressesProvider;
	IPoolAddressesProvider public poolAddressesProvider;

	address[] public reserves;

	constructor(IERC20 _asset) ERC4626(_asset) ERC20("Bad Debt Workout Vault", "BDWV") Ownable(msg.sender)
	{
		
	}

	function init(address _badDebtPoolAddressesProvider, address _poolAddressesProvider) external onlyOwner
	{
		badDebtPoolAddressesProvider = IPoolAddressesProvider(_badDebtPoolAddressesProvider);
		poolAddressesProvider = IPoolAddressesProvider(_poolAddressesProvider);
	}

	function addReserve(address[] calldata _reserves) external onlyOwner
	{
		for (uint256 i = 0; i < _reserves.length; i++)
		{
			reserves.push(_reserves[i]);
		}
	}

	function rebalance(int256[] calldata values) external onlyOwner
	{
		require(values.length == reserves.length, "Invalid values length");

		IPool badDebtPool = IPool(badDebtPoolAddressesProvider.getPool());
		IPool pool = IPool(poolAddressesProvider.getPool());

		for (uint256 i = 0; i < values.length; i++)
		{
			if (values[i] != 0)
			{
				if (values[i] > 0)
				{
					badDebtPool.borrow(reserves[i], uint256(values[i]), 2, 0, address(this));
					IERC20(reserves[i]).safeIncreaseAllowance(address(pool), uint256(values[i]));
					pool.supply(reserves[i], uint256(values[i]), address(this), 0);
				}
				else
				{
					pool.withdraw(reserves[i], uint256(-values[i]), address(this));
					IERC20(reserves[i]).safeIncreaseAllowance(address(badDebtPool), uint256(-values[i]));
					badDebtPool.repay(reserves[i], uint256(-values[i]), 2, address(this));
				}
			}
		}
	}

	function swap(uint256[] calldata values) external onlyOwner
	{
		require(values.length == reserves.length, "Invalid values length");

		IPool pool = IPool(poolAddressesProvider.getPool());

		for (uint256 i = 0; i < values.length; i++)
		{
			if (values[i] != 0)
			{
				pool.withdraw(reserves[i], uint256(values[i]), address(this));
			}
		}
	}
}