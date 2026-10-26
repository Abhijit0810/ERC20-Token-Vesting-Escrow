#!/usr/bin/env bash

echo "===================================================="
echo "🚀 ERC-20 Token Vesting Protocol Auto-Launcher"
echo "===================================================="

# Ensure foundry bin is in path if installed locally
export PATH="$PATH:$HOME/.foundry/bin:C:/Users/naika/.foundry/bin"

echo ""
echo "1️⃣  Deploying MockToken to Anvil..."
forge script script/DeployMockToken.s.sol --rpc-url http://127.0.0.1:8545 --broadcast

echo ""
echo "2️⃣  Deploying TokenVesting Escrow to Anvil..."
forge script script/DeployVesting.s.sol --rpc-url http://127.0.0.1:8545 --broadcast

echo ""
echo "3️⃣  Funding Escrow & Allocating Beneficiaries..."
forge script script/ConfigureVesting.s.sol --rpc-url http://127.0.0.1:8545 --broadcast

echo ""
echo "4️⃣  Fast-forwarding Time (90-Day Cliff Warp)..."
cast rpc evm_increaseTime 7776000 --rpc-url http://127.0.0.1:8545 || true
cast rpc evm_mine --rpc-url http://127.0.0.1:8545 || true

echo ""
echo "5️⃣  Opening Interactive Web UI Dashboard in Browser..."
cmd.exe /c start http://localhost:3000

echo ""
echo "===================================================="
echo "🎉 Setup Complete! Dashboard is live at:"
echo "👉 http://localhost:3000"
echo "===================================================="
