#!/usr/bin/env bash
# install.sh — met à jour /etc/apt/sources.list pour Debian 12 (bookworm), installe vim/curl/wget,
# met à jour le système, télécharge Kasm et lance son installateur.
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

# --- Ajout demandé: update + upgrade ---
LOG "apt update -y (de nouveau) && apt upgrade -y"
apt update -y
apt upgrade -y

# --- Téléchargement & installation de Kasm en /tmp ---
KASM_URL="https://kasm-static-content.s3.amazonaws.com/kasm_release_1.17.0.7f020d.tar.gz"
ARCHIVE="/tmp/$(basename "$KASM_URL")"
WORKDIR="/tmp"
EXTRACT_DIR="/tmp/kasm_release"

LOG "Changement de répertoire vers $WORKDIR"
cd "$WORKDIR"

LOG "Téléchargement de Kasm depuis $KASM_URL"
if ! curl -fsSL -O "$KASM_URL"; then
  LOG "ERREUR: échec du téléchargement de $KASM_URL"
  exit 1
fi

LOG "Vérification de la présence de l'archive $ARCHIVE..."
if [ ! -f "$ARCHIVE" ]; then
  LOG "ERREUR: archive introuvable après téléchargement: $ARCHIVE"
  exit 1
fi

LOG "Décompression de l'archive $ARCHIVE"
tar -xf "$ARCHIVE"

# tar extrait le dossier kasm_release normalement ; ajuster si différent
if [ ! -d "$EXTRACT_DIR" ]; then
  # tenter de détecter le répertoire extrait s'il ne s'appelle pas exactement kasm_release
  DETECTED_DIR=$(tar -tf "$ARCHIVE" | head -n1 | cut -f1 -d"/" || true)
  if [ -n "$DETECTED_DIR" ] && [ -d "/tmp/$DETECTED_DIR" ]; then
    EXTRACT_DIR="/tmp/$DETECTED_DIR"
  fi
fi

if [ ! -d "$EXTRACT_DIR" ]; then
  LOG "ERREUR: dossier d'installation Kasm introuvable après extraction."
  ls -al /tmp
  exit 1
fi

LOG "Contenu extrait dans $EXTRACT_DIR :"
ls -al "$EXTRACT_DIR"

# Exécution du script d'installation Kasm
INSTALLER="$EXTRACT_DIR/install.sh"
if [ -f "$INSTALLER" ]; then
  LOG "Lancement de l'installateur Kasm : $INSTALLER"
  # Le script tourne déjà en root — pas besoin de sudo
  bash "$INSTALLER"
else
  LOG "ERREUR: install.sh introuvable dans $EXTRACT_DIR. Vérifie l'archive."
  exit 1
fi

LOG "Terminé. $SRC a été remplacé (sauvegarde : $BACKUP)."
LOG "Les paquets vim, curl et wget sont installés. Kasm a été téléchargé et son installateur lancé."
exit 0
