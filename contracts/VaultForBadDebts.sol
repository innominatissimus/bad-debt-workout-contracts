// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.29;

import "@openzeppelin-contracts-5.4.0/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin-contracts-5.4.0/token/ERC20/IERC20.sol";
import "@openzeppelin-contracts-5.4.0/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-contracts-5.4.0/access/Ownable.sol";
import "@kei-fi-aave-v3-origin-1.0.0/core/contracts/interfaces/IPoolAddressesProvider.sol";
import "@kei-fi-aave-v3-origin-1.0.0/core/contracts/interfaces/IPool.sol";
import "@uniswap-universal-router-2.0.0/contracts/interfaces/IUniversalRouter.sol";

contract VaultForBadDebts is ERC4626, Ownable
{	
	using SafeERC20 for IERC20;
	
	IPoolAddressesProvider public badDebtPoolAddressesProvider;
	IPoolAddressesProvider public poolAddressesProvider;
	IUniversalRouter public universalRouter;

	IERC20 public underlyingAssetOfAToken;

	address[] public reserves;

	constructor(IERC20 _asset) ERC4626(_asset) ERC20("Bad Debt Workout Vault", "BDWV") Ownable(msg.sender)
	{
		
	}

	function init(address _badDebtPoolAddressesProvider,
		address _poolAddressesProvider, 
		address _universalRouter,
		address _underlyingAssetOfAToken) external onlyOwner
	{
		badDebtPoolAddressesProvider = IPoolAddressesProvider(_badDebtPoolAddressesProvider);
		poolAddressesProvider = IPoolAddressesProvider(_poolAddressesProvider);
		universalRouter = IUniversalRouter(_universalRouter);
		underlyingAssetOfAToken = IERC20(_underlyingAssetOfAToken);
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
					uint256 withdrawn = pool.withdraw(reserves[i], uint256(-values[i]), address(this));
					IERC20(reserves[i]).safeIncreaseAllowance(address(badDebtPool), withdrawn);
					badDebtPool.repay(reserves[i], withdrawn, 2, address(this));
				}
			}
		}
	}

	function swap(uint256[] calldata values) external onlyOwner
	{
		require(values.length == reserves.length, "Invalid values length");

		IPool pool = IPool(poolAddressesProvider.getPool());
		IPool badDebtPool = IPool(badDebtPoolAddressesProvider.getPool());

		
		for (uint256 i = 0; i < values.length; i++)
		{
			if (values[i] != 0)
			{
				// Withdraw tokens from Aave pool
				uint256 withdrawn = pool.withdraw(reserves[i], uint256(values[i]), address(this));
				
				// Create path: reserves[i] -> (0.3% fee) -> underlyingAssetOfAToken
				bytes memory path = abi.encodePacked(
					reserves[i],           // tokenIn
					uint24(3000),         // 0.3% fee (3000 = 0.3%)
					address(underlyingAssetOfAToken)  // tokenOut
				);
				
				// Prepare Universal Router command
				bytes memory commands = abi.encodePacked(uint8(0x80)); // V3_SWAP_EXACT_IN and f == 1
				
				// Prepare input parameters for V3_SWAP_EXACT_IN
				bytes[] memory inputs = new bytes[](1);
				inputs[0] = abi.encode(
					address(this),	// recipient
					withdrawn,		// amountIn
					0,				// amountOutMinimum (0 for simplicity, should set proper slippage)
					path,			// path
					true			// payer
				);
				
				// Approve Universal Router to spend tokens
				IERC20(reserves[i]).safeIncreaseAllowance(address(universalRouter), withdrawn);
				
				// Execute swap through Universal Router
				universalRouter.execute(
					commands,
					inputs,
					block.timestamp
				);
			}
		}

		// Supply all received underlyingAssetOfAToken to bad debt pool
		uint256 balance = underlyingAssetOfAToken.balanceOf(address(this));
		underlyingAssetOfAToken.safeDecreaseAllowance(address(badDebtPool), balance);
		badDebtPool.supply(address(underlyingAssetOfAToken), balance, address(this), 0);
	}
}