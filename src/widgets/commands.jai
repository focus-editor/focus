commands_dialog_handle_event :: (event: Input.Event) {
    using commands_dialog;

    // if event.type == .KEYBOARD && event.key_pressed {
    //     action := map_event_to_action(event, Action_Open_File_Dialog);
    //     if action == {
    //         case .close_dialog;             hide_open_file_dialog(); return;
    //         case .open_entry_in_place;      open_file_dialog_open_entry(entries.selected, .in_place);    return;
    //         case .open_entry_on_the_side;   open_file_dialog_open_entry(entries.selected, .on_the_side); return;
    //         case .open_entry_on_the_left;   open_file_dialog_open_entry(entries.selected, .left);        return;
    //         case .open_entry_on_the_right;  open_file_dialog_open_entry(entries.selected, .right);       return;
    //         case .open_directory;           open_file_dialog_open_entry(entries.selected, .in_place, folder_only = true); return;
    //         case .pop_directory;            if pop_directory() return;

    //         case .search_in_buffer;     return;  // TODO: handle when the widget is rewritten
    //         case .search_in_project;    finder_open();                  return;
    //         case .toggle_expand;        toggle_expand();                return;
    //         case .move_up;              move_cursor(-1, wrap = true);   return;
    //         case .move_down;            move_cursor( 1, wrap = true);   return;
    //         case .move_up_fast;         move_cursor(-5);                return;
    //         case .move_down_fast;       move_cursor( 5);                return;
    //         case .move_up_one_page;     move_cursor(-entries.per_page); return;
    //         case .move_down_one_page;   move_cursor( entries.per_page); return;

    //         case .show_open_file_dialog_in_search_mode;             show_open_file_dialog(.search);
    //         case .show_open_file_dialog_in_navigate_mode;           show_open_file_dialog(.navigate);
    //         case .show_open_file_dialog_in_navigate_mode_from_root; show_open_file_dialog(.navigate, from_root = true);
    //     }

    //     handled := maybe_handle_text_input_event(*input, event);
    //     if handled return;

    // } else if event.type == .TEXT_INPUT {
    //     char := event.utf32;
    //     if open_file_dialog.mode == .navigate && (char == #char "/" || char == #char "\\") return;  // these are special chars, don't handle

    //     if char == 127 return;  // there seems to be a bug in the Input module
    //                             // which generates a TEXT_INPUT event for DEL
    //                             // when Ctrl+Backspace is pressed

    //     text_input_type_char(*open_file_dialog.input, char);
    //     refresh_entries();
    // }
}

show_commands_dialog :: () {
    active_global_widget = .commands_dialog;

    using commands_dialog;

    // array_reset_keeping_memory(*filtered);
    // for
}

hide_commands_dialog :: () {
    activate_editors();
}

commands_execute_selected :: () {

}

// for shortcut : SHORTCUTS_TO_DISPLAY {
//             combo := get_first_matching_key_combo_from_action(shortcut.action);

//             // Figure out combo width for aligning right
//             combo_width := 0.0;
//             plus_width  := cast(float) Simp.get_text_width(font_ui, "+");
//             for combo {
//                 combo_width += xx Simp.get_text_width(font_ui, it) + 2 * padding_h;
//                 if it_index < combo.count - 1 {
//                     combo_width += plus_width + 2 * padding_h;
//                 }
//             }

//             x = right_area.x + align_x - combo_width;
//             text_y := y + padding_v * 1.5;

//             key_rect := Rect.{ x = x, y = y, w = 0, h = key_height };
//             for combo {
//                 key_rect.x = x;
//                 key_rect.w = xx Simp.prepare_text(font_ui, it) + 2 * padding_h;
//                 key_rect = align_to_grid(key_rect);
//                 shadow_rect := expand(key_rect, 1);
//                 shadow_rect.y -= 2;
//                 draw_rounded_rect(shadow_rect, Colors.BACKGROUND_DARK);
//                 draw_rounded_rect(key_rect, Colors.SELECTION_ACTIVE);
//                 Simp.draw_prepared_text(font_ui, xx (x + padding_h), xx text_y, Colors.UI_DEFAULT);
//                 x += key_rect.w;
//                 if it_index < combo.count - 1 {
//                     Simp.draw_text(font_ui, xx (x + padding_h), xx text_y, "+", Colors.UI_DEFAULT);
//                     x += plus_width + 2 * padding_h;
//                 }
//             }
//             Simp.draw_text(font_ui, xx (x + padding_h * 10), xx text_y, shortcut.description, Colors.UI_DEFAULT);

