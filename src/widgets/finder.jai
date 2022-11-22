finder_handle_event :: (event: Input.Event) {
    if event.type == {
        case .KEYBOARD;
            if event.key_pressed {
                if event.key_code == {
                    case .ESCAPE;   deactivate_finder(); return;
                    case #char "B"; if only_ctrl_pressed(event.modifier_flags) { close_finder(); return; }
                    case #char "P"; if only_ctrl_pressed(event.modifier_flags) { show_open_file_dialog(); return; }
                }
                finder_handle_key_press(event.key_code, event.modifier_flags);
            }

        case .TEXT_INPUT;
            finder_handle_text_input(event.utf32);
    }
}

finder_handle_key_press :: (key_code: Input.Key_Code, mods: Mods) {
    using finder;

    handled := text_input_handle_keypress(*input, key_code, mods);
    if handled return;

    if key_code == {
        case #char "L"; if only_ctrl_shift_pressed(mods) toggle_enlarged();
        case .ENTER;    search_in_project(to_string(input.text));
    }

    // TODO: more handling later
}

finder_handle_text_input :: (char: u32) {
    if char == 127 return;  // there seems to be a bug in the Input module
                            // which generates a TEXT_INPUT event for DEL
                            // when Ctrl+Backspace is pressed

    text_input_type_char(*finder.input, char);
}

finder_is_open :: inline () -> bool {
    return finder.openness > 0;
}

finder_is_active :: inline () -> bool {
    return active_global_widget == .finder;
}

toggle_finder :: () {
    if finder_is_open() then close_finder(); else open_finder();
}

activate_finder :: inline () {
    active_global_widget = .finder;
}

deactivate_finder :: inline () {
    // Currently the only one other global widget available when the finder is open is the editors,
    // because open_file_dialog is modal and will close if finder opens.
    // If that changes we may have to change this code, too.
    active_global_widget = .editors;
}

open_finder :: () {
    using finder;

    activate_finder();

    // Select text when opening
    input.cursor.sel = 0;
    input.cursor.pos = get_num_chars(input.text);

    start_animation(*open_anim, openness, default_openness);
}

close_finder :: () {
    active_global_widget = .editors;

    start_animation(*finder.open_anim, finder.openness, 0);
}

finder_set_openness :: (value: float) {
    using finder;
    openness = clamp(value, 0, Finder.MAX_OPENNESS);;
    if openness < Finder.MIN_OPENNESS then openness = 0;  // fully close if too small
    open_anim.target = openness;
    if openness == 0 then deactivate_finder();
    default_openness = ifx openness > Finder.MIN_OPENNESS then openness else Finder.DEFAULT_OPENNESS;
}

maybe_animate_finder :: () {
    using finder;
    if finder.openness != open_anim.target {
        redraw_requested = true;
        finder.openness = get_animation_value(open_anim);
    }
}

finder: Finder;


#scope_file

search_in_project :: (needle: string) {
    if needle.count < 3 return;

    allocator := get_pool_allocator();
    push_allocator(allocator);

    array_reset(*finder.search_results);

    reset(*memory_pool);  // to avoid having to free each search result

    all_files: [..] File_Info;  // will be allocated from pool, no need to free

    // @Speed: probably can be sped up by not collecting everything upfront
    // and just scheduling search as we go (it takes 10ms on my machine to scan everything)
    // Also as an alternative could check out the code in count_lines_in_tree.jai,
    // maybe the code it uses to read dir entries is faster
    collect_files(project_dirs, dst = *all_files);

    queue := File_Async.initialize_queue(File_Info);
    defer File_Async.destroy_queue(queue);

    files_left_to_read := all_files.count;
    skip_table := bmh_prepare_skip_table(needle);

    for file : all_files {
        result := File_Async.read_entire_file(queue, file.full_path, file);
        if result.code == .FullQueue {
            file_info, data, success := File_Async.wait_for_completion(queue);
            if success.code == .Success {
                files_left_to_read -= 1;
                search_in_file(file_info, to_string(data), needle, skip_table);
            } else {
                log_error("Error while waiting for completion: %\n", success);
                files_left_to_read = 0;
                break;
            }
            result = File_Async.read_entire_file(queue, file.full_path, file);
        }
        if result.code != .Success {
            log_error("Error while trying to read file % asynchronously: %\n", file.full_path, result);
            files_left_to_read = 0;
            break;
        }
    }

    for 1 .. files_left_to_read {
        file_info, data, success := File_Async.wait_for_completion(queue);
        if success.code == .Success {
            search_in_file(file_info, to_string(data), needle, skip_table);
        } else {
            log_error("Error while waiting for completion: %\n", success);
            break;
        }
    }

    // for result : finder.search_results {
    //     print("% =======================\n", result.file.full_path);
    //     for line : result.lines {
    //         print("  %\n", line);
    //     }
    //     print("\n");
    // }
}

search_in_file :: (file: File_Info, contents: string, needle: string, skip_table: [] s32) {
    lines: [..] string;

    file_end := contents.data + contents.count;
    offset := 0;
    while true {
        offset = inline bmh_find_index_from_left(contents, needle, start_index = offset, skip_table);
        if offset < 0 break;

        // Expand to newlines
        line := slice(contents, offset, needle.count);
        while line.data > contents.data && <<(line.data - 1) != #char "\n" {
            line.data  -= 1;
            line.count += 1;
        }
        end := line.data + line.count;
        while end < file_end && <<end != #char "\n" {
            end += 1;
        }
        line.count = end - line.data;

        array_add(*lines, line);

        offset += needle.count;
    }

    if lines.count > 0 {
        result := array_add(*finder.search_results);
        result.file = file;
        result.lines = xx lines;
    }
}

toggle_enlarged :: () {
    using finder;
    if values_are_close(openness, Finder.ENLARGED_OPENNESS) || openness > Finder.ENLARGED_OPENNESS {
        // Shrink
        start_animation(*open_anim, openness, Finder.DEFAULT_OPENNESS);
    } else {
        // Enlarge
        start_animation(*open_anim, openness, Finder.ENLARGED_OPENNESS);
    }
}

Finder :: struct {
    openness: float = 0;  // percentage of window width. Zero means it's hidden
    input: Text_Input;

    search_results: [..] Search_Result;

    open_anim: Tween_Animation(float);

    default_openness := 0.2;  // if the user drags it then we remember it

    MIN_OPENNESS      :: 0.005;
    MAX_OPENNESS      :: 0.8;
    DEFAULT_OPENNESS  :: 0.2;
    ENLARGED_OPENNESS :: 0.5;
}

Search_Result :: struct {
    file: File_Info;
    lines: [] string;  // TODO: add highlight info
    // TODO: add line number
}

get_pool_allocator :: () -> Allocator {
    a: Allocator;
    a.proc = flat_pool_allocator_proc;
    a.data = *memory_pool;
    return a;
}

memory_pool: Flat_Pool;

#scope_file

File_Async :: #import "File_Async";
