# TODO macOS
In order of priority:

1. Keyboard Input
    - Cmd+C to copy does not currently work. It actually does an unrelated behavior. Cmd+V works though.
    - Cmd+Arrow or Option+Arrow should do the correct platform-specific action. Currently we mimic Windows Ctrl+Arrow behavior.

2. Visual Glitches
    - IBeam cursor does not reset to Normal when hovering over the window title bar or bottom filename/line/col bar

3. Would Be Nice Eventually
    - Smooth Mac-style inertia scrolling

4. Out of our hands for now (unless we want to rewrite the Jai modules or something)
    - Resizing the window squishes the interface (Jai's Input module needs an update or rewrite)
