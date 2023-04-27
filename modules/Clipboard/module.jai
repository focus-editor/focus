/*

A set of OS clipboard functions, such as getting text out of the clipboard, setting a bitmap, etc.

API
--------------------------------------------------------------
```
os_clipboard_get_text   :: () -> string                        - Retrieves a copy of the string that is currently in the clipboard.
os_clipboard_set_text   :: (text: string)                      - Copies a string into the clipboard.
os_clipboard_set_bitmap :: (width: s32, height: s32, rgb: *u8) - Copies a bitmap in RGB8 format into the clipboard.
os_clipboard_empty      :: ()                                  - Clears any and all data currently in the clipboard.
```
*/

#load "Clipboard.jai";
