init_color_preview :: () {
    // Init the panel buffer
    assert(panel_buffer_id < 0, "Code helper panel already has a buffer. This is a bug");
    panel_buffer_id = create_an_empty_buffer();
    panel_editor_id = find_or_create_editor(panel_buffer_id);
    buffer := *open_buffers[panel_buffer_id];
    buffer.internal = true;

    // Collect stats on most used languages in the workspace
    array_resize(*languages, NUM_LANGUAGES, initialize = true);
    for enum_values_as_enum(Buffer.Lang) {
        language := *languages[xx it];

        language.lang = it;
        language.num_buffers = 0;

        if language.name then free(language.name);
        language.name = sprint("%", it);
        replace_chars(language.name, "_", xx #char " ");
    }
    for open_buffers {
        languages[xx it.lang].num_buffers += 1;
    }
    for * languages {
        if it.lang == {
            case .Plain_Text;           #through;
            case .Focus_Config;         #through;
            case .Focus_Theme;          #through;
            case .Focus_Build_Panel;
                remove it;
        }
    }
    compare_languages :: (a: Color_Preview_Language, b: Color_Preview_Language) -> s64 {
        usage_diff := b.num_buffers - a.num_buffers;
        if usage_diff != 0 return usage_diff;
        return compare_strings(a.name, b.name);
    }
    quick_sort(languages, compare_languages);

    color_preview_set_language(0);

    if context.config.settings.color_preview_popup != .enabled then color_preview_is_shown = false;
}

deinit_color_preview :: () {
    // Assuming that the editor and the buffer will be cleaned up separately
    panel_buffer_id = -1;
    panel_editor_id = -1;

    target_editor_id = -1;
    target_buffer_id = -1;

    free(preview_theme_path,, focus_allocator);
    preview_theme_path = "";
    array_free(preview_theme_colors);
    preview_theme_valid = false;
}

show_color_preview :: () {
    color_preview_is_shown = true;
}

hide_color_preview :: () {
    color_preview_lose_focus();
    color_preview_is_shown = false;
}

is_color_preview_panel :: inline (editor_id: s64) -> bool {
    return editor_id == panel_editor_id;
}

color_preview_lose_focus :: () {
    activate_editors();
}

color_preview_set_height :: (height: float) {
    height = clamp(height, 0.1, 1.0);
    color_preview_height = height;
}

color_preview_set_width :: (width: float) {
    color_preview_width = clamp(width, 0.1, 1.0);
}

color_preview_invalidate_theme :: (path: string) {
    if preview_theme_path && platform_path_equals(path, preview_theme_path) {
        preview_theme_valid = false;
    }
}

color_preview_begin_draw :: (editor_id: s64) {
    Simp.immediate_flush();
    previous_color_map = COLOR_MAP;

    color_preview_warning = "";  // reset warning

    if !is_color_preview_panel(editor_id) {  // we could be focusing on the widget itself
        target_editor := *open_editors[editor_id];
        target_editor_id = editor_id;
        target_buffer_id = target_editor.buffer_id;  // remember the buffer we're targeting
    } else {
        if target_buffer_id < 0 return;  // shouldn't happen
    }

    buffer := *open_buffers[target_buffer_id];
    if !buffer.has_file || buffer.readonly return;

    config_extra := cast(*Focus_Config_Extra) buffer.extra;
    if !config_extra return;

    push_allocator(temp);

    edited: Parsed_Config;
    array_add(*edited.colors, ..config_extra.parsed_colors);
    if buffer.lang == .Focus_Config && config_extra.active_theme {
        colors, success := color_preview_get_theme_colors(config_extra.active_theme);
        if success {
            edited.theme = config_extra.active_theme;
            edited.colors.count = 0;
            array_add(*edited.colors, ..colors);
            color_preview_warning = tprint("Theme '%' is selected in this config. Its inline colors are not applied.", edited.theme);
        }
    }

    style := DEFAULT_CONFIG.style;
    active_config := is_our_config_file(buffer.file.full_path);
    active_theme := buffer.lang == .Focus_Theme && is_config_theme_dependency(buffer.file.full_path);
    if active_config || active_theme {
        if global_config.loaded {
            parsed := global_config.parsed_config;
            if is_current_global_config(buffer.file.full_path) {
                parsed = edited;
            } else if active_theme && platform_path_equals(buffer.file.full_path, global_config.theme_path) {
                parsed.colors = edited.colors;
            }
            merge_style(*style, parsed);
        }
        if project_config.loaded {
            parsed := project_config.parsed_config;
            if is_current_project_config(buffer.file.full_path) {
                parsed = edited;
            } else if active_theme && platform_path_equals(buffer.file.full_path, project_config.theme_path) {
                parsed.colors = edited.colors;
            }
            merge_style(*style, parsed);
            if is_current_global_config(buffer.file.full_path) && parsed.colors.count && !edited.theme {
                color_preview_warning = "An active project config overrides some colors. Your changes may not be visible.";
            }
        }
    } else {
        merge_style(*style, edited);
        color_preview_warning = "This config or theme is not active. Its colors are previewed against defaults and will not be applied when you save.";
    }
    COLOR_MAP = style.colors;
}

color_preview_end_draw :: () {
    Simp.immediate_flush();
    COLOR_MAP = previous_color_map;
}

color_preview_set_language :: (lang_id: int) {
    selected_language_id = lang_id;

    editor, buffer := *open_editors[panel_editor_id], *open_buffers[panel_buffer_id];
    set_buffer_language(buffer, languages[lang_id].lang);

    close_search_bar(editor);
    reset_search_results(*editor.search_bar);
    reset_keeping_memory(*buffer.undos);
    reset_keeping_memory(*buffer.redos);
    reset_keeping_memory(*editor.highlights);

    sample_text := get_language_sample_text(buffer.lang);
    replace_range_raw(buffer, 0, xx buffer.bytes.count, sample_text);
    rescan_for_lines(buffer);
    if editor.line_wrap == .on then rescan_for_wrapped_lines(editor, buffer);

    cursor := leave_only_original_cursor(editor);
    cursor.pos = 0;
    cursor.sel = 0;

    snap_viewport_top_to_target(editor, buffer, 0);
    snap_viewport_left_to_target(editor, 0);
}

color_preview_get_languages :: () -> [] string /* temp */, selected: int {
    lang_names: [..] string;
    lang_names.allocator = temp;

    for languages  array_add(*lang_names, it.name);

    return lang_names, selected_language_id;
}

color_preview_get_warning :: () -> string {
    return color_preview_warning;
}

color_preview_get_editor_id :: inline () -> s64 {
    if panel_editor_id < 0 then init_color_preview();
    return panel_editor_id;
}

color_preview_draw_color_picker :: (rect: Rect) {
    if target_editor_id < 0 || target_buffer_id < 0 return;

    editor := *open_editors[target_editor_id];
    buffer := *open_buffers[target_buffer_id];
    assert(buffer.lang == .Focus_Config || buffer.lang == .Focus_Theme);

    offset := editor.cursors[editor.main_cursor].pos;
    if offset > buffer.bytes.count - 1  offset = cast(s32)buffer.bytes.count - 1;
    using config_extra := cast(*Focus_Config_Extra) buffer.extra;
    if (colors_section_start < 0 || offset < colors_section_start) || (colors_section_end >= 0 && offset >= colors_section_end) return;

    // Try and find a color hex value on the cursor line.
    // Go to start of line, go forward to colon, go forward past whitespace, check value.

    if buffer.bytes[offset] == #char "\n" then offset -= 1;

    while buffer.bytes[offset] != #char "\n" {
        offset -= 1;
        if offset <= colors_section_start return;
    }

    while is_unicode_space(buffer.bytes[offset]) {
        offset += 1;
        if offset >= buffer.bytes.count || buffer.bytes[offset] == #char "\n" return;
    }

    if buffer.bytes[offset] == #char "#" return;

    while buffer.bytes[offset] != #char ":" {
        offset += 1;
        if offset >= buffer.bytes.count || buffer.bytes[offset] == #char "\n" return;
    }

    offset += 1;

    if offset >= buffer.bytes.count return;

    while is_unicode_space(buffer.bytes[offset]) {
        offset += 1;
        if offset >= buffer.bytes.count || buffer.bytes[offset] == #char "\n" return;
    }

    color_start := offset;
    offset += 1;
    while offset < buffer.bytes.count && is_hex(buffer.bytes[offset]) {
        offset += 1;
        if offset - color_start > 8 return;
    }

    color_end := offset;
    count := color_end - color_start;
    if count != 6 && count != 8 return;

    draw_color_picker(target_editor_id, editor, buffer, rect, .{color_start, color_end});
}

