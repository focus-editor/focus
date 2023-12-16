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
jai -quiet first.jai

if [ $? -eq 0 ]; then
    echo_green "Compilation successful."

    # List .exe and .pdb files in build_debug directory
    if [ -d "build_debug" ]; then
        echo_green "Listing .exe and .pdb files in build_debug:"
        ls -l build_debug/*.exe build_debug/*.pdb
    else
        echo_red "Directory build_debug does not exist."
    fi

else
    echo_red "Compilation failed."
fi
