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
- Creating new files (no UI for it yet - please use other ways of creating files until it's implemented)
- Projects and sessions: about 70% done, not ready to use yet
- Horizontal scrollbar is missing
- Line wrap
- No UI error reporting (e.g. when a project is misconfigured or a file fails to save)
- Settings in the config file are not usable yet
- Color schemes

## Shortcuts

You can see the full list of shortcuts and redefine keys in the global config file.


### Acknowledgements

- The editor was made possible by the fantastic Jai programming language by Jonathan Blow

- The editor was inspired by Jamie Brandon's blog post (https://www.scattered-thoughts.net/writing/focus-intro/). Nothing other than the name was borrowed from his editor - the name was just too good.

- I am very grateful to my wife who supported me along the way and took on the bigger share of the housework to let me work on the editor.

- A special thanks to the two early adopters who helped to make the editor more robust: @cookednick and @ustance.

- The default font is created by Nikita Prokopov - https://github.com/tonsky/FiraCode

- Icons - Font Awesome by Dave Gandy - http://fontawesome.io

- If not for VSCode's annoying "restart to apply the latest update" notifications every other day, this editor might never have been created.
