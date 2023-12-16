#!/bin/sh

# Define color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Function to display messages
echo_green() {
    echo -e "${GREEN}$1${NC}"
}

echo_red() {
    echo -e "${RED}$1${NC}"
}

# List and remove all files with .exe and .pdb extensions
echo_green "Listing .exe and .pdb files in the current directory:"
find . -maxdepth 1 -name "*.exe" -or -name "*.pdb"

echo_green "Removing .exe files..."
rm -f *.exe
if [ $? -eq 0 ]; then
    echo_green "Successfully removed .exe files."
else
    echo_red "Failed to remove .exe files."
fi

echo_green "Removing .pdb files..."
rm -f *.pdb
if [ $? -eq 0 ]; then
    echo_green "Successfully removed .pdb files."
else
    echo_red "Failed to remove .pdb files."
fi

# List contents of the build_debug directory, then remove it
if [ -d "build_debug" ]; then
    echo_green "Listing contents of build_debug directory:"
    ls -l build_debug

    echo_green "Removing build_debug directory..."
    rm -rf build_debug
    if [ $? -eq 0 ]; then
        echo_green "Successfully removed build_debug directory."
    else
        echo_red "Failed to remove build_debug directory."
    fi
else
    echo_red "Directory build_debug does not exist."
fi

# List contents of the build_release directory, then remove it
if [ -d "build_release" ]; then
    echo_green "Listing contents of build_release directory:"
    ls -l build_release

    echo_green "Removing build_release directory..."
    rm -rf build_release
    if [ $? -eq 0 ]; then
        echo_green "Successfully removed build_release directory."
    else
        echo_red "Failed to remove build_release directory."
    fi
else
    echo_red "Directory build_release does not exist."
fi
