# TODO

- Before I ship:
    + Show in the program title when it's running in debug mode
    + Support tabs (just draw them, not even necessarily wide, just draw in some way - but wide would be best)
    + Finish text input improvements
    + Bake fonts
    + Log errors into focus-log.txt, focus-log1.txt, ... in release mode
    + Jai tokenizer parses everything correctly
    + Figure out how to anti-alias rounded corners
    + Improve cursor: draw occluded letters on top
    + New open file dialog
    - Create new files
    - Try to support tabs properly
    - Horizontal scrolling
    - Support CRLF (ugh)
    - Test the exe on different machines
    - Notify about unsaved buffers on close
    - Ctrl + R to search by symbol within buffer (jump immediately when moving cursor between options)
    - Ctrl + Shift + R to search by symbol within workspace
    - Try to implement "jump to symbol definition". Display a popup if more than one. Do a scan of jai files for that.
    - Show help on F1
    - Have the option to not strip trailing whitespace (in the config?) Or can do ctrl+s as a main way to save, ctr+shift+s as an alternative way
    - Adjust cursors in joint editors properly
    - Highlight C/C++
    - Jump to line on Ctrl+G
    - Word wrap
    - See if memory usage can be improved
    - Custom title bar (currently too much work and not very robust)
    - Linux support
    - Windows 11 support
    - Watch single open files (not in project folders) - but don't watch the containing folders because we don't want that
    - Have a user error log - with an icon in the title bar to toggle it
    - Ignore project folders which are children of another project folder?
    - Trace the whole project to see if we're doing something stupid
    
- Rewrite the input system using the keymap handler
    - Debug the config key map
    - Modify the config syntax highlighter so that it understands keymap
    - Support commenting out stuff in focus config

- Display files that are deleted on disk but modified in the open file dialog

- File management:
    - Create new files:
        - Ctrl + N to create a new buffer
            - Check if we have any non-file buffers with nothing in them first, to avoid creating a million buffers
            - If there's an empty buffer already, just switch to it
        - If a buffer has no name, use the first N non-whitespace characters
        - Ctrl + S to open a save file dialog
    - File context menu:
        - Rename file
        - Delete file
        - Close file?
        
- New selection modes:
    - After double-click: enter word-selection mode
    - After triple-click: enter line-selection mode
    - Maintain both modes until mouse button is up
    - Can get rid of the timeout when it's done
    
- Sessions and buffer backups:
    - Write down a step by step loading process to identify the easiest format to load
    - When editing, remember:
        - A list of currently open editors with cursor/viewport/buffer information
            - Which buffer file corresponds to this editor
        - Editor layout (none/single/double)
        - Which editor was open on which side

- Projects
    - If a project doesn't exist, don't set it when loading previous session
    - On the splash screen list all previous sessions
        - Display create time
        - Display last edit time
        - Display project name
        - Maybe display the number of unsaved buffers

