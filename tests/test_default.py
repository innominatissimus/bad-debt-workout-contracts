from wake.testing import *
from pytypes.contracts.mocks.MockERC20 import MockERC20
from pytypes.contracts.VaultForBadDebts import VaultForBadDebts

# Print failing tx call trace
# def revert_handler(e: TransactionRevertedError):
# 	if e.tx is not None:
# 		print(e.tx.call_trace)


@chain.connect()
# @on_revert(revert_handler)
def test_default():
	# Deploy ERC20 token from OpenZeppelin for testing
	mock_token = MockERC20.deploy()
	
	# Deploy vault with ERC20 token as underlying asset
	vault = VaultForBadDebts.deploy(mock_token)
	
	# Verify vault deployment
	assert vault.asset() == mock_token.address
	assert vault.name() == "Bad Debt Workout Vault"
	assert vault.symbol() == "BDWV"
	assert vault.owner() == chain.accounts[0].address
	
	print(f"Vault deployed at: {vault}")
	print(f"ERC20 token deployed at: {mock_token}")
	print(f"Vault owner: {vault.owner()}")

	mock_token.approve(vault.address, 10**18)
	vault.deposit(10**18, chain.accounts[0].address)
	assert vault.balanceOf(chain.accounts[0].address) == 10**18

	vault.withdraw(10**18, chain.accounts[0].address, chain.accounts[0].address)
	assert vault.balanceOf(chain.accounts[0].address) == 0
	assert mock_token.balanceOf(chain.accounts[0].address) == 10**18