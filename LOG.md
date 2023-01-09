# TODO

- Before I ship:
    + Show in the program title when it's running in debug mode
    + Support tabs (just draw them, not even necessarily wide, just draw in some way - but wide would be best)
    + Finish text input improvements
    - Tokenizer parses everything correctly
    - Ignore project folders which are children of another project folder?
    - Show help on F1
    - Bake fonts
    - Test the exe on different machines
    - Improve cursor: change color based on scope + draw occluded letters on top
    - Remove the edited status on a timeout after last edit/undo/whatever
    - New open file dialog
    - Create new files
    - Notify about unsaved buffers on close
    - Try to implement "jump to symbol definition". Display a popup if more than one. Do a scan of jai files for that.
    - Horizontal scrolling
    - Figure out how to anti-alias rounded corners
    - Have a user error log - with an icon in the title bar to toggle it
    - Support CRLF (ugh)
    - Have the option to not strip trailing whitespace (in the config?) Or can do ctrl+s as a main way to save, ctr+shift+s as an alternative way
    - Adjust cursors in joint editors properly
    - Highlight C/C++
    - "disable_that_annoying_paste_effect = true"
    - Jump to line on Ctrl+G
    - Log errors into focus-log.txt, focus-log1.txt, ... in release mode
    - See if memory usage can be improved
    - Custom title bar (currently too much work and not very robust)
    - Linux support
    
- Projects
    + Assuming the dir containing the focus executable is writable, create a projects folder in it
    + If the folder is not writable, let the user know
    + Create a simple config format
    + Load and parse the default config at the start
    - Then think about loading the user config and merging it with the default one
    - Create a temporary folder alongside the exe
    - Save font size in the current project
    - Have a version in the config file
    - Hot-load user config file and apply the changes immediately (how do we handle the project dir change?)
    - Make 3 levels of config files:
        - The baked in default config (always present)
        - The global user config (located next to the exe file)
        - The project user config (per project)
    
- Rewrite the input system using the keymap handler

- Be able to open the default config as a readonly buffer
    - Create a command system first

- Hide scrollbars unless scrolling or hovering over editor
- Add horizontal scrollbar

- Fix the whole word matching when creating new cursors (underscore seems to be considered not a word char, but inconsistently)
    - Make sure when selected a word by double clicking, the highlights only highlight whole words
    
- Strip trailing whitespace on save    
- Ctrl + [ and Ctrl + ] to indent lines
    - Need to refactor the input system first
- Ctrl + Home/End to jump to beginning/end of the file
    
- Save editor state on editor operations:
    - Alt + minus to open previous state
    - Alt + plus to open next state
    
- Save modified buffers to temporary files and recover after crashes
    - Save undo/redo history in temporary files
    
- When cutting search results in finder, go by characters and not bytes

- Tokenizer:
    + Identifiers can start with _
    + Make $ a separate token
    + Backtick as a separate token
    + Parse @notes
    - Allow \ in identifiers
    - Browse everything in the modules folder and try to find anything that sticks out

- Search:
    - Implement case-insensitive search in buffer
    - Finder improvements:
        - Have an extra input for filtering by file path
        - Case-sensitive search

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
    - Ctrl+O to open dialog in the current file's folder
    - Ctrl+Shift+O to open from root
    - Review and cleanup code
    - Put the open editors at the top
    - Implement fuzzy searching with letter highlighting etc
    
- Remove 3D-related stuff from Simp

- When there are several cursors where some of them are above the viewport, hitting enter will shift everything down
  and will jerk briefly, which is annoying
    - Ideally we need a way to glue viewport to a line, so that if it shifts then we shift the viewport too

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
- Support "Open file in" in the context menu on Windows?

# FEEDBACK

## GUI stuff that feels incomplete
- Horizontal scrolling stuff:
    - I expect a horizontal search bar when the text runs off the right edge.
    - Alt + Up/Down is equivalent to scrolling up and down with the mouse wheel, but Alt + Left/Right does not work the same way horizontally.
    - My mouse's horizontal scroll wheel (yes I have both) does nothing. I have to navigate long lines using Home/End to use the cursor to scroll.

## Possible bugs
- Sometimes if you backspace two spaces between words, it erases both space characters with one backspace rather than just one. I can reliably
reproduce this issue by doing the following:
    1. Type something like " hello" on a new line.
    2. Navigate to column 0, the first character.
    3. Press the spacebar once, adding one space.
    4. Press the right arrow key so you are in column 2, after the two spaces.
    5. Press backspace. This reliably erases both spaces for me.
    And this is not just a start-of-line tabbing issue. It sometimes occurs within the middle of a line.

