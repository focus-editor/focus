apply_fonts :: (style: Style) {
    load_and_replace_font(*loaded_fonts.main,           style.font,                .main);
    load_and_replace_font(*loaded_fonts.ui,             style.font_ui,             .ui);
    load_and_replace_font(*loaded_fonts.ui_bold,        style.font_ui_bold,        .ui_bold);
    load_and_replace_font(*loaded_fonts.ui_bold_italic, style.font_ui_bold_italic, .ui_bold_italic);
}

find_font_by_name :: (name: string) -> path: string, error_msg: string /* temp */ {
    if name == "default" return "default", "";

    has_extension := ends_with_nocase(name, ".ttf") || ends_with_nocase(name, ".otf");

    try_path :: (font_path: string) #expand {
        if file_exists(font_path) {
            absolute_path, ok := get_absolute_path(font_path,, temp);
            if ok {
                path_overwrite_separators(absolute_path, #char "/");
                `return absolute_path, "";
            }
        }
        array_add(*tried_paths, font_path);
    }

    tried_paths: [..] string;
    tried_paths.allocator = temp;

    try_path(name);

    try_path(tprint("%/%", data_dir, name));
    if !has_extension {
        try_path(tprint("%/%.ttf", data_dir, name));
        try_path(tprint("%/%.otf", data_dir, name));
    }

    // Try to look it up in system fonts
    fonts_dir := platform_get_fonts_dir();

    try_path(tprint("%/%", fonts_dir, name));
    if !has_extension {
        try_path(tprint("%/%.ttf", fonts_dir, name));
        try_path(tprint("%/%.otf", fonts_dir, name));
    }

    if ! #compile_time {
        found, path := platform_find_font_by_name(name);
        if found then try_path(path);
    }

    error_msg := tprint("Couldn't find font '%'.\n\nTried the following locations:\n - %\n\nPlease note that you can specify a full path to the desired font file.", name, join(..tried_paths, "\n - ",, allocator = temp));
    return "", error_msg;
}

refresh_fonts :: () {
    push_allocator(focus_allocator);  // we sometimes call this from within a temp allocator

    style := context.config.style;

    Simp.set_anti_aliasing(style.font_anti_aliasing);
    Simp.set_hinting(style.font_hinting);

    common_icons: String_Builder;
    common_icons.allocator = temp;
    for enum_values_as_enum(Icon) {
        char := convert_utf32_to_utf8(xx it);
        append(*common_icons, to_string(*char));
    }
    append(*common_icons, PEN_ICON);
    append(*common_icons, XMARK_ICON);
    icons_string := builder_to_string(*common_icons,, allocator = temp);

    for description : FONT_ROLES {
        source: Loaded_Font;
        if #complete description.source == {
            case .main;           source = loaded_fonts.main;
            case .ui;             source = loaded_fonts.ui;
            case .ui_bold;        source = loaded_fonts.ui_bold;
            case .ui_bold_italic; source = loaded_fonts.ui_bold_italic;
            case .icons;          source = FONT_ICONS;
        }

        base_size := ifx description.source == .main then style.font_size else style.font_ui_size;
        pixel_size := font_pixel_size(base_size + description.size_offset + font_zoom_steps);
        font := Simp.get_font_at_size(source.name, source.data, pixel_size);
        assert(font != null, "Couldn't init font for role '%' at % pixels\n", description.role, pixel_size);
        sized_fonts[xx description.role] = font;

        // Warm every role's atlas to avoid repeated texture uploads during drawing.
        Simp.prepare_text(font, ifx description.source == .icons then icons_string else COMMON_CHARS);
    }

}

get_font_line_height :: inline (role: Font_Role) -> float {
    return cast(float) get_font(role).default_line_spacing;
}

get_char_size :: inline () -> float {
    return cast(float) get_font(.editor).em_width;
}

get_char_x_advance :: inline () -> float {
    return cast(float) get_font(.editor).x_advance;
}

get_line_height :: inline () -> float {
    return floor(get_font_line_height(.editor) * cast(float) context.config.settings.line_height_scale_percent / 100.0);
}

get_scrollbar_width :: inline () -> float {
    return floor(1.5 * get_char_size()) * context.config.settings.scrollbar_width_scale;
}

get_rounding_radius :: inline () -> float {
    return floor(get_char_size() / 2);
}

get_rounding_radius_large :: inline () -> float {
    return floor(get_char_size() / 1.5);
}

get_rounding_radius_small :: inline () -> float {
    return floor(get_char_size() / 3);
}

get_status_bar_height :: inline () -> float {
    return get_font_line_height(.ui) * 1.6;
}

adjust_zoom :: (delta: int) {
    min_zoom := MIN_FONT_SIZE - context.config.style.font_size;
    max_zoom := MAX_FONT_SIZE - context.config.style.font_size;

    new_zoom := clamp(font_zoom_steps + delta, min_zoom, max_zoom);
    if new_zoom == font_zoom_steps return;

    font_zoom_steps = new_zoom;
    refresh_fonts();
}

zoom_in :: () {
    adjust_zoom(1);
}

zoom_out :: () {
    adjust_zoom(-1);
}

reset_zoom :: () {
    font_zoom_steps = 0;
    refresh_fonts();
}

Loaded_Font :: struct {
    name: string;
    data: string;
}

PEN_ICON            :: #run to_string(*convert_utf32_to_utf8(0xf304));
CASE_SENSITIVE_ICON :: #run to_string(*convert_utf32_to_utf8(0xf031));
WHOLE_WORD_ICON     :: #run to_string(*convert_utf32_to_utf8(0xe4ba));
REGEX_SEARCH_ICON   :: #run to_string(*convert_utf32_to_utf8(0xf621));
BULLET_ICON         :: #run to_string(*convert_utf32_to_utf8(0x2022));
XMARK_ICON          :: #run to_string(*convert_utf32_to_utf8(0xf057));

Font_Role :: enum {
    editor;
    ui;
    ui_bold;
    ui_bold_italic;
    ui_big;
    ui_medium;
    ui_small;
    ui_very_small;
    icons;
    icons_small;
    icons_very_small;
}

get_font :: inline (role: Font_Role) -> *Simp.Dynamic_Font {
    return sized_fonts[xx role];
}

DEFAULT_FONT_MAIN_SIZE             :: 14;
DEFAULT_FONT_UI_SIZE               :: 15;
DEFAULT_FONT_UI_BIG_SIZE           :: 28;
DEFAULT_FONT_UI_MEDIUM_SIZE        :: 18;
DEFAULT_FONT_UI_SMALL_SIZE         :: 14;
DEFAULT_FONT_UI_VERY_SMALL_SIZE    :: 12;
DEFAULT_FONT_ICONS_SIZE            :: 16;
DEFAULT_FONT_ICONS_SMALL_SIZE      :: 12;
DEFAULT_FONT_ICONS_VERY_SMALL_SIZE :: 8;

MIN_FONT_SIZE :: 4;
MAX_FONT_SIZE :: 90;

loaded_fonts: struct {
    main:           Loaded_Font = FONT_MAIN;
    ui:             Loaded_Font = FONT_UI;
    ui_bold:        Loaded_Font = FONT_UI_BOLD;
    ui_bold_italic: Loaded_Font = FONT_UI_BOLD_ITALIC;
};

// Tracks temporary zoom
font_zoom_steps := 0;

// Embed default fonts
FONT_MAIN           :: #run load_font("FiraCode-Retina.ttf");
FONT_UI             :: #run load_font("OpenSans-Regular.ttf");
FONT_UI_BOLD        :: #run load_font("OpenSans-SemiBold.ttf");
FONT_UI_BOLD_ITALIC :: #run load_font("OpenSans-SemiBoldItalic.ttf");
FONT_ICONS          :: #run load_font("font-awesome/Font Awesome 6 Free-Solid-900.otf");

#scope_file

Font_Kind :: enum {
    main;
    ui;
    ui_bold;
    ui_bold_italic;
}

load_and_replace_font :: (dst: *Loaded_Font, name: string, kind: Font_Kind) {
    loaded_font, success, error_msg := load_font_by_name(name, kind);
    if !success {
        add_user_error("%\nUsing the embedded default font for '%'.", error_msg, kind);
        loaded_font = load_font_by_name("default", kind);
    }
    dst.* = loaded_font;
}

load_font_by_name :: (name: string, kind: Font_Kind) -> Loaded_Font, success: bool, error_msg: string /* temp */ {
    if name == "default" {
        if #complete kind == {
            case .main;           return FONT_MAIN,           true, "";
            case .ui;             return FONT_UI,             true, "";
            case .ui_bold;        return FONT_UI_BOLD,        true, "";
            case .ui_bold_italic; return FONT_UI_BOLD_ITALIC, true, "";
        }
    }

    push_allocator(focus_allocator);  // FreeType borrows these bytes, so cached resources live for the process lifetime.

    font_path, error_msg := find_font_by_name(name);
    if !font_path return .{}, false, error_msg;

    found, cached_font := table_find(*font_cache, font_path);
    if found return cached_font, true, "";

    font_data, success := read_entire_file(font_path);
    if !success return .{}, false, tprint("Couldn't read font '%' from '%'.", name, font_path);

    owned_path := copy_string(font_path);
    loaded_font := Loaded_Font.{ name = owned_path, data = font_data };
    table_set(*font_cache, owned_path, loaded_font);
    return loaded_font, true, "";
}

font_cache: Table(string, Loaded_Font);  // absolute path -> loaded font

Font_Source :: enum {
    main;
    ui;
    ui_bold;
    ui_bold_italic;
    icons;
}

Font_Description :: struct {
    role: Font_Role;
    source: Font_Source;
    size_offset: int;
}

FONT_ROLES :: Font_Description.[
    .{ .editor,             .main,              0 },
    .{ .ui,                 .ui,                0 },
    .{ .ui_bold,            .ui_bold,           0 },
    .{ .ui_bold_italic,     .ui_bold_italic,    0 },
    .{ .ui_big,             .ui,                DEFAULT_FONT_UI_BIG_SIZE           - DEFAULT_FONT_UI_SIZE },
    .{ .ui_medium,          .ui,                DEFAULT_FONT_UI_MEDIUM_SIZE        - DEFAULT_FONT_UI_SIZE },
    .{ .ui_small,           .ui,                DEFAULT_FONT_UI_SMALL_SIZE         - DEFAULT_FONT_UI_SIZE },
    .{ .ui_very_small,      .ui,                DEFAULT_FONT_UI_VERY_SMALL_SIZE    - DEFAULT_FONT_UI_SIZE },
    .{ .icons,              .icons,             DEFAULT_FONT_ICONS_SIZE            - DEFAULT_FONT_UI_SIZE },
    .{ .icons_small,        .icons,             DEFAULT_FONT_ICONS_SMALL_SIZE      - DEFAULT_FONT_UI_SIZE },
    .{ .icons_very_small,   .icons,             DEFAULT_FONT_ICONS_VERY_SMALL_SIZE - DEFAULT_FONT_UI_SIZE },
];

NUM_FONT_ROLES :: #run enum_highest_value(Font_Role) + 1;
#assert FONT_ROLES.count == NUM_FONT_ROLES;

sized_fonts: [NUM_FONT_ROLES] *Simp.Dynamic_Font;

font_pixel_size :: (logical_size: int) -> int {
    size := clamp(logical_size, MIN_FONT_SIZE, MAX_FONT_SIZE);
    return max(1, cast(int) (size * dpi_scale));
}

COMMON_CHARS :: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789… ~!@#$%^&*()-|\"':;_+={}[]\\/`,.<>?АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧЩЪЫЬЭЮЯабвгдеёжзийклмнопрстуфхцчщъыьэюя¶•\t\n—–‘’“”«»";

load_font :: (name: string) -> Loaded_Font {
    path := tprint("fonts/%", name);
    data, success := read_entire_file(path);
    assert(success, "Couldn't load font '%'", path);

    return Loaded_Font.{ name = sprint("builtin:%", name), data = data };
}

