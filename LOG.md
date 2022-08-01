# TODO
- Don't draw characters that are invisible
- Load 2 files side by side
- Draw selection
- Select text
- Remove/replace selection on edits

- Don't redraw if nothing has changed
- Maybe don't store font atlas in an rgba texture
- Investigate subpixel rendering with FT
- Implement semantic highlighting
    - Polymorphic structs and possibly other types
    - Highlight globals?
    - Color cursor differently depending on what scope we're in
- Make sure cursor positioning is correct for all fonts and sizes

# DONE
+ Handle backspace
+ Handle delete
+ Handle enter
+ Type something
+ Move cursor around
+ Don't load CRLF
+ Draw cursor
+ Load a buffer and populate auxiliary structures
+ Display some text with newlines
+ Change font size according to monitor DPI
+ Detect that scale has changed and print a message
+ Make the application DPI-aware per monitor in the manifest
+ Set an application icon
+ Read a how-to about the metaprogram
