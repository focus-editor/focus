# TODO macOS
In order of priority:

1. Data Security & Stability
    - Closing Focus with unsaved files will (a) not ask you if you'd like to save them and (b) put the app in a state that requires a Force Quit.

2. Behavior
    - Cmd+Tab out of the window, then back into the window causes us to be in cursor-creation mode until we hit Cmd one more time.
    - Resizing the window on the right edge will assume the mouse is still held down, resulting in the scrollbar being dragged even when using other windows.

3. Visual Glitches
    - IBeam cursor does not reset to Normal when hovering over the window title bar or bottom filename/line/col bar
    - Window seems to receive mouse-move events even when not the active window (Workaround: Minimize when not in use)

4. Would Be Nice Eventually
    - Smooth Mac-style inertia scrolling

5. Out of our hands for now (unless we want to rewrite the Jai modules or something)
    - Resizing the window squishes the interface (Jai's Input module needs an update or rewrite)
