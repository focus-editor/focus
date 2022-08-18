# TODO
- Change cursor position by clicking
- Support tab
- Move cursor quicker with ctrl+arrows
- Move viewport with alt+arrows
- Draw selection
- Select text
- Remove/replace selection on edits

- Set some minimum window size (which should be enough when split in half)

- Don't redraw if nothing has changed
- Maybe don't store font atlas in an rgba texture
- Implement semantic highlighting
    - Polymorphic structs and possibly other types
    - Highlight globals?
    - Color cursor differently depending on what scope we're in
- Make sure cursor positioning is correct for all fonts and sizes
- Look into subpixel font positioning
    - Revisit the font loading code as it has some rounding to pixels there
      and consider using floats or other units for font metrics
    - Simp.draw_text only allows integer positioning
    - Should we keep using GL_NEAREST for sampling?
- Subpixel rendering: support other types of panels (lookup ft2-lcd_rendering)
  (not useful for the editor, but may be useful for games)

# DONE
+ Set some limits for splitter
+ Drag splitter
+ Change pointer when over editor
+ Draw inactive cursor differently
+ Limit vertical scroll
+ Scroll the editor we're hovering over
+ Draw footer shadow
+ Draw footer and splitter rects
+ Load 2 files side by side
+ Don't draw characters that are invisible
    + Figure out which lines are visible and only draw them
    + Figure out which characters are visible and only draw them
+ Scroll text in all directions
    + Use scissor and try it on horizontal scroll
    + Draw text at an offset from borders
    + Implement some version of smooth scrolling
    + Scroll horizontally
+ Don't do a draw call per line
+ Investigate subpixel rendering with FT
+ Understand how glyphs are rendered in Simp
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
