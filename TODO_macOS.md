# TODO macOS
In order of priority:

1. Keyboard Input
    - Cmd+Tab out of the window, then back into the window causes us to be in cursor-creation mode until we hit Cmd one more time.

2. Visual Glitches
    - IBeam cursor does not reset to Normal when hovering over the window title bar or bottom filename/line/col bar
    - Window seems to receive mouse-move events even when not the active window (Workaround: Minimize when not in use)

3. Would Be Nice Eventually
    - Smooth Mac-style inertia scrolling

4. Out of our hands for now (unless we want to rewrite the Jai modules or something)
    - Resizing the window squishes the interface (Jai's Input module needs an update or rewrite)
