Color :: enum u8 {
    CODE_DEFAULT :: 0;  // must be first

    // ...
    // The space between CODE_DEFAULT and BACKGROUND_0 is reserved for the code colors,
    // which are defined by the Token_Type enum.
    // ...

    BACKGROUND_0 :: #run enum_highest_value(Token_Type) + 1;
    BACKGROUND_1;
    BACKGROUND_2;
    BACKGROUND_3;
    BACKGROUND_4;
    SELECTION_ACTIVE;
    SELECTION_INACTIVE;
    SELECTION_HIGHLIGHT;
    SEARCH_RESULT_ACTIVE;
    SEARCH_RESULT_INACTIVE;
    SCROLLBAR;
    SCROLLBAR_HOVER;
    SCROLLBAR_BACKGROUND;
    CURSOR;
    CURSOR_INACTIVE;
    PASTE_ANIMATION;
    SPLITTER;
    SPLITTER_HOVER;
    RULER;
    INDENT_GUIDE;
    LETTER_HIGHLIGHT;
    LIST_CURSOR_LITE;
    LIST_CURSOR;
    SHADOW_DARK;
    SHADOW_TRANSPARENT;
    TEXT_INPUT_LABEL;
    CHAR_UNDER_CURSOR;
    BRACKET_HIGHLIGHT;
    ACTIVE_PANE_BORDER;
    INACTIVE_PANE_DIM_OVERLAY;

    UI_DEFAULT;
    UI_DIM;
    UI_NEUTRAL;
    UI_WARNING;
    UI_WARNING_DIM;
    UI_ERROR;
    UI_ERROR_BRIGHT;
    UI_SUCCESS;

    REGION_SCOPE_EXPORT;
    REGION_SCOPE_FILE;
    REGION_SCOPE_MODULE;
    REGION_HEADER;
    REGION_SUCCESS;
    REGION_WARNING;
    REGION_ERROR;
    REGION_HEREDOC;

    BUILD_PANEL_BACKGROUND;
    BUILD_PANEL_SCROLLBAR;
    BUILD_PANEL_SCROLLBAR_HOVER;
    BUILD_PANEL_SCROLLBAR_BACKGROUND;
    BUILD_PANEL_TITLE_BAR;

    NONE;
};

// Will be populated when parsing config
COLOR_MAP: [COLOR_MAP_SIZE] Vector4;

// Will contain the color map of the default config (useful when merging configs)
#no_reset DEFAULT_COLOR_MAP: [COLOR_MAP_SIZE] Vector4;

map_color_to_vec4 :: inline (color: Color) -> Vector4 {
    return COLOR_MAP[cast(s64) color];
}

color_as_3_floats :: (color: Color) -> [3] float {
    c := map_color_to_vec4(color);
    return .[c.x, c.y, c.z];
}

COLOR_MAP_SIZE :: #run enum_highest_value(Color) + 1;
