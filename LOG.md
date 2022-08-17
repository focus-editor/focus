# TODO
- Scroll text in all directions
    + Use scissor and try it on horizontal scroll
    + Draw text at an offset from borders
    + Implement some version of smooth scrolling
    + Scroll horizontally
    - Don't draw characters that are invisible

- Load 2 files side by side
- Draw selection
- Select text
- Remove/replace selection on edits

- Don't redraw if nothing has changed
- Maybe don't store font atlas in an rgba texture
- Implement semantic highlighting
    - Polymorphic structs and possibly other types
    - Highlight globals?
    - Color cursor differently depending on what scope we're in
- Make sure cursor positioning is correct for all fonts and sizes
- Subpixel rendering: support other types of panels
  (https://freetype.org/freetype2/docs/reference/ft2-lcd_rendering.html)
- Look into subpixel font positioning
    - Revisit the font loading code as it has some rounding to pixels there
      and consider using floats or other units for font metrics
    - Simp.draw_text only allows integer positioning

# DONE
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
