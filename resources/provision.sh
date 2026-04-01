#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

echoRed()    { printf "\033[0;31m%s\033[0m\n" "$*"; }
echoGreen()  { printf "\033[0;32m%s\033[0m\n" "$*"; }
echoYellow() { printf "\033[0;33m%s\033[0m\n" "$*"; }
echoCyan()   { printf "\033[0;36m%s\033[0m\n" "$*"; }

# === Orchestration / options dev ===
PROVISION_VERSION="2025.10.25"
STAMP_DIR="/var/local"
DRY_RUN="${PROVISION_DRYRUN:-0}"
FORCE="${PROVISION_FORCE:-0}"
STEPS_FROM_ENV="${PROVISION_STEPS:-}"  # ex: "eza,wlclip"

usage() {
  cat <<USAGE
Usage: $0 [--steps a,b,c] [--force] [--dry-run] [--menu]
  --steps      : liste d'étapes à exécuter (ex: eza,wlclip,php)
  --force      : ignore les stamps et refait les étapes
  --dry-run    : affiche les commandes sans les exécuter
  --menu       : sélection interactive (gum)
Etapes: base, wlclip, eza, gumfzfbat, node, php, docker, clipboardrc, gitcfg, sshkey, finalize
USAGE
  exit 0
}

trap 'echoRed "❌ Erreur à la ligne $LINENO"; exit 1' ERR

# parse args
ARGS_STEPS=""
MENU=0
while [ $# -gt 0 ]; do
  case "$1" in
    --steps) shift; ARGS_STEPS="${1:-}";;
    --force) FORCE=1;;
    --dry-run) DRY_RUN=1;;
    --menu) MENU=1;;
    -h|--help) usage;;
    *) echoYellow "Arg inconnu: $1"; usage;;
  esac
  shift || true
done

ALL_STEPS=( base wlclip eza gumfzfbat node php docker clipboardrc gitcfg sshkey finalize )

if [ -n "${ARGS_STEPS:-}" ]; then
  IFS=',' read -r -a SELECTED_STEPS <<< "$ARGS_STEPS"
elif [ -n "$STEPS_FROM_ENV" ]; then
  IFS=',' read -r -a SELECTED_STEPS <<< "$STEPS_FROM_ENV"
elif [ "$MENU" = "1" ] && command -v gum >/dev/null 2>&1; then
  mapfile -t SELECTED_STEPS < <(printf "%s\n" "${ALL_STEPS[@]}" | gum choose --no-limit --header "Choisis les étapes à exécuter")
else
  SELECTED_STEPS=("${ALL_STEPS[@]}")
fi

have(){ command -v "$1" >/dev/null 2>&1; }
run() {
  if [ "$DRY_RUN" = "1" ]; then
    echo "+ $*"
  else
    eval "$@"
  fi
}
stamp_ok(){ [ "$FORCE" = "0" ] && [ -f "$STAMP_DIR/prov_$1.stamp" ]; }
stamp_set(){ [ "$DRY_RUN" = "1" ] || { echo "$(date -Is) $PROVISION_VERSION" | sudo tee "$STAMP_DIR/prov_$1.stamp" >/dev/null; }; }

do_step() {
  local name="$1"; shift
  if stamp_ok "$name"; then
    echoCyan "[skip] $name (déjà fait)"
    return 0
  fi
  echoGreen "==> $name"
  "$@"
  local rc=$?
  [ $rc -eq 0 ] && stamp_set "$name"
  return $rc
}

echoCyan "====================================================="
echoCyan " Provisioning du shell WSL (Debian 13 / Trixie)"
echoCyan "====================================================="

# ====== ÉTAPES ======

step_base() {
  export DEBIAN_FRONTEND=noninteractive
  run "sudo apt-get update -y"
  run "sudo apt-get install -y --no-install-recommends \
    ca-certificates apt-transport-https lsb-release gnupg curl wget \
    iproute2 iputils-ping net-tools bind9-dnsutils traceroute mtr-tiny fping \
    socat netcat-openbsd openssl \
    git vim nano less jq yq unzip zip tree file man-db bash-completion \
    lsof procps psmisc htop rsync ripgrep fd-find locate inotify-tools \
    ncdu mariadb-client openssh-client telnet \
    tcpdump make"
}

step_wlclip() {
  # bookworm fallback pour wl-clipboard
  run "echo 'deb http://deb.debian.org/debian bookworm main' | sudo tee /etc/apt/sources.list.d/bookworm.list >/dev/null"
  run "sudo apt update"
  run "sudo apt install -y wl-clipboard xclip"
  run "sudo rm /etc/apt/sources.list.d/bookworm.list"
  run "sudo apt update"
}

