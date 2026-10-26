# PowerShell Auto Launcher Script for Token Vesting Protocol

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "🚀 ERC-20 Token Vesting Protocol Auto-Launcher" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

$env:Path += ";C:\Users\naika\.foundry\bin"

Write-Host "`n1️⃣ Deploying MockToken to Anvil..." -ForegroundColor Yellow
& "C:\Users\naika\.foundry\bin\forge.exe" script script/DeployMockToken.s.sol --rpc-url http://127.0.0.1:8545 --broadcast

Write-Host "`n2️⃣ Deploying TokenVesting Escrow to Anvil..." -ForegroundColor Yellow
& "C:\Users\naika\.foundry\bin\forge.exe" script script/DeployVesting.s.sol --rpc-url http://127.0.0.1:8545 --broadcast

Write-Host "`n3️⃣ Funding Escrow & Allocating Beneficiaries..." -ForegroundColor Yellow
& "C:\Users\naika\.foundry\bin\forge.exe" script script/ConfigureVesting.s.sol --rpc-url http://127.0.0.1:8545 --broadcast

Write-Host "`n4️⃣ Fast-forwarding Time (90-Day Cliff Warp)..." -ForegroundColor Yellow
& "C:\Users\naika\.foundry\bin\cast.exe" rpc evm_increaseTime 7776000 --rpc-url http://127.0.0.1:8545
& "C:\Users\naika\.foundry\bin\cast.exe" rpc evm_mine --rpc-url http://127.0.0.1:8545

Write-Host "`n5️⃣ Opening Interactive Web UI Dashboard in Browser..." -ForegroundColor Green
Start-Process "cmd.exe" "/c start http://localhost:3000"

Write-Host "`n====================================================" -ForegroundColor Cyan
Write-Host "🎉 Setup Complete! Dashboard is live at http://localhost:3000" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Cyan