//             y -= line_height;
//         }
//     }

#scope_export

commands_dialog: Commands_Dialog;


#scope_file

commands :: Command.[
    .{ .show_open_file_dialog_in_search_mode,               "Open File By Name",                  0 },
    .{ .show_open_file_dialog_in_navigate_mode,             "Navigate To File",                   0 },
    .{ .show_open_file_dialog_in_navigate_mode_from_root,   "Navigate To File From Root",         0 },

    .{ .switch_project,                                     "Switch Project",                     0 },
    .{ .open_projects_directory,                            "Open Projects Directory",            0 },
    .{ .open_global_config,                                 "Open Global Config",                 0 },
    .{ .open_project_config,                                "Open Project Config",                0 },

    .{ .create_new_file,                                    "Create New File",                    0 },
    .{ .create_new_file_on_the_side,                        "Create New File On The Side",        0 },

    .{ .search_in_project,                                  "Search In Workspace",                0 },

    .{ .select_all,                                         "Select All",                         0 },
    .{ .select_line,                                        "Select Line",                        0 },

    .{ .close_current_editor,                               "Close Current File",                 0 },
    .{ .close_other_editor,                                 "Close Other File",                   0 },

    .{ .toggle_comment,                                     "Toggle Code Comments",               0 },

    .{ .join_lines,                                         "Join Lines",                         0 },
    .{ .join_lines_no_spaces_in_between,                    "Join Lines (no spaces in between)",  0 },

    .{ .duplicate_lines,                                    "Duplicate Lines",                    0 },
    .{ .delete_line,                                        "Delete Line",                        0 },
    .{ .delete_line_and_go_up,                              "Delete Line And Go Up",              0 },
    .{ .delete_to_start_of_line,                            "Delete To Start Of Line",            0 },
    .{ .delete_to_end_of_line,                              "Delete To End Of Line",              0 },
    .{ .move_selected_lines_up,                             "Move Selected Lines Up",             0 },
    .{ .move_selected_lines_down,                           "Move Selected Lines Down",           0 },
    .{ .move_up_to_empty_line,                              "Move Up To Empty Line",              0 },
    .{ .move_down_to_empty_line,                            "Move Down To Empty Line",            0 },

    .{ .move_cursor_to_viewport_center,                     "Move Cursor To Screen Center",       0 },
    .{ .remove_additional_cursors,                          "Remove Additional Cursors",          0 },

    .{ .new_line_below_without_breaking,                    "New Line Below Without Breaking",    0 },
    .{ .new_line_above_without_breaking,                    "New Line Above Without Breaking",    0 },

    .{ .switch_to_left_editor,                              "Switch To Left Pane",                0 },
    .{ .switch_to_right_editor,                             "Switch To Right Pane",               0 },
    .{ .switch_to_other_editor,                             "Switch To Other Pane",               0 },

    .{ .duplicate_editor,                                   "Duplicate File On The Side",         0 },

    .{ .move_editor_to_the_left,                            "Move Pane To The Left",              0 },
    .{ .move_editor_to_the_right,                           "Move Pane To The Right",             0 },
];

Command :: struct {
    action: Action_Editors;
    name: string;
    num_times_used := 0;
}

Commands_Dialog :: struct {
    input: Text_Input;
    filtered: [..] Entry;
    selected: s64;

    scroll_y: s32;
    scroll_anim := #run Tween_Animation(s32).{ speed = xx 0.1, func = .lerp };
    per_page: s64 = 10;

    scroll_to_cursor: Scroll_Mode = .no;
};

Entry :: struct {
    type: enum { command; nothing; } = .command;
    using command: Command;
    highlights: [] bool;
    sort_key: u64;
}