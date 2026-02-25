#!/bin/bash
set -e

# Claw Sheath Installation Script

echo "Installing Claw Sheath..."

# Detect OS
OS="$(uname -s)"
case "${OS}" in
    Linux*)     machine=linux;;
    Darwin*)    machine=darwin;;
    *)          machine="UNKNOWN"
esac

if [ "$machine" = "UNKNOWN" ]; then
    echo "Error: OS ${OS} is not supported. Only macOS and Linux are supported."
    exit 1
fi

# Detect Architecture
ARCH="$(uname -m)"
case "${ARCH}" in
    x86_64)     arch=amd64;;
    amd64)      arch=amd64;;
    arm64)      arch=arm64;;
    aarch64)    arch=arm64;;
    *)          arch="UNKNOWN"
esac

if [ "$arch" = "UNKNOWN" ]; then
    echo "Error: Architecture ${ARCH} is not supported."
    exit 1
fi

echo "Detected OS: $machine, Architecture: $arch"

# Define directories
INSTALL_DIR="$HOME/.claw-sheath"

echo "Cleaning previous installation (if any)..."
rm -rf "$INSTALL_DIR"

# Create installation directory
mkdir -p "$INSTALL_DIR"

# Currently using local repo for installation
# In the future, this will be replaced with a git clone or curl download
echo "Copying local repository files to $INSTALL_DIR..."
if [ -d "src" ] && [ -f "config.yml" ] && [ -f "cs" ]; then
    cp -R src "$INSTALL_DIR/"
    cp config.yml "$INSTALL_DIR/"
    cp cs "$INSTALL_DIR/"
    if [ -f "README.md" ]; then
        cp README.md "$INSTALL_DIR/"
    fi
else
    echo "Error: Cannot find source files (src/, config.yml, or cs) in current directory."
    echo "Please run this script from the root of the claw-sheath repository."
    exit 1
fi

GITHUB_REPO="antonibertel/claw-sheath"
BIN_TARGET="sheath-verifier-${machine}-${arch}"

echo "Downloading sheath-verifier binary for ${machine}/${arch}..."
DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/latest/download/${BIN_TARGET}"

if ! curl -fsSL -o "$INSTALL_DIR/sheath-verifier" "$DOWNLOAD_URL"; then
    echo "Error: Failed to download $DOWNLOAD_URL"
    echo "Please check your internet connection or the repository."
    # Fallback to local build if go is installed and src directory exists
    if [ -d "$INSTALL_DIR/src/verifier" ] && command -v go >/dev/null 2>&1; then
        echo "Attempting to build locally as fallback..."
        cd "$INSTALL_DIR/src/verifier"
        go build -o "$INSTALL_DIR/sheath-verifier" main.go
        cd - > /dev/null
    else
        exit 1
    fi
else
    chmod +x "$INSTALL_DIR/sheath-verifier"
fi

# Set permissions
chmod +x "$INSTALL_DIR/cs"
chmod +x "$INSTALL_DIR/src/sheath-env.sh"

echo ""
echo "Installation complete!"
echo "--------------------------------------------------------"
echo "Claw Sheath has been installed to: $INSTALL_DIR"
echo ""
echo "Your configuration file is located at:"
echo "  $INSTALL_DIR/config.yml"
echo ""
echo "To use the 'cs' wrapper command, please add the installation directory to your PATH."
echo "Add the following line to your ~/.bashrc, ~/.zshrc, or ~/.profile:"
echo "  export PATH=\"\$INSTALL_DIR:\$PATH\""
echo ""
echo "After adding it, restart your terminal or reload your shell profile:"
echo "  source ~/.bashrc  # (or ~/.zshrc)"
echo ""
echo "Then, you can protect your AI agents simply by prefixing their commands:"
echo "  cs openclaw agent --agent main --message \"Run rm important.txt\""
echo "  cs claude"
echo "--------------------------------------------------------"
echo "Stay productive. Stay safe."
