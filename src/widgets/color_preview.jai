init_color_preview :: () {
    // Init the panel buffer
    assert(panel_buffer_id < 0, "Code helper panel already has a buffer. This is a bug");
    panel_buffer_id = find_or_create_an_empty_buffer();
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

    if config.settings.color_preview_popup != .enabled then color_preview_is_shown = false;
}

deinit_color_preview :: () {
    // Assuming that the editor and the buffer will be cleaned up separately
    panel_buffer_id = -1;
    panel_editor_id = -1;

    target_editor_id = -1;
    target_buffer_id = -1;
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

color_preview_get_target_buffer_id :: inline () -> s64 {
    return target_buffer_id;
}

color_preview_lose_focus :: () {
    // Sometimes we might want to make the previously active editor active, e.g. when deciding on new buffer placement
    if editors.active != editors.left && editors.active != editors.right && editors.left >= 0 && editors.right >= 0 {
        // If we still have the same editors open when the panel was opened, go back to the previously active one,
        // otherwise default to left.
        make_editor_active(ifx target_editor_id == editors.right then editors.right else editors.left);
    }
}

color_preview_set_height :: (height: float) {
    height = clamp(height, 0.1, 1.0);
    color_preview_height = height;
}

color_preview_set_width :: (width: float) {
    color_preview_width = clamp(width, 0.1, 1.0);
}

color_preview_get_position :: () -> Panel_Position {
    if #complete editors.layout == {
        case .None;     saved_position = .right;
        case .Single;   saved_position = .right;
        case .Double;   if editor_closing_id >= 0 then saved_position = .right;
                        else if editors.active == editors.left  then saved_position = .right;
                        else if editors.active == editors.right then saved_position = .left;
    }
    return saved_position;
}

color_preview_begin_draw :: (editor_id: s64) {
    Simp.immediate_flush();
    OLD_COLOR_MAP = COLOR_MAP;

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

    // Override the colors temporarily
    // Try to build it up as it would when the config is actually loaded
    reset_color_map_to_default();

    if config.style.theme && !is_current_theme(buffer.file.full_path) {
        color_preview_warning = tprint("There is an active theme '%'. Colors from this config are not applied.", config.style.theme);
        if config.style.theme != "default" {
            color_preview_warning = tprint("% You can edit the theme using the 'Edit Current Theme' command.", color_preview_warning);
        }
    }

    if is_current_global_config(buffer.file.full_path) {
        // Apply the colors we're editing
        apply_parsed_colors(config_extra.parsed_colors);

        // Apply the colors from the current project, if any
        if project_config.loaded && project_config.parsed_config.colors {
            apply_parsed_colors(project_config.parsed_config.colors);
            color_preview_warning = "An active project config is overriding the colors from the config you are editing. Your changes may not be visible.";
        }
    } else if is_current_project_config(buffer.file.full_path) {
        // Apply the existing global config first
        assert(global_config.loaded);
        apply_parsed_colors(global_config.parsed_config.colors);

        // Then apply our stuff on top
        apply_parsed_colors(config_extra.parsed_colors);

    } else if is_current_theme(buffer.file.full_path) {
        // Themes are supposed to override everything, so apply on top of default
        apply_parsed_colors(config_extra.parsed_colors);
    } else {
        // This is not an active config or theme. Apply our stuff on top of the default config but show a warning
        apply_parsed_colors(config_extra.parsed_colors);
        if buffer.lang == {
            case .Focus_Config;  color_preview_warning = "The current config is not active, so no changes will be applied when you save the file.";
            case .Focus_Theme;   color_preview_warning = "The current theme is not active, so no changes will be applied when you save the file.";
        }
    }
}

color_preview_end_draw :: () {
    Simp.immediate_flush();
    COLOR_MAP = OLD_COLOR_MAP;
}

color_preview_set_language :: (lang_id: int) {
    selected_language_id = lang_id;

    editor, buffer := *open_editors[panel_editor_id], *open_buffers[panel_buffer_id];
    buffer.lang = languages[lang_id].lang;

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

    on_left := saved_position == .left;
    draw_color_picker(target_editor_id, editor, buffer, rect, .{color_start, color_end}, on_left);
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
    editor.cursor_moved = .jumped;
    editor.scroll_to_cursor = .yes;
}

color_preview_is_shown := true;

color_preview_width:  float = 0.5;
color_preview_height: float = 0.7;


#scope_file

get_language_sample_text :: (lang: Buffer.Lang) -> string {
    if #complete lang == {
        case .Jai;               return SAMPLE_Jai;
        case .C;                 return SAMPLE_C;
        case .Cpp;               return SAMPLE_Cpp;
        case .Css;               return SAMPLE_Css;
        case .CSharp;            return SAMPLE_CSharp;
        case .D;                 return SAMPLE_D;
        case .Glsl;              return SAMPLE_Glsl;
        case .Hlsl;              return SAMPLE_Hlsl;
        case .Golang;            return SAMPLE_Golang;
        case .Js;                return SAMPLE_Js;
        case .Json;              return SAMPLE_Json;
        case .Lua;               return SAMPLE_Lua;
        case .Odin;              return SAMPLE_Odin;
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

saved_position := Panel_Position.right;

color_preview_warning: string;

Panel_Position :: enum { left; right; }

OLD_COLOR_MAP: [COLOR_MAP_SIZE] Vector4;

#load "color_preview_samples.jai";

