<#
.SYNOPSIS
  Réinitialise complètement une distro WSL nommée "test"
  à partir d’un snapshot .tar ou .tar.gz

.EXAMPLE
  .\reset-wsl.ps1
  .\reset-wsl.ps1 -Snapshot "snapshots\devenv.tar.gz"
  .\reset-wsl.ps1 -Snapshot "C:\backups\debian-base.tar"
#>

param(
  [string]$DistroName = "test",
  [string]$Snapshot   = "snapshots\18-devenv.tar.gz"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$BaseDir    = (Get-Location).ProviderPath
$InstallDir = Join-Path $BaseDir $DistroName

Write-Host "=== 🔁 Reset WSL distro '$DistroName' ===" -ForegroundColor Cyan
Write-Host "BaseDir   : $BaseDir"
Write-Host "InstallDir: $InstallDir"
Write-Host "Snapshot  : $Snapshot"
Write-Host ""

# 0) Vérifications
if (-not (Test-Path -LiteralPath $Snapshot)) {
  throw "❌ Snapshot introuvable : $Snapshot"
}

# 1) Supprimer la distro existante
$existing = wsl -l -q | ForEach-Object { $_.Trim() } | Where-Object { $_ -eq $DistroName }
if ($existing) {
  Write-Host "→ La distro '$DistroName' existe, on la stoppe..." -ForegroundColor Yellow
  try { wsl --terminate $DistroName | Out-Null } catch { }
  wsl --unregister $DistroName | Out-Null
  Write-Host "✓ Distro désenregistrée" -ForegroundColor Green
} else {
  Write-Host "→ Aucune distro '$DistroName' trouvée (ok)" -ForegroundColor DarkGray
}

# 2) Supprimer le dossier d’installation
if (Test-Path -LiteralPath $InstallDir) {
  Write-Host "→ Suppression de $InstallDir..." -ForegroundColor Yellow
  Remove-Item -LiteralPath $InstallDir -Recurse -Force
  Write-Host "✓ Dossier supprimé" -ForegroundColor Green
}

# 3) Recréer le dossier vide
Write-Host "→ Création de $InstallDir..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
Write-Host "✓ Dossier créé" -ForegroundColor Green

# 4) Importer le snapshot
Write-Host "→ Import depuis $Snapshot (WSL2)..." -ForegroundColor Yellow
wsl --import $DistroName $InstallDir $Snapshot --version 2
Write-Host "✓ Import terminé" -ForegroundColor Green

# 5) Résumé
Write-Host ""
wsl -l -v | Select-String -SimpleMatch $DistroName | ForEach-Object { Write-Host $_ }
Write-Host ""
Write-Host "✅ Distro '$DistroName' recréée dans '$InstallDir'" -ForegroundColor Cyan
Write-Host "   → Utilisateur par défaut : root"
Write-Host "   → Tu peux lancer avec :  wsl -d $DistroName"
