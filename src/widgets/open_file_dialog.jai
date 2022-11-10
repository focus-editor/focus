open_file_dialog_handle_event :: (event: Input.Event) {
    mods := event.modifier_flags;

    if event.type == {
        case .KEYBOARD;
            if event.key_pressed {
                if event.key_code == {
                    case .ESCAPE;
                        hide_open_file_dialog();
                        return;

                    case #char "B";
                        if only_ctrl_pressed(mods) {
                            toggle_finder();
                            return;
                        }

                    case #char "F";
                        if only_ctrl_shift_pressed(mods) {
                            if !finder_is_open() then open_finder(); else activate_finder();
                            return;
                        }
                }
                open_file_dialog_handle_key_press(event.key_code, mods);
            }

        case .TEXT_INPUT;
            open_file_dialog_handle_text_input(event.utf32);
    }
}

init_open_file_dialog :: () {
    using open_file_dialog;

    pool_allocator := get_pool_allocator();
    push_allocator(pool_allocator);

    array_reset(*entries.all);
    reset(*memory_pool);  // to avoid having to free each string

    visitor_data: Visitor_Data = ---;
    visitor_data.ignore_folders = string.[".build", ".git", "bin"];
    visitor_data.ignore_files   = string.[".exe", ".pdb", ".rdbg", ".lib", ".dll", ".ttf", ".otf"];
    visitor_data.entries_dst = *entries.all;

    for dir : project_dirs {
        visitor_data.proj_path_prefix_len = dir.path_prefix_len;
        visit_files(dir.path, recursive = true, visitor_data, file_visitor_func, visit_directories = true);
    }

    recalculate_filtered_entries();
}

show_open_file_dialog :: () {
    using open_file_dialog;
    active_global_widget = .open_file_dialog;
    array_reset(*input.text);
    input.cursor.pos = 0;
    input.cursor.sel = 0;
    recalculate_filtered_entries();
}

hide_open_file_dialog :: () {
    active_global_widget = .editors;
}

open_file_dialog_handle_key_press :: (key_code: Input.Key_Code, mods: Mods) {
    using open_file_dialog;

    input_text := copy_temporary_string(to_string(open_file_dialog.input.text));
    handled := text_input_handle_keypress(*open_file_dialog.input, key_code, mods);
    if handled {
        if input_text != to_string(open_file_dialog.input.text) then recalculate_filtered_entries();
        return;
    }

    if key_code == {
        case .ENTER;
            open_file_dialog_open_entry(entries.selected, on_the_side = only_ctrl_pressed(mods));

        case .ARROW_DOWN; #through;
        case .ARROW_UP;
            using entries;
            selected += ifx key_code == .ARROW_UP then -1 else 1;
            if selected < 0 then selected = max(0, filtered.count - 1);
            if selected >= filtered.count then selected = 0;
            scroll_to_cursor = true;

        case .PAGE_UP; #through;
        case .PAGE_DOWN;
            using entries;
            selected += ifx key_code == .PAGE_UP then -entries.per_page else entries.per_page;
            if selected < 0 then selected = 0;
            if selected >= filtered.count then selected = filtered.count - 1;
            scroll_to_cursor = true;
    }
}

open_file_dialog_open_entry :: (selected: s64, on_the_side: bool) {
    using open_file_dialog;
    path := entries.filtered[selected].full_path;
    editors_open_file(path, on_the_side);
    hide_open_file_dialog();
}

open_file_dialog_handle_text_input :: (char: u32) {
    if char == 127 return;  // there seems to be a bug in the Input module
                            // which generates a TEXT_INPUT event for DEL
                            // when Ctrl+Backspace is pressed

    text_input_type_char(*open_file_dialog.input, char);

    recalculate_filtered_entries();
}

Open_File_Dialog :: struct {
    scroll_to_cursor := false;

    input: Text_Input;
    entries: Entries;

    Entries :: struct {
        all: [..] File_Info;  // all files in the project

        filtered: [..] File_Info;
        selected: s64;
        selected_by_mouse: s64 = -1;  // to remember which entry the left mouse button went down on

        scroll_y: s32;
        scroll_anim: Tween_Animation(s32);
        per_page: s64 = 10;
    }
}

BULLET_CHAR :: #run to_string(*convert_utf32_to_utf8(0x2022));


#scope_file

recalculate_filtered_entries :: () {
    using open_file_dialog;

    scroll_to_cursor = true;
    entries.scroll_y = 0;
    entries.selected = 0;
    array_reset(*entries.filtered);

    if input.text.count == 0 {
        // TODO: still give them scores and sort
        for entry : array_view(entries.all, 0, MAX_ENTRIES_TO_SHOW) {
            array_add(*entries.filtered, entry);
        }
        return;
    }

    str := to_string(input.text);
    num := 0;
    for entry : entries.all {
        if contains_nocase(entry.name, str) {
            array_add(*entries.filtered, entry);
            num += 1;
            if num >= MAX_ENTRIES_TO_SHOW break;
        }
    }
}

// @Cleanup: this logic needs some careful reviewing
// Also TODO: profile how long it takes to scan everything
file_visitor_func :: (file: *File_Visit_Info, config: Visitor_Data) {
    if file.is_directory {
        for config.ignore_folders {
            if equal_nocase(file.short_name, it) {  // TODO: do a wildcard match
                file.descend_into_directory = false;  // ignore
                return;
            }
        }
        return;
    }
    if file.is_symlink return;

    // TODO: do a wildcard match
    for config.ignore_files { if contains_nocase(file.short_name, it) return; }  // maybe ignore

    entry := get_file_info_from_full_path(file.full_name, config.proj_path_prefix_len);
    array_add(config.entries_dst, entry);
}

get_pool_allocator :: () -> Allocator {
    a: Allocator;
    a.proc = flat_pool_allocator_proc;
    a.data = *memory_pool;
    return a;
}

memory_pool: Flat_Pool;

// NOTE: could probably make it global
Visitor_Data :: struct {
    ignore_folders: [] string;
    ignore_files:   [] string;
    proj_path_prefix_len: s64;
    entries_dst: *[..] File_Info;
}

MAX_ENTRIES_TO_SHOW :: 200;
