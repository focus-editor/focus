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

search_in_project :: (text: string) {
    if !text return;
    // Single-threaded for now
    // Visit all files in projects
    // Read each file asynchronously and add its name to the results
    // Draw results

    allocator := get_pool_allocator();
    push_allocator(allocator);

    reset(*memory_pool);  // to avoid having to free each string

    all_files: [..] File_Info;
    defer array_reset(*all_files);

    visitor_data: File_Visit_Config = ---;
    // TODO: make this configurable
    visitor_data.ignore_folders = string.[".build", ".git", "bin"];
    visitor_data.allowed_files  = string.[".jai", ".md", ".c", ".h", ".cpp", ".txt"];
    visitor_data.files_dst = *all_files;

    for dir : project_dirs {
        visitor_data.proj_path_prefix_len = dir.path_prefix_len;
        visit_files(dir.path, recursive = true, visitor_data, file_collector_func, visit_directories = true);
    }

    for file : all_files {
        print("%\n", file);
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
}

get_pool_allocator :: () -> Allocator {
    a: Allocator;
    a.proc = flat_pool_allocator_proc;
    a.data = *memory_pool;
    return a;
}

memory_pool: Flat_Pool;
