#!/bin/bash

# ========== UTILITIES ==========
function print_title {
    echo
    echo "=============================="
    echo "$1"
    echo "=============================="
}


function abort_if_failed {
    if [ $1 -ne 0 ]; then
        zenity --error --text="$2"
        exit 1
    fi
}

# ========== CONFIG ==========
REPO="https://github.com/WheeLang/whee"
SYNTAX_URL="https://raw.githubusercontent.com/WheeLang/whee/main/syntax.json"
INSTALL_DIR="/opt/bitey/Whee"
BIN_DIR="/usr/bin"
TMP_DIR="/tmp/whee_installer"
TEMP_USERNAME=$(whoami)

# ========== USER AND GROUP SETUP ==========
print_title "Setting up system users and permissions"

# Create chocobitey group if it doesn't exist
if ! getent group chocobitey >/dev/null; then
    sudo groupadd chocobitey
fi

# Add current user and root to chocobitey group
sudo usermod -aG chocobitey "$TEMP_USERNAME"
sudo usermod -aG chocobitey root

# Create _bitey user if it doesn't exist
if ! id -u _bitey >/dev/null 2>&1; then
    sudo useradd -r -s /usr/sbin/nologin -g chocobitey _bitey
fi

# Ensure /opt/bitey exists and has correct ownership and permissions
sudo mkdir -p /opt/bitey
sudo chown -R _bitey:chocobitey /opt/bitey
sudo chmod -R 770 /opt/bitey

# ========== STAGE 0 ==========
zenity --info --width=300 --title="Whee Installer" \
--text="Welcome! This script will install Whee and related software."

print_title "Preparing installation directory"
sudo rm -rf "$INSTALL_DIR"
sudo mkdir -p "$INSTALL_DIR"
mkdir -p "$TMP_DIR"

# ========== STAGE 1: Select Version ==========
VERSION_CHOICE=$(zenity --list --radiolist --title="Select Version" \
--column "Pick" --column "Version" --column "Description" \
TRUE "stable" "Latest stable release" \
FALSE "staging" "Latest pre-release (staging)")

abort_if_failed $? "No version selected. Installation cancelled."

print_title "Fetching selected release info"

if [[ "$VERSION_CHOICE" == "staging" ]]; then
    echo "→ Fetching staging..."
    RELEASE_JSON=$(curl -s "https://api.github.com/repos/WheeLang/whee/releases")
    DOWNLOAD_URL=$(echo "$RELEASE_JSON" | jq -r '[.[] | select(.prerelease)][0].assets[] | select(.name == "whee") | .browser_download_url')
    WHEEC_URL=$(echo "$RELEASE_JSON" | jq -r '[.[] | select(.prerelease)][0].assets[] | select(.name == "wheec") | .browser_download_url')
    WCC_URL=$(echo "$RELEASE_JSON" | jq -r '[.[] | select(.prerelease)][0].assets[] | select(.name == "wcc") | .browser_download_url')
else
    echo "→ Fetching stable..."
    RELEASE_JSON=$(curl -s "https://api.github.com/repos/WheeLang/whee/releases/latest")
    DOWNLOAD_URL=$(echo "$RELEASE_JSON" | jq -r '.assets[] | select(.name == "whee") | .browser_download_url')
    WHEEC_URL=$(echo "$RELEASE_JSON" | jq -r '.assets[] | select(.name == "wheec") | .browser_download_url')
    WCC_URL=$(echo "$RELEASE_JSON" | jq -r '.assets[] | select(.name == "wcc") | .browser_download_url')
fi

# ========== STAGE 2: Software Selection ==========
SOFTWARE_SELECTION=$(zenity --list --checklist \
--title="Select Software" \
--width=500 --height=300 \
--column "Install" --column "Component" --column "Description" \
TRUE "wcc" "Whee Compiler to Binary")

abort_if_failed $? "Installation cancelled by user."

print_title "Installing selected software"

# Enforce required components
ENFORCED_SELECTION="whee|wheec"
IFS="|" read -ra TEMP_SELECTED <<< "$SOFTWARE_SELECTION"
for soft in "${TEMP_SELECTED[@]}"; do
    if [[ "$soft" != "whee" && "$soft" != "wheec" ]]; then
        ENFORCED_SELECTION+="|$soft"
    fi
done

# ========== STAGE 3: Install ==========
print_title "3: Install"

IFS="|" read -ra SELECTED <<< "$ENFORCED_SELECTION"
TOTAL=${#SELECTED[@]}
COUNT=0

(
for soft in "${SELECTED[@]}"; do
    PERCENT=$(( COUNT * 100 / TOTAL ))

    case "$soft" in
        whee)
            echo "$PERCENT"
            echo "# Downloading whee..."
            curl -L --progress "$DOWNLOAD_URL" -o "$TMP_DIR/whee"
            sudo cp "$TMP_DIR/whee" "$INSTALL_DIR/"
            sudo chmod +x "$INSTALL_DIR/whee"
            sudo ln -sf "$INSTALL_DIR/whee" "$BIN_DIR/whee"
            ;;
        wheec)
            echo "$PERCENT"
            echo "# Downloading wheec..."
            curl -L --progress "$WHEEC_URL" -o "$TMP_DIR/wheec"
            sudo cp "$TMP_DIR/wheec" "$INSTALL_DIR/"
            sudo chmod +x "$INSTALL_DIR/wheec"
            sudo ln -sf "$INSTALL_DIR/wheec" "$BIN_DIR/wheec"
            ;;
        wcc)
            echo "$PERCENT"
            echo "# Downloading wcc..."
            curl -L --progress "$WCC_URL" -o "$TMP_DIR/wcc" >/dev/null 2>&1
            sudo cp "$TMP_DIR/wcc" "$INSTALL_DIR/"
            sudo chmod +x "$INSTALL_DIR/wcc"
            sudo ln -sf "$INSTALL_DIR/wcc" "$BIN_DIR/wcc"
            ;;
    esac

    COUNT=$((COUNT + 1))
done

# Final step: download syntax.json
echo "100"
echo "# Downloading syntax.json..."
sudo curl -L --progress "$SYNTAX_URL" -o "$INSTALL_DIR/syntax.json"
) |
zenity --progress \
  --title="Installing Whee Software" \
  --width=500 \
  --height=120 \
  --text="Starting installation..." \
  --percentage=0 \
  --auto-close

# Check if installation was canceled
if [ $? -ne 0 ]; then
    zenity --error --text="Installation canceled."
    exit 1
fi

sudo chown _bitey:chocobitey /opt/bitey/Whee
zenity --info --title="Success" --text="Installation complete!\nTry running:  whee yourfile.wh"
clear
