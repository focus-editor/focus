# Focus

A simple editor whose goal is to get out of your way and let you do work.

This editor is for people who value simplicity, are sensitive to input latency and do not require heavy language support in their editor.

![focus-0 3 0](https://github.com/focus-editor/focus/assets/119373822/49a80c5a-f24a-469e-bbbb-88c315f9b391)


## Quick start

1. [Download the executable](https://github.com/focus-editor/focus/releases) and put it somewhere where it will live.

2. Launch the executable. Once launched, it will generate its configuration files.
    * On **Windows**, it will create a `global.focus-config` file and a `projects` folder next to itself.
    * On **macOS**, these files will be found in `/Users/YOURNAME/Library/Application Support/dev.focus-editor/`.
    * On **Linux**, these files will be found in `${XDG_CONFIG_HOME}/focus-editor/` (which usually expands to `${HOME}/.config/focus-editor`).

3. Open the global config file by using the command `Open Global Config` - you can find the shortcut to show commands on the welcome screen.

4. This editor expects that you tell it what folders it should add to the workspace. You do it by either editing the global config file for your default workspace, or by creating a project (see below)

5. A project in this editor is just a config file that lives in `projects/Project Name.focus-config`. There's an example project config file provided. You just edit the file and then activate the project by using the `Switch To Project` command.

NOTE: if you are on a newer macOS you may have to run `xattr -d com.apple.quarantine /Applications/Focus.app` in order to be able to run the editor, until we are able to sign the executable.


## Official Discord server

https://discord.gg/eSXquAzTmW


## How to compile

`$ jai first.jai - release`

(NOTE: it's `- release`, not `-release`)

Minimum Jai version: `0.2.010` (the language is currently in closed beta, but it will hopefully go into open beta soon)

**On macOS:**

1. Full XCode must be installed

2. To avoid multiple security warnings like [in these screenshots](https://github.com/focus-editor/focus/issues/6#issuecomment-1531240978):
> "freetype.dylib" cannot be opened because the developer cannot be verified. macOS cannot verify that this app is free from malware.

... run the following command:

`xattr -d -r com.apple.quarantine /path/to/your/jai/distribution`

**NOTE**: starting with Jai `0.1.090`, `AArch64` became the default platform when building on Apple Sillicon macs. However, some of the modules used by the editor are not fully ported to support it. You will need to use the `x86_64` compiler to build for macOS (for now):

`arch -x86_64 /path/to/jai-macos first.jai - release`


## Disclaimer

The editor is in beta. This means you may encounter some bugs here and there, and not all wrinkles have been ironed out yet.


## Limitations

- Only 64-bit systems are supported, Windows 8+, Linux (WIP), macOS (WIP).
- This editor is not designed for editing very large files (it is expected that editing might start lagging upwards of 100K LOC). 2GB files is a hard limit right now.
- CRLF will be converted to LF on save. It's time to move on.
- Multi-codepoint Unicode symbols are not supported.
- Currently only RGB monitor panels are supported. If your text looks funny or blurry, please open an issue.


## Acknowledgements

- The editor was made possible by the fantastic Jai programming language by [Jonathan Blow](https://en.wikipedia.org/wiki/Jonathan_Blow).

- The editor was inspired by [Jamie Brandon's blog post](https://www.scattered-thoughts.net/writing/focus-intro/). Nothing other than the name was borrowed from his editor - the name was just too good.

- I am very grateful to my wife who supported me along the way and took on the bigger share of the housework to let me work on the editor.

- A special thanks to the two early adopters who helped to make the editor more robust and more enjoyable to use: [@cookednick](https://github.com/cookednick) and [@ustance](https://github.com/ustance).

- The default font [FiraCode](https://github.com/tonsky/FiraCode) is created by [Nikita Prokopov](https://github.com/tonsky).

- Icons - [Font Awesome](http://fontawesome.io) by Dave Gandy.

- If not for VSCode's annoying "restart to apply the latest update" notifications every other day, this editor might never have been created.
