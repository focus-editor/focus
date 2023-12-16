#!/bin/sh

# Run Jai compiler quietly
jai -quiet first.jai

# Check if the Jai compiler command was successful
if [ $? -eq 0 ]; then
    # Save current directory and change to build_debug
    pushd build_debug || exit

    # Change permissions to make 'focus' executable
    chmod +x focus

    # Run focus (assuming it's a script or an executable)
    ./focus

    # Return to the original directory
    popd
fi
