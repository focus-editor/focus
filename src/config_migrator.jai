#run,stallable {
    // file_data:
    modified_data: [..] u8;
    array_resize(*modified_data, KEYBINDS.count, initialize = false);
    memcpy(modified_data.data, KEYBINDS.data, KEYBINDS.count);

    array_reserve(*modified_data, modified_data.count + 5);
}


KEYBINDS :: #string FOCUS_CONFIG
[2]  # Version number. Do not delete.

[[keymap]]

# - The first matching combination will be used, so order matters

[editors]   # <- this means that the following key combos will apply only when editing text

Alt-F4                      quit
Escape                      remove_additional_cursors
Ctrl-Escape                 remove_additional_cursors

Ctrl-D                      select_word_or_create_another_cursor
Ctrl-Shift-A                select_all_occurrences

[open file dialog]
Tab                         open_directory

[common]
Alt-X                       show_commands
Ctrl-Shift-P                show_commands

Ctrl-P                      show_open_file_dialog_in_search_mode
Ctrl-O                      show_open_file_dialog_in_navigate_mode
Ctrl-Shift-O                show_open_file_dialog_in_navigate_mode_from_root
Ctrl-Tab                    show_open_file_dialog_in_open_editors_mode

Ctrl-Alt-P                  switch_to_project

[search dialog]
Enter                       open_entry_in_place

FOCUS_CONFIG

