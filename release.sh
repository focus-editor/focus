#!/bin/sh

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Function to display green messages
echo_green() {
    echo -e "${GREEN}$1${NC}"
}

# Function to display red messages
echo_red() {
    echo -e "${RED}$1${NC}"
}

# Run Jai compiler quietly
jai -quiet first.jai - release

if [ $? -eq 0 ]; then
    echo_green "Compilation successful."

    # List .exe and .pdb files in build_release directory
    if [ -d "build_release" ]; then
        echo_green "Listing .exe and .pdb files in build_release:"
        ls -l build_release/*.exe build_release/*.pdb
    else
        echo_red "Directory build_release does not exist."
    fi

else
    echo_red "Compilation failed."
fi
