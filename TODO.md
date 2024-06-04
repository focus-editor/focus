# TODO

- Config migration
    + Verify that settings merging works ok
    - ...

- Line wrap:
    - Have line_starts for editor
    - Implement wrapping for buffer
        - Point line_starts to real_line_starts unless in the line wrap mode
    - Have a toggle command
    - Have a maximum allowed line length (then force a line wrap, but with a possibility to disable and face the consequences)
    - Inspect all places where we use line_starts and consider using real_line_starts (with a switch?)

- When switching to another editor, jump to cursor (unless multiple)
- Autoindent region
- Ctrl-K should copy whatever was deleted
- Ctrl-K and other shortcuts should work in text inputs
- Notify about duplicate bindings and highlight that in the config file
- Search returns extra results: Runtime_Support, report_bounds_check_error_more_visibly
- Colors per programming language
    - Get the list of available colors

- A config option to disable subpixel font rendering

- Review the editor history implementation:
    - It's confusing to have the last state to persist randomly
    - When a new file is open, it doesn't replace itself as the most recent state?

- Improve the scoring for fuzzy search (maybe after the fact even) - score matches closer together higher
    - When a capital letter is present, score matching case higher?

- Ignore files and dirs during search - have a bunch of wildcards

- Have a font_ui config setting

- Pass a path to global config as a parameter

