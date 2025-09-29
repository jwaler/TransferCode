#!/usr/bin/env bash
# install.sh — met à jour /etc/apt/sources.list pour Debian 12 (bookworm) et installe vim/curl/wget
# Usage: sudo bash install.sh
# Author: Jérémie Leroux (adapté)
set -euo pipefail
IFS=$'\n\t'

LOG() { printf '%s %s\n' "$(date +'%Y-%m-%dT%H:%M:%S%z')" "$*"; }

# --- Vérif root ---
if [ "$EUID" -ne 0 ]; then
  LOG "ERREUR: ce script doit être exécuté en root. Relancez avec sudo."
  echo "Ex: sudo bash $0"
  exit 1
fi

# --- Pré-requis réseau (vérif simple) ---
if ! ping -c1 -W2 deb.debian.org >/dev/null 2>&1; then
  LOG "ATTENTION: deb.debian.org injoignable. Vérifie ta connexion réseau."
fi

# --- Mise à jour et installation des paquets requis ---
export DEBIAN_FRONTEND=noninteractive
LOG "apt update..."
apt update -y

LOG "Installation (ou vérification) de vim, curl, wget..."
apt install -y vim curl wget

# --- Sauvegarde du fichier sources.list existant ---
SRC="/etc/apt/sources.list"
BACKUP="${SRC}.bak-$(date +%Y%m%d%H%M%S)"
if [ -f "$SRC" ]; then
  LOG "Sauvegarde de $SRC vers $BACKUP"
  cp -a "$SRC" "$BACKUP"
else
  LOG "$SRC n'existe pas encore — pas de sauvegarde."
fi

# --- Écriture du nouveau sources.list (idempotent) ---
LOG "Écriture du nouveau $SRC"
cat > "$SRC" <<'EOF'
# Debian 12 (Bookworm) main repos
deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware

# Security updates
deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
deb-src http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware

# Bookworm updates
deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware

# Bookworm backports (newer software)
deb http://deb.debian.org/debian bookworm-backports main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian bookworm-backports main contrib non-free non-free-firmware
EOF

# --- Mise à jour des dépôts après modification ---
LOG "apt update après modification de $SRC..."
apt update -y

LOG "Terminé. $SRC a été remplacé (sauvegarde : $BACKUP)."
LOG "Les paquets vim, curl et wget sont installés."
exit 0
