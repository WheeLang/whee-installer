# Whee Installer

A graphical Bash installer for [WheeLang/whee](https://github.com/WheeLang/whee).  
Easily install `whee`, `wheec` and `wcc` with a few clicks.

## Features

- Zenity GUI with checklist and progress bar
- Installs latest or staging (pre-release) versions
- Automatically configures /etc/whee and creates symlinks in /usr/bin

## Requirements

- `bash`
- `zenity`
- `jq`
- `curl`
- `sudo` privileges

## Usage

```bash
git clone https://github.com/WheeLang/whee-installer.git .whee-installer
cd .whee-installer
chmod +x install.sh
./install.sh
```