- Feedback from nafonso:
    requests:
        + be able to create cursors adjacent to each other (e.g. alt+up would keep the current cursor in the line that it is, but move me to the line above and I'd have 2 cursors. Kind of like the behaviour of ctrl+d but to select adjacent lines)
        - go to symbol
        - line numbers
        - way to toggle here strings to show as strings or be rendered as normal code (helpful when doing strings for meta programming to get the language coloring syntax)
        - someway to visualize colors in the config file (ie if you define a background color you can see either that line text in that color, or a square after it, prob with color picker integrated would be cherry on top)

    general comments:
        + switch project should have a shortcut by default
        - load previous project on launch
        - I'd recommend having a "select folder" to add new projects, instead of having to go to the projects folder, duplicating config, and setting that path in the config
        - https://ark-vcs.com/images/client_new.png

    bugs:
        - switching to tab_size 4 doesn't update the tabs, repro:
            - switch tab_size in the project config to 3 (it updated)
            - switch back to 4 (it didn't)
            - switch to 5 (it updated)
            - switch back to 4 (it didn't)
        - after switching back to project, ctrl+p wouldn't show all files, repro:
            - open UE project, do ctrl+p to see all files
            - switch to the other project, did ctrl+p there
            - switch back to UE project, ctrl+p didn't find all the files

- Keymap changing without having to reload - investigate a bug
- Make sure behaviour is consistent when selecting by cursor or by mouse (either with ctrl+D or with ctrl+arrows)

- Ctrl-double click should create a new cursor and select a word
- Ctrl-click to remove a cursor
- Show default config (readonly)

- Be able to change the width of the filename area in finder (and remember it somewhere)

- Highlight C/C++

- Use keyboard in the confirmation dialog
- Drop a folder into the editor to add it to workspace

- Highlight matching braces

- F12 to search by current identifier
- Generalise TODO highlighting
- Implement general language highlighting with a set of common keywords etc
- Numpad shortcuts

- Mark modified buffers in the navigate dialog
- Mark deleted buffers in the open file dialog
- Display the number of cursors in the footer
- Rollback creating another cursor (ctrl+alt+D?)

- Horizontal scrolling
- Ctrl + R to search by symbol within buffer (jump immediately when moving cursor between options)
- Ctrl + Shift + R to search by symbol within workspace
- Try to implement "jump to symbol definition". Display a popup if more than one. Do a scan of jai files for that.
- Custom title bar (currently too much work and not very robust)
- Ignore project folders which are children of another project folder?
- Profile the whole project to see if we're doing something stupid

- Detect conflicting keys in the same context in the same config

- Add horizontal scrollbar
    - Alt-HL smooth scroll

- Multi-cursor pasting not as in vscode https://discord.com/channels/661732390355337246/1100701456950099978/1104408405180956752

- Hot refresh workspace (not having to restart the editor)

- Select syntax highlighting dialog

- When an editor is closed using Ctrl+W, use session_notify_closed_editor to remove the buffer backup (if unmodified)
  (or maybe when it hasn't been edited or opened in this session?)
- Be able to ignore individual files

- Use SIMD for syntax highlighting
- remove_crlf_in_place - optimise a bit

- Replace / replace all

- File context menu:
    - Rename file
    - Delete file
    - Close file?

- When adding a directory to workspace, the check for parent directory is NOT RELIABLE. Paths are case-sensitive on Linux
    - Also, what if we add a parent dir to a dir already in the project - what would be the expected behaviour? Delete the child dir? Keep it and dedup the files?

- Sessions and buffer backups:
    - Write down a step by step loading process to identify the easiest format to load
    - When editing, remember:
        - A list of currently open editors with cursor/viewport/buffer information
            - Which buffer file corresponds to this editor
        - Editor layout (none/single/double)
        - Which editor was open on which side

- Consider the move_viewport_to_cursor_top action suggested by poyepolomix on Discord

- Log time with the session logger

- Try using File_Async when scanning project folders and measure how long it takes

- Save editor state on editor operations:
    - Alt + minus to open previous state
    - Alt + plus to open next state

- Save modified buffers to temporary files and recover after crashes

- Implement scrolling by dragging in all directions and with different speed

- When cutting search results in finder, go by characters and not bytes

- Finder improvements:
    - Have an extra input for filtering by file path
    - Case-sensitive search

- Jump to function definition:
    - Tokenizer: support broken down identifiers
    - Scan all jai files in a project (possibly in a separate thread) and build a lookup table for functions and structs
      (Do without scopes for now, later if we find we have to limit potential results we can do it)
    - Update the lookup table on file/buffer changes (buffers always take precedence over what's in files)

- Custom commands (maybe)
    - Modify the metaprogram to load files from some folder (maybe a file per action type)
    - Have handlers for them separate from the normal ones
    - Insert new commands into the lists so that the config knows about them

- If a buffer is modified on disk, ask for confirmation before saving (use the function and not the flag)

- Implement semantic highlighting
    - Polymorphic structs and possibly other types
    - Highlight globals?
    - Highlight shadowed variables
    - Color cursor differently depending on what scope we're in

- Remember window position (in session maybe)

- Optimisation:
    - See if we can join edits in edit groups (maybe on the fly on undo/redo)
    - Use custom allocators for edits to reduce memory fragmentation (maybe later)

- Look into subpixel font positioning
    - Revisit the font loading code as it has some rounding to pixels there
      and consider using floats or other units for font metrics
    - Simp.draw_text only allows integer positioning
    - Should we keep using GL_NEAREST for sampling?
- Subpixel rendering: support other types of panels (lookup ft2-lcd_rendering)
  (not useful for the editor, but may be useful for games)
- Investigate a crash when font size is too large - copy glyph to buffer segfaults

# DONE
+ Don't merge into default config
+ Fix the multi-line copying and pasting - https://discord.com/channels/661732390355337246/1100701456950099978/1103153377237540874
+ Create global config always
+ Case-sensitive / whole word search:
    + Make the icons nice
    + Tooltips and hover
    + No global search flags
    + Compile-time flags
+ Reset max line pixel width
+ Fix command execution via the popup
+ Project dir disambiguation
+ Update window title when clicking on a pane
+ Create new cursors above/below
+ Show project name in the window title
+ Ctrl-double click to select word
+ Ctrl-drag to select things using the newly created cursor
+ Open config commands should respect ctrl, ctrl-1/2
+ Don't crash when the config doesn't find the version number at the top
+ Derive path chunks in the file open dialog from the current buffer
+ Auto-enlarge when path chunks don't fit
+ Truncate path chunks when don't fit even when enlarged
+ Fix the thread logging crash
+ Merge the macOS misc PR and cleanup
+ Fix the race condition and reject the PR
+ Line height scale
+ Fix horizontal spacing
+ Reopen up to 2 open editors after workspace reload
+ Remove the unused get_range_as_string or get_string_from_range
+ Strip down the example project file
+ Fix the new file saving bugs
+ Fix the large path crash
+ Don't ignore your own config
+ Fix smooth scrolling
+ See if panic behaviour can be improved in release builds
+ Sticky viewport
    + Remember line number and offset_within_line after finishing scrolling (or when dragging the scrollbar)
    + Calculate viewport.top from it before drawing
    + Move the glue point
+ Remove the "config saved" messages when they don't apply
+ UI_ERROR_BRIGHT
+ Debug label
+ LOG.md / TODO
+ Changelog
+ Don't skip spaces when editing with multiple cursors
+ BUG: crash when trying to open the newly created file
+ Save All
+ BUG: crash when trying to delete line near the top
+ Switch project
+ Open projects folder
+ Open global config
+ Open project config
+ Make sure new files are colorised properly when they are saved
+ Commands
+ Only show the crlf warning in the footer
+ CRLF:
    + Get rid of crlf notes
    + Show a warning when a CRLF file is loaded, then dismiss on save
+ Create new files
+ Colors
+ Be able to override fonts
+ Don't reload if there are unsaved buffers
+ Reload workspace dirs
    + Remember old dirs before loading config
    + If there are unsaved buffers, show the dialog
    + Stop all threads and completely refresh everything
+ Implement config options
    + When parsing project dirs, replace path separators with /
    + Report errors on wrong configs (write the usage code first)
    + Parse settings
    + Use all current settings
    + Have an option to specify the time to dismiss a user message
    + Hot-load user config file and apply the changes immediately
+ Refresh buffers from disk
    + Make it work
    + Remove crlf on load every time
    + Even if a file is reported as changed, calculate hash and compare after removing crlf before proceeding
    + Test a crlf file changed externally
+ Unsaved files dialog
+ BUG: Pasting with multiple cursors broke
+ BUG: moving lines to the last line broke again
+ Fix all line_starts accesses
+ BUG: global config not being created
+ BUG: if a project folder is deleted, the editor doesn't know about that and doesn't give any errors when trying to save files
+ Improve scrolling using shitty touchpads
+ When switching to buffer or trying to save it, check that the file exists
+ When sorting the file list, put the modified buffers on top
+ Definitely ignore the editor's own temp dir, even if the user doesn't include it
+ When subsuming cursors, do something with the clipboard (also when undoing/redoing)
+ Jump to line on Ctrl+G
+ Blinking cursor
+ Local search
    + New widget
    + Keep the classic mode
    + Open in another pane on ctrl+enter, ctrl+1/2
    + Support search actions
+ Load UE5 source and try to scan it
    + When doing it, collect info on any binary files that had to be read to be ignored
+ Ctrl+C without a selection removes the selection
+ Progress bar when scanning workspace
    + Draw a simple progress bar
    + Have an atomic counter
    + At the end wait a bit, then dissolve
+ Try to log asserts into log_error.txt - would be very helpful for debugging release builds
+ When unable to save file, show a warning (have an error log?)
+ Optimise line offset storage and recalculation
    + Drop cursor positions and just use offsets
    + Move cursor up and down
    + Follow cursor
    + Calculate positions of only visible cursors when drawing
    + Draw selections
    + Handle mouse
    + Create new cursors on ctrl+click
    + Move tmp functions to non-tmp ones
    + Type text
    + Undo/redo
    + Make sure edit groups work properly
    + f ff f
    + Indentation
    + Implement the most important edits
    + Adjust cursors in joint editors properly on edits
    + Paste animation
    + Fix the crash after last undo (already fixed?)
    + Selection highlights and marks
    + Optimise cursor clipboard (use shared memory with offsets)
    + Be able to open actual files in the new buffers
    + Remove cursor_offsets at the end
    + Draw new buffers using one draw call
    + Draw tabs
    + Calculate cursor coords taking tabs into account
    + Save buffer
    + Draw footer
    + Fix the cursor when scrolled horizontally
    + Implement the rest of actions
    + Delete to end of line (Ctrl+K)
    + Ctrl+x without a selection cuts the whole line (but only if no cursors have a selection)
    + Fix issues near the end of file
        + Crash
        + Not processing the last line properly (when scanning for newlines)
        + Typing near the end is bugged
        + Fix joining lines
        + Test indent/unindent
        + New line without breaking on last line
        + Move last line up
    + Don't draw separators in the navigate mode
    + Look up the combo for an action from the keymap
    + Global search
        + Make it work
        + Auto-search etc.
        + Double shift to search
        + All files opened separately should always appear at the top in searches
    + New selection modes:
        + BUG: Selecting after Ctrl+D still selects in whole words mode
        + After double-click: enter word-selection mode
        + After triple-click: enter line-selection mode
        + Maintain both modes until mouse button is up
        + Can get rid of the timeout when it's done
    + BUG: search results sort order sometimes wrong
    + Fix the crash from last night
    + Rename carets and newbuffer
    + Rewrite the buffer array using bucket array
        + Parallelize workspace scanning
            + Get the list of all files upfront
            + Test scanning on small folders
        + Test with smaller buffer bucket sizes
        + Make sure the files are sorted correctly in the files list and in the search results
    + Opening webm crashes
        + Don't display binary files
    + Actually lock the buffer contents when modifying it
+ BUGS:
    + Copying off-by-one
    + Smooth scrolling
    + Cursor subsuming
+ Show in the program title when it's running in debug mode
+ Support tabs (just draw them, not even necessarily wide, just draw in some way - but wide would be best)
+ Finish text input improvements
+ Bake fonts
+ Log errors into focus-log.txt, focus-log1.txt, ... in release mode
+ Jai tokenizer parses everything correctly
+ Figure out how to anti-alias rounded corners
+ Improve cursor: draw occluded letters on top
+ New open file dialog
+ Watch single open files (not in project folders) - but don't watch the containing folders because we don't want that
+ Adjust cursors in joint editors properly
+ Try to support tabs properly
+ Test the exe on different machines
+ Optimisation: with large files, disable selection highlights (because we're calculating them every frame when dragging)
+ Make sure move to empty line works on lines with just whitespace
+ Buffer ordering improvements:
    + Make sure that files opened by double clicking or dragging which are within one of project dirs have their path displayed as the rest of the files
    + I should probably draw the project boundary in the file open dialog so that you see why JaiDE files appear at the top even when the match is worse
+ Keymap: add a "nothing" function (this is for merging)
+ Wildcard support in config
+ Open files by drag/drop (add them to standalone files if needed)
+ Watch single open files (not in project folders) - but don't watch the containing folders because we don't want that
+ Measure how much time it takes to copy 8 mb of data
+ Test memcpy with overlapping ranges with debug/release/compile time
+ Ctrl + J to join lines (should there be a limit of how many?)
+ BUG: cursor is being drawn on the other pane sometimes
+ Ctrl + Mouse Wheel to increase/decrease editor font size by 1 pt
+ (Ctrl (VSCode) or Alt (N++) or Alt+Shift (macOS)) + Mouse Click to add an additional cursor wherever the mouse is.
+ Ctrl + Shift + , to duplicate current vasu editor on the other pane
+ Ctrl + Home/End to jump to beginning/end of the file
+ Alt+up/down to move fast (editor action)
+ Alt-U/D or Alt-PgUp/Down scroll fast
+ Alt-Backspace/Delete to delete words
+ Shift-backspace - delete_line_and_go_up
+ Shift-Delete - delete_line
+ Important: improve jumping by words - treat non-word-char "words" as words too
+ Select word:
    + Favor the word on the left if present
    + Select all sorts of chars by double clicking
    + Don't select single characters by ctrl+D
    + Fix the issue near the beginning of the buffer (e.g. "!main" is selected)
+ On del, when deleting a newline, delete until the text starts, if the line is empty (then maybe no whitespace trimming will be required)
    + Also, check if it's whitespace all until the newline, then maybe delete all that in one go?
+ On backspace, don't delete to tab stops if in the middle of a line
+ Ctrl+Backspace to delete all whitespace to the next non-whitespace
+ Fix delete_word - actually delete both types of words (ideally ignore 1 space before the word)
+ Implement delete_word on the right
+ Select word: don't decode the whole line
+ Rewrite the input system using the keymap handler
    + Debug the config key map
    + Have only one action per context
    + Finish splitting the editor action functions
    + Modify the keymap to support hold actions (see Keymap for reference)
    + Alt+JK smooth scroll (hopefully the vim people will be happy)
    + Support commenting out stuff in focus config
    + Ctrl+Alt+arrows to scroll
    + Modify the config syntax highlighter so that it understands keymap
        + Build compile time hash tables to test action names
    + Ctrl-, to switch to other editor
    + Fix the hold actions - cancel them when a modifier is released too (have a list of active actions)
+ Ctrl + [ and Ctrl + ] to indent lines
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
