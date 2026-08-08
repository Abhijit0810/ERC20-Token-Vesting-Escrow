-include .env

.PHONY: all build test test-unit test-fuzz test-invariant gas-report clean deploy-token deploy-vesting configure-vesting demo-claim verify

FORGE := C:/Users/naika/.foundry/bin/forge.exe

all: build test

build:
	$(FORGE) build

test:
	$(FORGE) test -vvv

test-unit:
	$(FORGE) test --match-contract TokenVestingTest -vvv

test-fuzz:
	$(FORGE) test --match-contract TokenVestingFuzzTest -vvv

test-invariant:
	$(FORGE) test --match-contract TokenVestingInvariantTest -vvv

gas-report:
	$(FORGE) test --gas-report

clean:
	$(FORGE) clean

deploy-token:
	$(FORGE) script script/DeployMockToken.s.sol --rpc-url $(BSC_TESTNET_RPC) --broadcast -vvvv

deploy-vesting:
	$(FORGE) script script/DeployVesting.s.sol --rpc-url $(BSC_TESTNET_RPC) --broadcast -vvvv

configure-vesting:
	$(FORGE) script script/ConfigureVesting.s.sol --rpc-url $(BSC_TESTNET_RPC) --broadcast -vvvv

demo-claim:
	$(FORGE) script script/DemoClaim.s.sol --rpc-url $(BSC_TESTNET_RPC) --broadcast -vvvv

verify-token:
	$(FORGE) verify-contract $(MOCK_TOKEN_ADDRESS) src/MockToken.sol:MockToken --chain 97 --verifier-url https://api-testnet.bscscan.com/api --compiler-version v0.8.24+commit.e11b9ed9

verify-vesting:
	$(FORGE) verify-contract $(VESTING_CONTRACT_ADDRESS) src/TokenVesting.sol:TokenVesting --chain 97 --verifier-url https://api-testnet.bscscan.com/api --compiler-version v0.8.24+commit.e11b9ed9
