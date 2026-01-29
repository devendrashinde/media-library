# Quick Deploy Script
# Usage: .\quick-deploy.ps1

# Configuration - EDIT THESE VALUES
$OSMCHost = "192.168.1.96"
$OSMCUser = "osmc"

Write-Host "🚀 Quick Deploy to OSMC" -ForegroundColor Cyan
Write-Host ""

# Run full deployment
& ".\deploy-windows-to-osmc.ps1" -OSMCHost $OSMCHost -OSMCUser $OSMCUser

# Show connection info
Write-Host ""
Write-Host "✅ Deploy complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Access your application:" -ForegroundColor Yellow
Write-Host "  Frontend: http://$OSMCHost:4200"
Write-Host "  Backend:  http://$OSMCHost:3000"