color_preview_jump_to_color_name :: (color_name: string) {
    assert(target_editor_id >= 0 && target_buffer_id >= 0);
    editor := *open_editors[target_editor_id];
    buffer := *open_buffers[target_buffer_id];
    assert(buffer.lang == .Focus_Config || buffer.lang == .Focus_Theme);

    offset := parse_config_and_get_offset_of_color_value(buffer, color_name);
    if offset < 0 {
        clear_user_messages(.config);
        add_user_warning("Color '%' is not found in config", color_name, tag = .config, dismiss_in_seconds = 5);
        return;
    }

    cursor := leave_only_original_cursor(editor);
    cursor.pos = cast(s32) offset;
    cursor.sel = cursor.pos;
    add_paste_animation(target_editor_id, get_real_line_range(buffer, offset_to_real_line(buffer, cursor.pos)));
    editor.cursor_moved = true;
    editor.scroll_to_cursor = .yes;
}

color_preview_is_shown := true;

color_preview_width:  float = 0.5;
color_preview_height: float = 0.7;

color_preview_scroll_y_anim := #run Tween_Animation(s32).{ duration = 0.1, func = .lerp };
color_preview_scroll_y : s32;

#scope_file

color_preview_get_theme_colors :: (name: string) -> [] Parsed_Color, bool {
    if global_config.loaded && global_config.parsed_config.theme == name {
        return global_config.parsed_config.colors, true;
    }
    if project_config.loaded && project_config.parsed_config.theme == name {
        return project_config.parsed_config.colors, true;
    }

    path := get_theme_path_from_name(name);
    if !preview_theme_valid || !platform_path_equals(path, preview_theme_path) {
        push_allocator(focus_allocator);
        free(preview_theme_path);
        preview_theme_path = copy_string(path);
        array_free(preview_theme_colors);
        preview_theme_valid = true;
        preview_theme_success = false;

        if name != "default" then start_watching_file_if_not_already(path);
        result := load_theme(name, save_migration = false,, temp);
        if result.success {
            preview_theme_colors = array_copy(result.config.colors);
            preview_theme_success = true;
        } else {
            add_user_error(result.error_msg, tag = .config);
        }
    }
    return preview_theme_colors, preview_theme_success;
}