## Keyboard/Mouse Shortcuts that I think are "missing"
- Ctrl + Backspace/Delete to erase an entire word.
- Ctrl + Mouse Wheel to increase/decrease editor font size by 1 pt. (use mouse wheel up/down "key press" events for this, not scroll delta. Print
key code in debug mode to find out the if case values. This will cause it to behave as expected on every platform similar to all other programs.)
- (Ctrl (VSCode) or Alt (N++) or Alt+Shift (macOS)) + Mouse Click to add an additional cursor wherever the mouse is.

## User Preferences that if they were able to be changed, I would change
- Color scheme, ideally the entire UI (like the window background color), but at the very least jai constructs/keywords like procedure names and
symbols like :: and semicolons.
- I-beam cursor instead of character-wide block. Boolean value.
- Customize keyboard shortcuts. This is probably very low priority compared to pretty much anything else in this list or LOG.md. I got this
working in my editor already with an XML file in under an hour. You'd basically just check the pressed key code (and modifiers) against the
configured procedures during a press event, calling one if the modifiers/key match a configured procedure. If something is wrong with the config,
you can use the default shortcuts and maybe report the error in a dialog box, presuming this was user-error after manually editing the config.

# DONE
+ Ignore .svn
+ Text Input:
    + Fix the weird doubling of characters when pasted a newline
    + Put cursor in the right place on click
    + Select by mouse
    + Select words by ctrl+D
    + Select words by double-click
    + Select the whole text by triple-click
    + Expand on ctrl+shift+L
    + Undo/redo
        + When undoing, sometimes extra text is appended in unexpected places
        + Cursors are not always remembered (e.g. when using replace_text)
+ Fix the parsing of "\\" in jai
+ Finder improvements:
    + While the initial scan is still in progress, display something that says so when the widget opens
    + Fix the crash when searching by whitespace
    + When jumping to file, make sure the positions are still valid
    + Cut lines so that the match is on the screen
        + Figure out how many characters can fit into the code section
        + If cut on the left, add an ellipsis
        + If the match can fit, maybe cut on the left, but leave as many characters as possible on the left
        + Always cut the invisible part on the right off
    + Understand why memory usage sometimes jumps to 1Gb
    + Don't search in deleted buffers
    + Hold any buffer refreshes while there's an active search request
    + If any buffer is modified, remember that so that finder can search again when it opens next time.
    + Highlight modified buffers
    + Enlarge finder on Ctrl+Shift+L
+ When pressing shift+delete, the selection is not removed
+ Improve buffer opening logic:
    + (To help with debugging should output buffer id in the open file dialog)
    + Try moving a file around - it doesn't get marked as deleted
    + Buffers are added when you try to open a file which doesn't exist but we have a buffer for them
+ Enlarge open file dialog
+ Open with focus on Windows
+ Make sure the selection is correct when a buffer is refreshed
+ Refresh local search results when a buffer is refreshed
+ Fix the font unknown character glyph (try copying something from font-awesome)
+ Start lines and columns from 1
+ File watcher: make sure a rescan doesn't include binary files
+ Rewrite finder to search in all in-memory project files:
    + At the start of the program start a thread which will scan all files and open buffers for them 
    + Before starting, open whatever editors there are from the previous session, so that it opens fast
    + Make sure there are no synchronisation conflicts:
        + The thread doing the initial scan should create all buffers in a separate array and have a separate hash table?
        + When the work is finished, the main thread should merge the arrays in an efficient way
    + Start a file watcher which will keep looking for new or modified files
    + [reported a bug] Release all file handles for the files we scanned (at least with no active editors)
    + Use the synchronous file api for now
    + Refresh modified buffer if needed
    + Rescan dir as required by the watcher
    + Make sure that when we save a file, the watcher knows about that (or maybe it's ok if it treats it as an external save?)
    + Make the open file dialog work from the open buffers
    + Create an example widget with search results
    + Search and display results:
        + Display something
        + Create a search request and only replace results when collected data from all threads
        + Make sure the results are sorted by project folder
        + Request redraw when there's an active search request
        + Don't overlap text
        + Display code lines
        + Color the code
        + Highlight matches
        + Move the cursor 
        + Open the results
+ Maybe sleep at least a little bit, don't render too many frames
+ Finder improvements
    + Use a thread to search to avoid blocking
    + Show a "searching..." label to indicate that searching is in progress
    + When reached the top of search results, select input again
    + Support Page Down/Up as an alternative to Ctrl+arrows
    + On Ctrl+B don't switch the active part, just toggle
    + WONTDO (switching to a new finder):
        - Try using a normal pool instead of flat pool and check if memory behaviour is still bad
        - [bug] When buffer changes and search results don't, it may find wrong results:
            - Solution: always trigger search on buffer save (have to do the threading first)
        - If a buffer is open, always use the buffer's bytes, not file's bytes
        - Don't lock files after scanning
+ Search in the project
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
    + Do case-insensitive search by default
    + Do case-sensitive on ctrl+enter
    + [bug] Finding underscores doesn't work with case-insensitive search
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
