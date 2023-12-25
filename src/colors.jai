Color :: enum u8 {
    CODE_DEFAULT;
    CODE_COMMENT;
    CODE_TYPE;
    CODE_FUNCTION;
    CODE_PUNCTUATION;
    CODE_OPERATION;
    CODE_STRING;
    CODE_VALUE;
    CODE_HIGHLIGHT;
    CODE_ERROR;
    CODE_WARNING;
    CODE_KEYWORD;

    BACKGROUND_0;
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
    LETTER_HIGHLIGHT;
    LIST_CURSOR_LITE;
    LIST_CURSOR;
    SHADOW_DARK;
    SHADOW_TRANSPARENT;
    TEXT_INPUT_LABEL;
    CHAR_UNDER_CURSOR;

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

    BUILD_PANEL_BACKGROUND;
    BUILD_PANEL_SCROLLBAR;
    BUILD_PANEL_SCROLLBAR_HOVER;
    BUILD_PANEL_SCROLLBAR_BACKGROUND;
    BUILD_PANEL_TITLE_BAR;

    NONE;
};

// Will be populated when parsing config
COLOR_MAP: [NUM_COLORS] Vector4;

// Will contain the color map of the default config (useful when merging configs)
#no_reset DEFAULT_COLOR_MAP: [NUM_COLORS] Vector4;

map_color_to_vec4 :: inline (color: Color) -> Vector4 {
    return COLOR_MAP[cast(s64) color];
}

color_as_3_floats :: (color: Color) -> [3] float {
    c := map_color_to_vec4(color);
    return .[c.x, c.y, c.z];
}

#scope_file

NUM_COLORS :: #run enum_highest_value(Color) + 1;
