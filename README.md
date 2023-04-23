# Focus

A simple editor that tries to not stand in your way.

## Quick start

- Copy the exe into a folder where it will live. The folder needs to be writable.
- Launch the exe. This will create a global config file next to it.
- Open the global.focus-config file by e.g. dragging it to the editor window (or by using the Open With dialog and pointing to the editor's exe).
- In the config file you can specify the paths to your workspace folders (it's probably a good idea to add the jai folder to the list
  because then you'll be able to search within all jai modules folder as well as your project files)
- Save the global config, then relaunch the editor. It should scan all the files in your workspace.

## Disclaimer

The editor is in beta. This means you may encounter some bugs here and there, and not all wrinkles have been ironed out yet.

## Shortcuts

You can see the full list of shortcuts and redefine keys in the global config file.


## Acknowledgements

- The editor was made possible by the fantastic Jai programming language by [Jonathan Blow](https://en.wikipedia.org/wiki/Jonathan_Blow).

- The editor was inspired by [Jamie Brandon's blog post](https://www.scattered-thoughts.net/writing/focus-intro/). Nothing other than the name was borrowed from his editor - the name was just too good.

- I am very grateful to my wife who supported me along the way and took on the bigger share of the housework to let me work on the editor.

- A special thanks to the two early adopters who helped to make the editor more robust and more enjoyable to use: [@cookednick](https://github.com/cookednick) and [@ustance](https://github.com/ustance).

- The default font [FiraCode](https://github.com/tonsky/FiraCode) is created by [Nikita Prokopov](https://github.com/tonsky).

- Icons - [Font Awesome](http://fontawesome.io) by Dave Gandy.

- If not for VSCode's annoying "restart to apply the latest update" notifications every other day, this editor might never have been created.
