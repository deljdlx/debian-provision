# Script PowerShell pour supprimer la distribution WSL 'devenv' si elle existe

# Forcer l'encodage UTF-8 pour l'affichage correct
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Write-Color($Text, $Color) {
    Write-Host $Text -ForegroundColor $Color
}

Write-Color "[INFO] Vérification de l'existence de la distribution 'devenv'..." Yellow
$exists = wsl -l -q | ForEach-Object { $_.Trim() } | Where-Object { $_.ToLower() -eq "devenv" }
if ($exists) {
    Write-Color "[ACTION] Suppression de la distribution 'devenv'..." Yellow
    wsl --unregister devenv
    if ($LASTEXITCODE -eq 0) {
        Write-Color "[SUCCÈS] La distribution 'devenv' a été supprimée avec succès." Green
    } else {
        Write-Color "[ERREUR] La suppression de 'devenv' a échoué." Red
    }
} else {
    Write-Color "[INFO] La distribution 'devenv' n'existe pas." Cyan
}

# Afficher la liste complète des distributions WSL (mode verbose)
Write-Color "\n[INFO] Liste complète des distributions WSL (mode verbose) :" Yellow
wsl -l -v | ForEach-Object { Write-Color $_ White }
