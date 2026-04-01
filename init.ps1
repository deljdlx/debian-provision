$Distro = "devenv"

# Contenu minimal du wsl.conf
$conf = @"
[user]
default=debian
"@

# Chemin du fichier dans la distro
$path = "\\wsl$\$Distro\etc\wsl.conf"

# S'assure que le dossier /etc existe
[System.IO.Directory]::CreateDirectory("\\wsl$\$Distro\etc") | Out-Null

# Écrit le fichier en UTF-8 sans BOM
[System.IO.File]::WriteAllText($path, $conf, (New-Object System.Text.UTF8Encoding($false)))

# Redémarre la distro pour appliquer la conf
wsl --terminate $Distro

Write-Host "✅ wsl.conf copié. Au prochain lancement de '$Distro', tu seras connecté en 'debian'."