- Config files:
    - Hot-load user config file and apply the changes immediately (how do we handle the project dir changes?)
    - Have a command to edit global config or project config (it will open the corresponding file)
    - Every time a config file changes, the configs need to be reloaded and re-merged (and the changes need to be applied)
    - When an editor is closed using Ctrl+W, use session_notify_closed_editor to remove the buffer backup (if unmodified)
      (or maybe when it hasn't been edited or opened in this session?)
    - Be able to ignore individual files
    
- Multiple cursors: when cursors have copied something into their own buffers and we remove the cursors,
  their buffers should be concatenated and put into the OS buffer
    
- New search-in-buffer widget - an extension from finder (with different modes of work, with transitions between each):
    - It's much nicer to see all occurrences at the same time, rather than trying to cycle through them blindly
    - Make it look like the project search widget, but without the file names (so can be smaller)
    - Jump to the occurrence under cursor immediately
    - Can extend to support searching by symbol (possibly by adding a # or something like Sublime/VSCode)

- Log time with the session logger
- Try to log asserts into log_error.txt - would be very helpful for debugging release builds
- Either limit the number of bytes in text input, or improve the handling of cursor (currently calculating the length every frame)
- Select word: depending on the char under cursor, select either word chars or punctuation

- BUG: When reloading file from disk (refresh_buffer_from_disk) make sure to remove crlf (until it's supported at least)

- Proper tab support:
    - Draw them wide (only in the visible part of the text)
    - Consider them a whitespace when calculating line start - they never need to show on the left in finder results
    - If it turns out to be too hard or messy, could just convert them to spaces on load

- Config parameters:
    - Convert to LF on load = true
    - "disable_that_annoying_paste_effect = false"
    - tab_size = 4
    - Convert tabs to spaces on load = false
    - cursor_style = block/line
    - highlight selection occurrences
    - log_level = info/error
    - load last session on start ?

- Hide scrollbars unless scrolling or hovering over editor
- Add horizontal scrollbar
    - Scroll by alt+left/right
- Search in buffer:
    - When pressing up/down to switch to prev/next result, don't wrap (but do wrap when using Enter - what else to go back?)

- Try using File_Async when scanning project folders and measure how long it takes

- Fix the whole word matching when creating new cursors (underscore seems to be considered not a word char, but inconsistently)
    - Easy to detect when using variables like success, success_read, log_error, error etc
    - Make sure when selected a word by double clicking, the highlights only highlight whole words

- Strip trailing whitespace on save
- Ctrl + [ and Ctrl + ] to indent lines
    - Need to refactor the input system first
- Ctrl + Home/End to jump to beginning/end of the file
- Alt + PgUp/PgDown to scroll viewport by page
- Ctrl + J to join lines (should there be a limit of how many?)
- (Ctrl (VSCode) or Alt (N++) or Alt+Shift (macOS)) + Mouse Click to add an additional cursor wherever the mouse is.
- Ctrl + Mouse Wheel to increase/decrease editor font size by 1 pt

- Optimisation: with large files, disable selection highlights

- Save editor state on editor operations:
    - Alt + minus to open previous state
    - Alt + plus to open next state

- Save modified buffers to temporary files and recover after crashes
    - Save undo/redo history in temporary files

- When cutting search results in finder, go by characters and not bytes

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

- When there are several cursors where some of them are above the viewport, hitting enter will shift everything down
  and will jerk briefly, which is annoying
    - Ideally we need a way to glue viewport to a line, so that if it shifts then we shift the viewport too

- Add a warning on large texts (maybe semi-transparent)
- When unable to save file, show a warning (have an error log?)

- Implement semantic highlighting
    - Polymorphic structs and possibly other types
    - Highlight globals?
    - Highlight shadowed variables
    - Color cursor differently depending on what scope we're in
- Highlight matching braces
- Set a proper horizontal scroll limit
- Maybe don't draw too many horizontal characters
- When changing buffer in another editor, adjust cursors
    - It seems that in vscode cursors are tied to their position in buffer,
      so if that position moved then so do the cursors
      (just like the individual letters would)

- Look into subpixel font positioning
    - Revisit the font loading code as it has some rounding to pixels there
      and consider using floats or other units for font metrics
    - Simp.draw_text only allows integer positioning
    - Should we keep using GL_NEAREST for sampling?
- Subpixel rendering: support other types of panels (lookup ft2-lcd_rendering)
  (not useful for the editor, but may be useful for games)
- Investigate a crash when font size is too large - copy glyph to buffer segfaults

# DONE
+ Open file dialog:
    + Display something to indicate no entries
    + Fix the jiggling at the bottom when typing every second letter
+ BUG: when pressing shift + backspace, a selection is created because we're holding shift. This is confusing.
+ BUG: Cursor is not shown correctly in the scrollbar area
+ BUG: When changing font size, it can be increased to a larger size on lower dpi screens
+ Create a new open file dialog:
    + Create 2 states: 
        + Search files in the project
        + Open files by navigating
    + Draw the navigator differently
    + From root (no path chunks present or from_root = true):
        + Display project dirs
        + Display available drives (on Windows)
    + Project dirs first, then drives
    + Open folder by enter, tab, or slashes
    + Display directory contents
        + Filter files we're not going to open anyway
        + Don't draw file paths for the navigator (unless starting from root)
    + Don't scan folders on every keystroke
    + Switch between modes while the dialog is open
    + Support clicking on path chunks
        + Highlight on hover
        + Rewind to the corresponding chunk on click
+ Bug: undos can cause a crash in certain situations with the open file dialog
+ When mouse pointer is over the title bar, change the to arrow
+ When window is resized, redraw
+ Ctrl + 0 to revert to the default font size
+ When the window loses focus, redraw
+ Fix select_word in empty inputs
+ Fix selection rounding
+ Use smoothstep instead of lerp for tween animations
+ Don't redraw if mouse move is outside the window
+ Smooth rounded corners:
    + Review the current code
    + Try to find a way to implement rounded corners using SDF
    + Try with integer heights - maybe it'll help to get rid of blurry edges
    + Figure out a way to invert the colors using the same shader
    + Cursor is not rounded when selection is present
    + Rewrite shadows, get rid of draw_corner
+ Remove 3D-related stuff from Simp
+ Existing open file dialog:
    + Review and cleanup code
    + Implement fuzzy searching with letter highlighting etc
    + Put the open editors at the top
    + Take into account how many times a buffer was opened
+ Ctrl + 1/2 when opening files to specify the preferred side
+ Add a timeout on dragging after double clicks (to avoid being too sensitive)
+ Fix a bug with not colorising text loaded externally
+ Tokenizer:
    + Identifiers can start with _
    + Make $ a separate token
    + Backtick as a separate token
    + Parse @notes
    + ^
    + Report any invalid tokens and fix them
    + Allow \ in identifiers
+ Ctrl + Backspace/Delete to erase an entire word.
+ BUG: can't open a file by double-click and the logger is not set up
+ Fix: when changing font size, the size of the path in the open file dialog doesn't change
+ BUG: viewport no longer moves right when typing off the edge of it
+ Make sure the logger writes to logs in the session folder (buffered)
    + Make a custom logger which writes to files in the session
    + When DEBUG=true, log also to the standard output/error
+ Fix the global config not being loaded
+ Basic project/session stuff
    + Assuming the dir containing the focus executable is writable, create a projects folder in it
    + If the folder is not writable, let the user know
    + Create a simple config format
    + Load and parse the default config at the start
    + Create a temporary folder alongside the exe
    + Then think about loading the user config and merging it with the default one
    + If no global config exists, attempt to create it on start
    + Load project dirs from the global config
    + Load last opened project
    + Investigate why a new session is not created when opening a file by double click
    + When a new instance is started, start a new session:
        + Create a folder in the temp folder `session_{timestamp}`
        + Save project name
        + When an old session is present, copy over stuff from there (gracefully fail if can't reopen stuff)
        + Save up to 10 sessions (delete the rest when starting)
    + Save session state somehow:
        + Have a file per buffer, with 2 editor slots, one optional (for the second editor)
        + Do it every quick frame
        + Measure how long it takes
        + Implement buffer saves using async file io
        + Measure how long it takes to save buffer
        + Save after saving the buffer (should be quick)
+ Use meow_hash to detect whether a file is unmodified
    + If the hashes match, unmark as modified
    + On any change to the buffer, calculate the hash again and compare against the stored one
    + When a buffer is created, refreshed from disk, or saved, calculate and store a meow hash
    + If the buffer is marked as modified on disk, load the file contents from disk and refresh the hash from there
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