step_eza() {
  install_eza() {
    set -e
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
      | sudo gpg --dearmor -o /etc/apt/keyrings/eza.gpg
    sudo chmod 0644 /etc/apt/keyrings/eza.gpg
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/eza.gpg] http://deb.gierens.de stable main" \
      | sudo tee /etc/apt/sources.list.d/eza.list >/dev/null
    sudo apt update || true
    if sudo apt install -y eza; then return 0; fi
    arch="$(uname -m)"; case "$arch" in x86_64) deb_arch="amd64";; aarch64|arm64) deb_arch="arm64";; *) deb_arch="amd64";; esac
    tmpd="$(mktemp -d)"
    url="https://github.com/eza-community/eza/releases/latest/download/eza_${deb_arch}.deb"
    echoYellow "APT a échoué, fallback .deb: $url"
    curl -fL "$url" -o "$tmpd/eza.deb"
    sudo apt install -y "$tmpd/eza.deb"
    rm -rf "$tmpd"
  }
  have eza || run "install_eza"
  # Aliases eza (idempotents)
  run "grep -q 'alias ls=' \"$HOME/.bashrc\" 2>/dev/null || cat >> \"$HOME/.bashrc\" <<'EZA_ALIASES'
# --- eza aliases ---
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --group-directories-first --git --color=auto -F'
  alias ll='eza -lh --git --group-directories-first'
  alias la='eza -lha --git --group-directories-first'
  alias lt='eza --tree --git-ignore --group-directories-first'
fi
EZA_ALIASES"
  # alias fd -> fdfind (Debian)
  run "if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then echo 'alias fd=fdfind' >> \"$HOME/.bashrc\"; fi"
}

step_gumfzfbat() {
  # gum : apt sinon fallback GitHub
  if ! have gum; then
    if ! run "sudo apt-get install -y --no-install-recommends gum 2>/dev/null"; then
      tmpd="$(mktemp -d)"
      run "curl -fsSL -o \"$tmpd/gum.tar.gz\" \"https://github.com/charmbracelet/gum/releases/latest/download/gum_$(uname -s)_$(uname -m).tar.gz\" || true"
      if [ -s "$tmpd/gum.tar.gz" ]; then
        run "tar -xzf \"$tmpd/gum.tar.gz\" -C \"$tmpd\" || true"
        [ -f "$tmpd/gum" ] && run "sudo install -m 0755 \"$tmpd/gum\" /usr/local/bin/gum || true"
      fi
      run "rm -rf \"$tmpd\""
    fi
  fi
  run "sudo apt-get install -y --no-install-recommends fzf bat || true"
  run "if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then echo 'alias bat=batcat' >> \"$HOME/.bashrc\"; fi"
  # Raccourcis fzf idempotents
  run "if ! grep -q 'key-bindings.bash' \"$HOME/.bashrc\" 2>/dev/null; then [ -f /usr/share/doc/fzf/examples/key-bindings.bash ] && echo '[ -f /usr/share/doc/fzf/examples/key-bindings.bash ] && source /usr/share/doc/fzf/examples/key-bindings.bash' >> \"$HOME/.bashrc\"; fi"
}

step_node() {
  run "sudo apt-get install -y --no-install-recommends build-essential python3"
  if ! have node; then
    run "sudo apt-get install -y --no-install-recommends nodejs npm"
  fi
  run "sudo npm -g install n"
  run "sudo -E n stable"
  run "if ! grep -q '/usr/local/bin' <<<\"$PATH\"; then echo 'export PATH=\"/usr/local/bin:\$PATH\"' >> \"$HOME/.bashrc\"; fi"
  hash -r || true
}

step_php() {
  run "sudo curl -fsSLo /tmp/debsuryorg-archive-keyring.deb https://packages.sury.org/debsuryorg-archive-keyring.deb"
  run "sudo dpkg -i /tmp/debsuryorg-archive-keyring.deb"
  run "echo 'deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main' | sudo tee /etc/apt/sources.list.d/php.list >/dev/null"
  run "sudo apt-get update -y"
  run "sudo apt-get install -y --no-install-recommends \
    php8.4 php8.4-cli php8.4-common php8.4-fpm php8.4-mysql php8.4-xml php8.4-curl \
    php8.4-mbstring php8.4-zip php8.4-bcmath php8.4-intl php8.4-gd php8.4-imagick php8.4-dev php8.4-soap"
  run "if command -v update-alternatives >/dev/null 2>&1; then sudo update-alternatives --set php /usr/bin/php8.4 || true; fi"
  if ! have composer; then
    run "curl -fsSL https://getcomposer.org/installer | php"
    run "sudo mv composer.phar /usr/local/bin/composer"
    run "sudo chmod +x /usr/local/bin/composer"
  fi
}

step_docker() {
  run "if getent group docker >/dev/null 2>&1; then sudo usermod -aG docker \"$USER\" || true; fi"
}

