# TODO

- Most important stuff (so I can start using the editor):
    + Search within buffer
    + Basic token highlighting
    - Grep in the project
    - Save modified buffers to temporary files and recover after crashes

- Before I ship:
    - Adjust cursors in joint editors properly
    - Tokenizer parses everything correctly
    - Finish text input fixes
    - Support tabs (just draw them, not even necessarily wide, just draw in some way - but wide would be best)
    - Ignore project folders which are children of another project folder?
    - Show help on F1
    - Bake fonts
    - Test the exe on different machines
    - Improve cursor: change color based on scope + draw occluded letters on top
    - Remove the edited status on a timeout after last edit/undo/whatever
    - See if memory usage can be improved
    - New open file dialog
    - Create new files
    - Notify about unsaved buffers on close

- Search in the project
    + Profile the use of the in-buffer search
    + Write a BMH implementation for search
    + Compare with the previous version
    + Create a panel for the search
    + Search for stuff, maybe start in the focus folder only for now
    + Strip away whitespace
    + Scrollbar
    + Top shadow
    + Only draw visible stuff
    + When searching reset scroll
    + Cursor:
        + Move by up/down
        + Jump to next file on ctrl+up/down
        + Scroll to cursor when moved
    + Deactivate input when moving cursor
    + Fix the way inactive cursors are displayed (both in finder and in editor)
    + Close editor on ctrl+W
    + Be able to center viewport on cursor
    + Use selected text from active editor if on one line on activation
    + Draw the number of results and files
    + Limit the number of results
    + Allow any number of chars for search
    + Say when the maximum number of results is reached
    + When jumping to cursor, align to the left
    + Open files:
        + On enter
        + Select the searched text
        + On click (don't conflict with the scrollbar)
    + Limit results width:
        + Don't go too much to the left
        + Don't go too much to the right
        + Mark cut lines with an ellipsis
    + Highlight search string
    + Don't activate finder's input on click in the results area (only if there are no results then it's ok)
    - Do case-insensitive search by default
    - Do case-sensitive on ctrl+enter?
    - Use threads to search and show a spinner after some time has passed
    - [bug] When buffer changes and search results don't, it may find wrong results:
        - Solution: always trigger search on buffer save (have to do the threading first)
    - Don't lock files after scanning
    
- Strip trailing whitespace on save    
    
- Save editor state on editor operations:
    - Alt + minus to open previous state
    - Alt + plus to open next state

- Text Input:
    - Select by mouse
    - Select words by ctrl+D
    - Fix the weird doubling of characters when pasted a newline
    
- When cutting search results in finder, go by characters and not bytes

- Tokenizer:
    + Identifiers can start with _
    - Parse @notes
    - Make $ a separate token
    - Allow \ in identifiers

- Implement case-insensitive search in buffer

- Jump to function definition:
    - Tokenizer: support broken down identifiers
    - Scan all jai files in a project (possibly in a separate thread) and build a lookup table for functions and structs
      (Do without scopes for now, later if we find we have to limit potential results we can do it)
    - Update the lookup table on file/buffer changes (buffers always take precedence over what's in files)

- Navigating project dirs in a dialog
- Create new files (with a mini-dialog?)
- If a buffer is modified on disk, ask for confirmation before saving (use the function and not the flag)

- Optimisation:
    - Measure how long it takes to insert a char/string into a buffer of various length
    - If it's long enough then consider how this could be optimised
    - Figure out a way to do edits with multiple cursors more efficiently
        - One idea: always copy buffer into a temporary string and rebuild the buffer every time, making changes for every cursor as we go. It would be probably a bit slower for one cursor, but still acceptable and much more predictable for many cursors
      (also this may be a good occasion to make sure other editors' cursors are adjusted when edits are done elsewhere)

- Open file dialog:
    - Review and cleanup code
    - Put the open editors at the top
    - Implement fuzzy searching with letter highlighting etc


- When there are several cursors where some of them are above the viewport, hitting enter will shift everything down
  and will jerk briefly, which is annoying
    - Ideally we need a way to glue viewport to a line, so that if it shifts then we shift the viewport too

- Remember open editors and show prev/next editor configuration with Ctrl+U / Ctrl+Shift_

- Detect tab symbols and draw them differently
- Don't redraw if mouse move is outside the window
- Add a warning on large texts (maybe semi-transparent)
- When unable to save file, show a warning (have an error log?)

- Implement semantic highlighting
    - Polymorphic structs and possibly other types
    - Highlight globals?
    - Highlight shadowed variables
    - Color cursor differently depending on what scope we're in
- Highlight matching braces
- Make sure cursor positioning is correct for all fonts and sizes
- Figure out how to anti-alias rounded corners
- Set a proper horizontal scroll limit
- Maybe don't draw too many horizontal characters
- When changing buffer in another editor, adjust cursors
    - It seems that in vscode cursors are tied to their position in buffer,
      so if that position moved then so do the cursors
      (just like the individual letters would)

- Try to improve memory usage (where did 100Mb go?)

- Look into subpixel font positioning
    - Revisit the font loading code as it has some rounding to pixels there
      and consider using floats or other units for font metrics
    - Simp.draw_text only allows integer positioning
    - Should we keep using GL_NEAREST for sampling?
- Get rid of the window top bar
- Subpixel rendering: support other types of panels (lookup ft2-lcd_rendering)
  (not useful for the editor, but may be useful for games)
- Fix the font unknown character glyph (try copying something from font-awesome)

# DONE
+ [quick] Highlight work log
+ Draw cursor line highlight (disabled)
+ Draw inactive cursors, but only if no search results are present
+ Create a panel for the search
    + Refactor animation into something more general
    + Use the new animation struct for the search bar
    + Slide in and out
    + Refactor the input system so that there can be only one active global widget
    + Make sure active widget is changed when activated as ui (on click)
    + See if we can compress the common ui pieces of code
    + Drag the slider
    + Draw the input
    + Type into input
    + Draw sample results
    + Ctrl+shift+L to temporarily enlarge (try with an animation?)
+ Footer: file name should occlude line numbers, not the other way around
+ Use Ctrl+1 and Ctrl+2 for switching panes
+ [bug] When finder is open, clicks on files in the dialog don't do anything
+ [bug] Weird selection when inserting line above when the cursor is more to the left
+ Text input: always show as much text as possible
+ Text input: can't select text by individual letters
+ Text input: draw a consistent outline of 1px
+ Bug: resize pointer is not shown when trying to resize window
+ Bug: crash when drawing search bar with in small window
+ Fix the memory usage: backend/gl.jai - update texture is called too often (fixed using a workaround, but memory usage is still high, even though not as high)
+ Syntax highlighting
    + Write a tokeniser
    + Analyse tokens and highlight functions
    + Parse here-strings
+ Text colorising
    + Decide how to draw colored text
    + Draw each word in its own color
    + Don't draw the chars off the screen
+ Text input - jump to selection boundary on arrow-left/right
+ Search and highlight results
    + Case-sensitive version, like the Ctrl+D one
    + Show the label if no text
    + Display the number of results in the bar
    + Select the first result after cursor
    + Select the text in the search bar when shown, it's really needed
    + Highlight results
    + Jump to it if it's outside viewport, otherwise don't jump
    + When opening search bar set selected text as search text if on single line
    + Don't highlight selections in the scrollbar when search bar is open
    + Highlight results in the scrollbar
    + Bug: Don't mark buffer as modified on cursor movements
+ Search within buffer - visual part:
    + Display the search bar
    + Enter text
    + Cleanup the code for input
    + Make sure the bar is displayed in the right place and is resized correctly
    + Draw differently in active/inactive state
    + Activate by click, deactivate by click elsewhere
    + Deactivate the editor cursor when the search bar is active
    + Display the number of search results
+ Fix a crash when dragging slider
+ Rescan buffers in a changed directory
+ Fix opening files by click
+ Make sure the cursor doesn't drift as string grows
+ Reload from disk
    + Don't rescan project dirs on every file change (only on additions/deletions)
    + When a file is changed elsewhere, if the buffer is not modified, update it with the opportunity to undo
      (remove all cursors because they may end up in weird places)
    + If a buffer is unsaved and is modified elsewhere, mark it as modified on disk
    + If a buffer is deleted, mark it as deleted
+ When pressing Ctrl+S, write the buffer to disk and mark as not modified (ignore standalone buffers for now)
+ Draw modified file name differently
+ Fix the drawing of selection when cursor pos is up
+ Display cursors in the scrollbar area
+ Highlight occurrences of selection
    + When there's some selected text and no current highlights, update highlights
    + Draw highlights
    + Display highlights in the scrollbar area
+ Fix the crash when a file is saved with open dialog hidden
+ Select whole words when creating new cursors (unless selected manually)
+ Move viewport in a constant smooth fashion (on ctrl+up/down)
+ Expand pane on ctrl+shift+L
+ Jump by words on ctrl/alt+left/right
+ Revert to ctrl+alt+left/right for pane change
+ Jump to next empty line on ctrl+up/down
+ Remember the scrollbar grab position
+ Set a minimum slider height
+ Make sure all lines are visible when dragging slider
+ Investigate why CHANGELOG.txt is slowing everything down (probably drawing too much?)
    + Make the remove_crlf function fast
    + Profile the scrolling
    + Try a newer version of render doc
    + Allocations when scrolling? What?
+ Draw scrollbars
    + Just draw for now
    + Try to migrate from hard-coded ui ids to automatic ones and use a separate one for scrollbars
    + Drag and go to click
    + Finish the slider for open file dialog (pointer image and misclicks)
    + File open dialog - don't click on files when over scrollbar
    + Editor - draw scrollbar correctly when not enough text
+ Strip away project path when scanning
+ Show line/col in the footer
+ Handle path overflow nicely
+ Show file name in footer
+ Open file dialog
    + On start, build a file list in the project
    + Filter the list
    + Don't leave empty space at the bottom because of scroll_y
    + Support PAGE UP/DOWN
    + Setup a file watcher and just rescan
    + Actually open files
    + Open files on click (release)
+ Input:
    + Draw a box and make it behave nicely when resizing
    + Draw an input box
    + Support basic kerning
    + Type text into input, move cursor etc
    + Support non-ascii
    + Support deleting
    + Support copy/cut/paste
+ Draw an example file list
    + Change box height depending on entries
    + Draw project and folder info
    + Change current entry and scroll
    + Draw scrollbar
    + Draw shadow when scrolled
    + Change pointer when hovering (and hover over entries)
    + Don't react to mouse in other places when it's over the dialog box
    + Close the dialog when clicked outside it
    + Scroll using mouse
    + Don't draw too many files, only draw visible ones
+ Try font-awesome icons
+ Don't change selection on ctrl+D if cursor already has selection
+ Move between panes by ctrl+arrow, move cursor horizontally by alt+arrows
+ Swap panes by ctrl+alt+arrow
+ Undo/redo
    + See if we can add a new edit type just for typing chars to avoid allocating them on the heap
+ Multiple cursors
    + Sort cursors each frame
    + Deduplicate cursors each frame
    + Support text typing
    + Adjust cursor positions (easier to do by looking at lines/cols)
    + Adjust cursor positions like it's done in Zig focus - for all operations
    + Support all the remaining single cursor operations
    + Free and clear cursor clipboards when removing extra cursors
    + After pressing escape return to the original cursor
    + After wrapping around, make the next cursor main and then stop
+ Select word by double-click
+ Change active pane by ctrl+alt+arrow
+ Move lines up/down
+ Comment/uncomment block
+ Paste animation
+ Copy/cut/paste
+ Duplicate lines
+ Fix selecting last line
+ Remove selection on escape
+ Page up/page down
+ Select all
+ Select lines
+ When dpi changes, adjust viewport position
+ Don't crash if window is resized to 0
+ Don't put cursor in the weird spot when clicking at the end of file
+ Put cursor at the center of viewport on alt+C
+ Select word with ctrl+D
+ Support tab
    + Insert tab when no selection
    + Indent selection
    + Unindent selection
+ Handle arrow keys differently when there's a selection
+ Remove/replace selection on edits
+ Be able to scroll while holding LMB
+ Move viewport with alt+arrows
+ Move cursor quicker with ctrl+arrows
+ Fix the crash when typing text
+ When dragging splitter, don't change selection on mouse up
+ When selecting by mouse continue to track cursor even when left the editor rect
+ Draw selection with rounded corners
+ Don't accidentally select when clicking near the border
+ Don't select text when typing
+ Scroll all the way without waiting for message near the end
+ Only scroll to cursor when cursor moved
+ Don't select when clicking next to border
+ Scroll when cursor is near border
+ Select text properly when clicking and dragging
+ Draw selection
+ Improve splitter dragging
+ Change cursor position by clicking
+ When dragging splitter ignore 0 to avoid blinking
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
