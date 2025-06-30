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
SYNTAX_URL="https://raw.githubusercontent.com/WheeLang/index/main/docs/syntax@latest/syntax.json"
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
            curl -L --progress-bar "$DOWNLOAD_URL" -o "$TMP_DIR/whee"
            sudo cp "$TMP_DIR/whee" "$INSTALL_DIR/"
            sudo chmod +x "$INSTALL_DIR/whee"
            sudo ln -sf "$INSTALL_DIR/whee" "$BIN_DIR/whee"
            ;;
        wheec)
            echo "$PERCENT"
            echo "# Downloading wheec..."
            curl -L --progress-bar "$WHEEC_URL" -o "$TMP_DIR/wheec"
            sudo cp "$TMP_DIR/wheec" "$INSTALL_DIR/"
            sudo chmod +x "$INSTALL_DIR/wheec"
            sudo ln -sf "$INSTALL_DIR/wheec" "$BIN_DIR/wheec"
            ;;
        wcc)
            echo "$PERCENT"
            echo "# Downloading wcc..."
            curl -L --progress-bar "$WCC_URL" -o "$TMP_DIR/wcc" >/dev/null 2>&1
            sudo cp "$TMP_DIR/wcc" "$INSTALL_DIR/"
            sudo chmod +x "$INSTALL_DIR/wcc"
            sudo ln -sf "$INSTALL_DIR/wcc" "$BIN_DIR/wcc"
            ;;
    esac

    COUNT=$((COUNT + 1))
done

print_title "Installing Bitey Package Manager (Required)"

# Step 1: Fetch the latest Bitey release from GitHub
echo "→ Fetching Bitey release info..."
BITEY_RELEASE_JSON=$(curl -s "https://api.github.com/repos/Chocobitey/bitey/releases/latest")
BITEY_BINARY_URL=$(echo "$BITEY_RELEASE_JSON" | jq -r '.assets[] | select(.name == "bitey") | .browser_download_url')

abort_if_failed $? "Failed to fetch Bitey release info."

# Step 2: Create /opt/bitey/bin directory
echo "→ Preparing /opt/bitey/bin..."
sudo mkdir -p /opt/bitey/bin

# Step 3: Download and place the bitey binary
echo "→ Downloading Bitey binary..."
curl -L --progress-bar "$BITEY_BINARY_URL" -o "$TMP_DIR/bitey"
abort_if_failed $? "Failed to download Bitey binary."

sudo cp "$TMP_DIR/bitey" /opt/bitey/bin/bitey

# Step 4: Set ownership and permissions
sudo chown -R _bitey:chocobitey /opt/bitey/bin
sudo chmod -R 771 /opt/bitey/bin

# Step 5 & 6: Create core directories
echo "→ Creating Chocobitey and Chocolaterie directories..."
sudo mkdir -p /opt/bitey/Chocobitey/remotes
sudo mkdir -p /opt/bitey/Chocolaterie

# Step 7: Download remote.yml for 'main' remote
echo "→ Installing default remote: main"
sudo mkdir -p /opt/bitey/Chocobitey/remotes/main
sudo curl -L --progress-bar \
  "https://raw.githubusercontent.com/Chocobitey/remote-main/refs/heads/main/remote.yml" \
  -o /opt/bitey/Chocobitey/remotes/main/remote.yml
abort_if_failed $? "Failed to download default remote.yml"

# Step 8: Make bitey executable
sudo chmod +x /opt/bitey/bin/bitey

# Optional: symlink to /usr/bin
sudo ln -sf /opt/bitey/bin/bitey /usr/bin/bitey

echo "✓ Bitey installed at /opt/bitey/bin/bitey"
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

sudo chown _bitey:chocobitey /opt/bitey/**
sudo chmod 771 /opt/bitey/**
zenity --info --title="Success" --text="Installation complete!\nTry running:  whee yourfile.wh"
clear