step_clipboardrc() {
  # Bloc idempotent avec marqueurs
  run "if ! grep -q 'BEGIN_CLIPRC' \"$HOME/.bashrc\" 2>/dev/null; then cat >> \"$HOME/.bashrc\" <<'CLIPRC'
# ==== BEGIN_CLIPRC ====
# === Clipboard helpers (WSLg/Wayland -> X11 -> Windows fallback) ===
copy() {
  if command -v wl-copy >/dev/null 2>&1 && [ -n \"\${WAYLAND_DISPLAY:-}\" ]; then
    wl-copy
  elif command -v xclip >/dev/null 2>&1 && [ -n \"\${DISPLAY:-}\" ]; then
    xclip -selection clipboard
  else
    iconv -f UTF-8 -t UTF-16LE | /mnt/c/Windows/System32/clip.exe
  fi
}
paste() {
  if command -v wl-paste >/dev/null 2>&1 && [ -n \"\${WAYLAND_DISPLAY:-}\" ]; then
    wl-paste
  elif command -v xclip >/dev/null 2>&1 && [ -n \"\${DISPLAY:-}\" ]; then
    xclip -selection clipboard -o
  else
    powershell.exe -NoProfile -Command \"[Console]::OutputEncoding=[Text.UTF8Encoding]::UTF8;Get-Clipboard -Raw\" | tr -d '\r'
  fi
}
alias clip='copy'
alias pbcopy='copy'
alias pbpaste='paste'
# ==== END_CLIPRC ====
CLIPRC
fi"
}

step_gitcfg() {
  if ! git config --global user.name >/dev/null 2>&1; then
    if have gum; then
      run 'git_username=$(gum input --placeholder "Nom Git (ex: Julien Delsescaux)" --prompt "👤  Votre nom Git : "); git config --global user.name "$git_username"'
    else
      read -rp "Votre nom Git : " git_username
      run "git config --global user.name \"$git_username\""
    fi
  fi
  if ! git config --global user.email >/dev/null 2>&1; then
    if have gum; then
      run 'git_email=$(gum input --placeholder "email@exemple.com" --prompt "📧  Votre email Git : "); git config --global user.email "$git_email"'
    else
      read -rp "Votre email Git : " git_email
      run "git config --global user.email \"$git_email\""
    fi
  fi
  run "git config --global init.defaultBranch main"
}

step_sshkey() {
  run "mkdir -p \"$HOME/.ssh\" \"$HOME/__dev\""
  if [ ! -f "$HOME/.ssh/id_rsa" ] && [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    echoYellow "Aucune clé SSH trouvée."
    if have gum; then
      if gum confirm "🔑  Générer une nouvelle clé SSH (ed25519) ?"; then
        run 'ssh_email=$(gum input --placeholder "email@exemple.com" --prompt "📧  Email pour la clé : "); ssh-keygen -t ed25519 -C "$ssh_email" -N "" -f "$HOME/.ssh/id_ed25519"'
        echoGreen "✅ Clé SSH générée avec succès."
        run 'gum style --foreground 212 "Voici ta clé publique :"'
        run 'gum style --foreground 36 "$(cat \"$HOME/.ssh/id_ed25519.pub\")"'
      else
        run 'gum style --foreground 244 "⏩  Clé SSH non générée (tu pourras le faire plus tard)."'
      fi
    else
      read -rp "Générer une nouvelle clé SSH (ed25519) ? (y/n): " yn
      if [ "${yn,,}" = "y" ]; then
        read -rp "Email pour la clé : " ssh_email
        run "ssh-keygen -t ed25519 -C \"$ssh_email\" -N '' -f \"$HOME/.ssh/id_ed25519\""
        echoGreen "✅ Clé SSH générée."
        run "cat \"$HOME/.ssh/id_ed25519.pub\""
      fi
    fi
  else
    echoGreen "✅ Clé SSH déjà présente."
  fi
}

step_finalize() {
  run "sudo apt-get clean"
  run "sudo rm -rf /var/lib/apt/lists/*"
  run "mkdir -p \"$HOME/.ssh\" \"$HOME/__dev\""
  echo
  echoGreen "✅ Installation terminée — environnement Debian 13 prêt."
  echo -n "node: "; (node -v 2>/dev/null || echo "non installé")
  echo -n "npm : "; (npm -v 2>/dev/null || echo "non installé")
  echo -n "php : "; (php -v 2>/dev/null | head -n1 || echo "non installé")
  echo -n "cmp : "; (composer -V 2>/dev/null | awk '{print $1,$2}' || echo "non installé")
  echo
  # Tag global de provision (utile pour base immuable)
  run "echo \"$PROVISION_VERSION\" | sudo tee /etc/provision.version >/dev/null"
}

# ====== EXÉCUTION ======
[ -d "$STAMP_DIR" ] || run "sudo mkdir -p '$STAMP_DIR'"

for s in "${SELECTED_STEPS[@]}"; do
  case "$s" in
    base)        do_step base        step_base ;;
    wlclip)      do_step wlclip      step_wlclip ;;
    eza)         do_step eza         step_eza ;;
    gumfzfbat)   do_step gumfzfbat   step_gumfzfbat ;;
    node)        do_step node        step_node ;;
    php)         do_step php         step_php ;;
    docker)      do_step docker      step_docker ;;
    clipboardrc) do_step clipboardrc step_clipboardrc ;;
    gitcfg)      do_step gitcfg      step_gitcfg ;;
    sshkey)      do_step sshkey      step_sshkey ;;
    finalize)    do_step finalize    step_finalize ;;
    *) echoYellow "Step inconnue: $s (ignorée)";;
  esac
done
