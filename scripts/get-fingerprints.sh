#!/bin/bash

# Get SHA-1 and SHA-256 fingerprints for Android app signing
# This script helps developers quickly retrieve fingerprints for Google Sign-In configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Android Signing Fingerprints Extractor ===${NC}\n"

# Detect OS
OS="$(uname -s)"
case "$OS" in
    Darwin*)
        KEYSTORE_PATH="$HOME/.android/debug.keystore"
        ;;
    Linux*)
        KEYSTORE_PATH="$HOME/.android/debug.keystore"
        ;;
    MINGW*|MSYS*|CYGWIN*)
        KEYSTORE_PATH="$USERPROFILE\.android\debug.keystore"
        ;;
    *)
        echo -e "${RED}Unknown OS: $OS${NC}"
        exit 1
        ;;
esac

# Function to extract fingerprints from keystore
extract_fingerprints() {
    local keystore=$1
    local alias=$2
    local keypass=${3:-android}
    local storepass=${4:-android}

    if [ ! -f "$keystore" ]; then
        echo -e "${RED}Error: Keystore not found at $keystore${NC}"
        return 1
    fi

    echo -e "${GREEN}Found keystore at: $keystore${NC}\n"

    # Extract fingerprints
    local output=$(keytool -list -v -keystore "$keystore" \
        -alias "$alias" \
        -storepass "$storepass" \
        -keypass "$keypass" 2>/dev/null || true)

    if [ -z "$output" ]; then
        echo -e "${RED}Error: Could not read keystore. Check alias, password, or file permissions.${NC}"
        return 1
    fi

    # Extract SHA-1
    local sha1=$(echo "$output" | grep "SHA1" | head -1 | sed 's/.*SHA1: //' | xargs)

    # Extract SHA-256
    local sha256=$(echo "$output" | grep "SHA-256" | head -1 | sed 's/.*SHA-256: //' | xargs)

    if [ -z "$sha1" ] || [ -z "$sha256" ]; then
        echo -e "${RED}Error: Could not extract fingerprints from keystore${NC}"
        echo -e "${YELLOW}Full output:${NC}"
        echo "$output"
        return 1
    fi

    echo -e "${YELLOW}Keystore: $keystore${NC}"
    echo -e "${YELLOW}Alias: $alias${NC}"
    echo -e "${YELLOW}Certificate fingerprints:${NC}\n"
    echo -e "${GREEN}SHA-1:${NC}"
    echo "  $sha1"
    echo ""
    echo -e "${GREEN}SHA-256:${NC}"
    echo "  $sha256"

    return 0
}

# Function to display usage
show_usage() {
    cat << EOF
${BLUE}Usage:${NC}
  $0                              # Extract from debug keystore (default)
  $0 release                      # Extract from custom release keystore
  $0 custom <path> <alias>        # Extract from custom keystore with alias
  $0 --help                       # Show this help message

${BLUE}Examples:${NC}
  # Get debug fingerprints (default)
  $0

  # Get release fingerprints (prompts for path and alias)
  $0 release

  # Get fingerprints from custom keystore
  $0 custom ./my-release-key.keystore my-key-alias

${BLUE}Default values:${NC}
  Debug keystore: $KEYSTORE_PATH
  Debug alias: androiddebugkey
  Passwords: android (default)
EOF
}

# Parse arguments
case "${1:-debug}" in
    --help|-h)
        show_usage
        exit 0
        ;;
    debug)
        echo -e "${BLUE}Extracting debug keystore fingerprints...${NC}\n"
        if ! extract_fingerprints "$KEYSTORE_PATH" "androiddebugkey" "android" "android"; then
            echo -e "\n${YELLOW}Debug keystore not found. Have you run Flutter/Android yet?${NC}"
            echo -e "${YELLOW}Try running: flutter run${NC}"
            exit 1
        fi
        ;;
    release)
        echo -e "${BLUE}Extracting release keystore fingerprints...${NC}\n"
        read -p "Enter path to release keystore: " keystore_path
        read -p "Enter keystore alias [my-key-alias]: " alias
        alias="${alias:-my-key-alias}"
        read -sp "Enter keystore password: " storepass
        echo ""
        read -sp "Enter key password (press Enter if same as store password): " keypass
        echo ""
        keypass="${keypass:-$storepass}"

        if ! extract_fingerprints "$keystore_path" "$alias" "$keypass" "$storepass"; then
            exit 1
        fi
        ;;
    custom)
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo -e "${RED}Error: custom mode requires keystore path and alias${NC}"
            show_usage
            exit 1
        fi

        read -sp "Enter keystore password [android]: " storepass
        echo ""
        storepass="${storepass:-android}"
        read -sp "Enter key password [android]: " keypass
        echo ""
        keypass="${keypass:-android}"

        extract_fingerprints "$2" "$3" "$keypass" "$storepass"
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}\n"
        show_usage
        exit 1
        ;;
esac

# Show next steps
echo -e "\n${BLUE}=== Next Steps ===${NC}"
echo -e "1. Copy the SHA-1 and SHA-256 fingerprints above"
echo -e "2. Go to ${YELLOW}Firebase Console${NC} → Your Project → Project Settings"
echo -e "3. Add/Update your Android app with these fingerprints"
echo -e "4. Download ${YELLOW}google-services.json${NC} and place it at ${YELLOW}android/app/${NC}"
echo -e "5. Run ${YELLOW}flutter run${NC} to build with the new configuration"
echo ""
echo -e "For more details, see: ${YELLOW}docs/GOOGLE_SIGNIN_SETUP.md${NC}"