previous_color_map: [COLOR_MAP_SIZE] Vector4;
preview_theme_path: string;
preview_theme_colors: [] Parsed_Color;
preview_theme_valid: bool;
preview_theme_success: bool;

get_language_sample_text :: (lang: Buffer.Lang) -> string {
    if #complete lang == {
        case .Jai;               return SAMPLE_Jai;
        case .C;                 return SAMPLE_C;
        case .Cpp;               return SAMPLE_Cpp;
        case .Css;               return SAMPLE_Css;
        case .CSharp;            return SAMPLE_CSharp;
        case .D;                 return SAMPLE_D;
        case .Dart;              return SAMPLE_Dart;
        case .Diff;              return SAMPLE_Diff;
        case .Glsl;              return SAMPLE_Glsl;
        case .Hlsl;              return SAMPLE_Hlsl;
        case .Golang;            return SAMPLE_Golang;
        case .Java;              return SAMPLE_Java;
        case .Js;                return SAMPLE_Js;
        case .Json;              return SAMPLE_Json;
        case .Toml;              return SAMPLE_Toml;
        case .Lua;               return SAMPLE_Lua;
        case .Luau;              return SAMPLE_Luau;
        case .Odin;              return SAMPLE_Odin;
        case .Powershell;        return SAMPLE_Powershell;
        case .Python;            return SAMPLE_Python;
        case .RenPy;             return SAMPLE_RenPy;
        case .Rust;              return SAMPLE_Rust;
        case .Xml;               return SAMPLE_Xml;
        case .Html;              return SAMPLE_Html;
        case .Todo;              return SAMPLE_Todo;
        case .Yang;              return SAMPLE_Yang;
        case .Zig;               return SAMPLE_Zig;
        case .Uxntal;            return SAMPLE_Uxntal;
        case .Markdown;          return SAMPLE_Markdown;
        case .Batch;             return SAMPLE_Batch;
        case .Swift;             return SAMPLE_Swift;
        case .Shell;             return SAMPLE_Shell;
        case .Ini;               return SAMPLE_Ini;
        case .Vue;               return SAMPLE_Vue;

        case .Plain_Text;        #through;
        case .Focus_Config;      #through;
        case .Focus_Theme;       #through;
        case .Focus_Build_Panel;
            panic("Attempted to get a sample for an unsupported buffer language %. This is a bug.", lang);
    }
    return "";
}

parse_config_and_get_offset_of_color_value :: (buffer: Buffer, color_name: string) -> offset: s32 {
    // Do some very superficial parsing, not super robust but better than plain search
    handler: Text_File_Handler;
    trimmed_data := trim_left(to_string(buffer.bytes), " \t\n\r");  // skip empty lines, otherwise the handler will crash!
    start_from_memory(*handler, "colors", "colors", trimmed_data);
    if handler.failed return -1;

    colors_section := false;

    while true {
        line, found := consume_next_line(*handler);
        if !found break;

        if begins_with(line, "[[") && ends_with(line, "]]") {
            colors_section = false;
        } else if begins_with(line, "[") && ends_with(line, "]") {
            if equal_nocase(trim(line, " \t[]"), "colors") {
                colors_section = true;
            } else {
                colors_section = false;
            }
        }
        if !colors_section continue;

        color, value := break_by_spaces(line);
        color = trim_right(color, ":");

        if equal_nocase(color, color_name)  return cast(s32) (value.data - buffer.bytes.data);
    }

    return -1;
}

// The ids of the editor and buffer with the color section which triggered the widget
target_editor_id := -1;
target_buffer_id := -1;
selected_language_id := 0;

NUM_LANGUAGES :: #run enum_highest_value(Buffer.Lang) + 1;
languages: [..] Color_Preview_Language;

Color_Preview_Language :: struct {
    lang: Buffer.Lang;
    num_buffers: s32;  // the number of buffers in the current workspace which use it
    name: string;
}

panel_buffer_id := -1;
panel_editor_id := -1;

color_preview_warning: string;

#load "color_preview_samples.jai";

