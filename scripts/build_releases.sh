#!/bin/bash
set -e

# Go verifier path
VERIFIER_DIR="src/verifier"

# Output directory
OUT_DIR="releases"
mkdir -p "$OUT_DIR"

# Build Matrix
OS_LIST=("linux" "darwin")
ARCH_LIST=("amd64" "arm64")

echo "Building Claw Sheath Verifier for multiple platforms..."

cd "$VERIFIER_DIR"

for GOOS in "${OS_LIST[@]}"; do
    for GOARCH in "${ARCH_LIST[@]}"; do
        echo "Building for $GOOS/$GOARCH..."
        BIN_NAME="sheath-verifier-$GOOS-$GOARCH"
        
        # Build the binary
        GOOS=$GOOS GOARCH=$GOARCH go build -o "../../$OUT_DIR/$BIN_NAME" main.go
    done
done

echo "Builds completed successfully. Binaries are in the '$OUT_DIR/' directory."
