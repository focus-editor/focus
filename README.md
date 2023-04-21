# Focus

A simple editor that tries to not stand in your way.

## Quick start

- Copy the exe into a folder where it will live. The folder needs to be writable.
- Launch the exe. This will create a global config file next to it.
- Open the global.focus-config file by e.g. dragging it to the editor window (or by using the Open With dialog and pointing to the editor's exe).
- In the config file you can specify the paths to your workspace folders (it's probably a good idea to add the jai folder to the list
  because then you'll be able to search within all jai modules folder as well as your project files)
- Save the global config, then relaunch the editor. It should scan all the files in your workspace.
- Use Ctrl + P to open file from your workspace, or Ctrl - O to navigate to file.

## Disclaimer

The editor is not finished and there's a big list of things to do before release. Your bug reports and comments are welcome!
Notable missing features:
- Tab support (currently tabs are drawn as a one-symbol arrow, and when you press tab spaces are inserted to the next tab stop)
- Creating new files (no UI for it yet - please use other ways of creating files until it's implemented)
- Projects and sessions: about 70% done, not ready to use yet
- Horizontal scrollbar is missing
- Line wrap
- Jump to line by number
- No UI error reporting (e.g. when a project is misconfigured or a file fails to save)
- Settings in the config file are not usable yet
- Color schemes

## Basic shortcuts

(you can see the full list of shortcuts and redefine keys in the global config file)

- Ctrl + P - open file (if you hold Ctrl when opening a file it will open on the side)
- Ctrl + W - close current file
- Ctrl + S - save
- Ctrl + Shift + W - close other file (when 2 files are open side-by-side)
- Ctrl + 1 / 2 switch to the left/right editor
- Ctrl + comma - toggle active pane
- Ctrl + Shift + L - enlarge/shrink the current editor (in the side-by-side layout)
- Ctrl + arrow keys - move cursor by word/paragraph
- Ctrl + Enter - insert a new line below without breaking
- Ctrl + Shift + Enter - insert a new line above without breaking
- Ctrl + D - select word
- Ctrl + D repeatedly - make a new cursor for the next occurrence
- Ctrl + L - select line
- Ctrl + Shift + D - duplicate selected lines
- Ctrl + F - search within open file. When the search bar is open, up/down to jump to the prev/next search result
- Ctrl + Shift + F - search within workspace
- Alt + Shift + Up/Down - move selection up/down
- Alt + arrows - scroll
- Alt + C - move cursor to the center of the screen. Useful when you've scrolled using the keyboard and now want to edit something

### Acknowledgements

- The editor was inspired by Jamie Brandon's blog post (https://www.scattered-thoughts.net/writing/focus-intro/).
  Nothing other than the name was borrowed from his editor - the name was just too good.
  
- The default font is created by Nikita Prokopov - https://github.com/tonsky/FiraCode

- Icons - Font Awesome by Dave Gandy - http://fontawesome.io