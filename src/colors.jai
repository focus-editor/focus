Color :: struct {
    #as vec4 : Vector4 = ---;

    #place vec4;
    using components : struct { r, g, b, a : float = 1; };

    #place vec4;
    floats : [4] float = ---;
}

Color_Values :: struct {
    NONE :: Color.{ r = -1, g = -1, b = -1, a = -1 };  // an invalid color to denote no color


    BACKGROUND              := Color.{ r = 0.086, g = 0.133, b = 0.165 };
    BACKGROUND_DARK         := Color.{ r = 0.065, g = 0.101, b = 0.125 };
    BACKGROUND_HIGHLIGHT    := Color.{ r = 0.097, g = 0.15, b = 0.185 };
    BACKGROUND_LIGHT        := Color.{ r = 0.102, g = 0.158, b = 0.195 };
    BACKGROUND_BRIGHT       := Color.{ r = 0.131, g = 0.202, b = 0.25 };
    SELECTION_ACTIVE        := Color.{ r = 0.11, g = 0.267, b = 0.29 };
    SELECTION_INACTIVE      := Color.{ r = 0.11, g = 0.267, b = 0.29, a = 0.5 };
    SELECTION_HIGHLIGHT     := Color.{ r = 0.99, g = 0.93, b = 0.99, a = 0.15 };
    SEARCH_RESULT_ACTIVE    := Color.{ r = 0.559, g = 0.469, b = 0.184 };
    SEARCH_RESULT_INACTIVE  := Color.{ r = 0.99, g = 0.93, b = 0.99, a = 0.15 };
    SCROLLBAR               := Color.{ r = 0.20, g = 0.80, b = 0.80, a = 0.1 };
    SCROLLBAR_HOVER         := Color.{ r = 0.20, g = 0.80, b = 0.80, a = 0.3 };
    SCROLLBAR_BACKGROUND    := Color.{ r = 0.065, g = 0.101, b = 0.125, a = 0.3 };
    CURSOR                  := Color.{ r = 0.15, g = 0.7, b = 0.7 };
    CURSOR_INACTIVE         := Color.{ r = 0.10, g = 0.4, b = 0.4 };
    PASTE_ANIMATION         := Color.{ r = 0.11, g = 0.267, b = 0.29 };
    SPLITTER                := Color.{ r = 0.131, g = 0.202, b = 0.25 };
    SPLITTER_HOVER          := Color.{ r = 0.110, g = 0.267, b = 0.29 };
    LETTER_HIGHLIGHT        := Color.{ r = 0.35, g = 0.6, b = 0.6 };
    LIST_CURSOR_LITE        := Color.{ r = 0.20, g = 0.80, b = 0.80, a = 0.1 };  // @TODO: do without alpha?
    LIST_CURSOR             := Color.{ r = 0.20, g = 0.80, b = 0.80, a = 0.3 };
    SHADOW_DARK             := Color.{ r = 0.057, g = 0.089, b = 0.11, a = 0.5 };
    SHADOW_TRANSPARENT      := Color.{ r = 0.057, g = 0.089, b = 0.11, a = 0 };  // for interpolation
    TEXT_INPUT_LABEL        := Color.{ r = 0.233, g = 0.269, b = 0.316, a = 1.0 };

    UI_DEFAULT              := Color.{ r = 0.75, g = 0.79, b = 0.86, a = 1.0 };
    UI_DIM                  := Color.{ r = 0.533, g = 0.569, b = 0.616, a = 1.0 };
    UI_NEUTRAL              := Color.{ r = 0.3, g = 0.3, b = 0.3, a = 1.0 };
    UI_WARNING              := Color.{ r = 0.85, g = 0.68, b = 0.33, a = 1.0 };
    UI_WARNING_DIM          := Color.{ r = 0.59, g = 0.37, b = 0.19, a = 1.0 };
    UI_ERROR                := Color.{ r = 0.46, g = 0.13, b = 0.13, a = 1.0 };
    UI_ERROR_BRIGHT         := Color.{ r = 1.00, g = 0.00, b = 0.00, a = 1.0 };
    UI_SUCCESS              := Color.{ r = 0.00, g = 0.80, b = 0.00, a = 1.0 };

    CODE_DEFAULT            := Color.{ r = 0.75, g = 0.79, b = 0.86, a = 1.0 };
    CODE_COMMENT            := Color.{ r = 0.533, g = 0.569, b = 0.616, a = 1.0 };
    CODE_TYPE               := Color.{ r = 0.51, g = 0.67, b = 0.64, a = 1.0 };
    CODE_FUNCTION           := Color.{ r = 0.816, g = 0.776, b = 0.663, a = 1.0 };
    CODE_PUNCTUATION        := Color.{ r = 0.75, g = 0.79, b = 0.86, a = 1.0 };
    CODE_OPERATION          := Color.{ r = 0.88, g = 0.68, b = 0.51, a = 1.0 };
    CODE_STRING             := Color.{ r = 0.835, g = 0.74, b = 0.494, a = 1.0 };
    CODE_VALUE              := Color.{ r = 0.84, g = 0.60, b = 0.71, a = 1.0 };
    CODE_HIGHLIGHT          := Color.{ r = 0.85, g = 0.61, b = 0.46, a = 1.0 };
    CODE_ERROR              := Color.{ r = 1.00, g = 0.00, b = 0.00, a = 1.0 };
    CODE_KEYWORD            := Color.{ r = 0.902, g = 0.493, b = 0.457, a = 1.0 };
};

Colors: Color_Values;  // a hack to avoid replacing a lot of code

Code_Color :: enum u8 {
    DEFAULT;
    COMMENT;
    TYPE;
    KEYWORD;
    VALUE_KEYWORD;
    VALUE;
    FUNCTION;
    PUNCTUATION;
    STRING;
    ERROR;
    OPERATION;

    NUM_COLORS;
}

CODE_COLOR_MAP: [Code_Color.NUM_COLORS] Vector4;

refresh_code_color_map :: () -> [Code_Color.NUM_COLORS] Vector4 {
    using Code_Color;

    result: [NUM_COLORS] Vector4;

    result[DEFAULT]         = Colors.CODE_DEFAULT;
    result[COMMENT]         = Colors.CODE_COMMENT;
    result[TYPE]            = Colors.CODE_TYPE;
    result[FUNCTION]        = Colors.CODE_FUNCTION;
    result[PUNCTUATION]     = Colors.CODE_PUNCTUATION;
    result[STRING]          = Colors.CODE_STRING;
    result[VALUE]           = Colors.CODE_VALUE;
    result[VALUE_KEYWORD]   = Colors.CODE_VALUE;
    result[ERROR]           = Colors.CODE_ERROR;
    result[KEYWORD]         = Colors.CODE_KEYWORD;
    result[OPERATION]       = Colors.CODE_OPERATION;

    return result;
}


as_3_floats :: (color: Color) -> [3] float {
    result : [3] float = ---;
    result[0] = color.r;
    result[1] = color.g;
    result[2] = color.b;
    return result;
}

is_none :: (using color: Color) -> bool {
    return r < 0 || g < 0 || b < 0 || a < 0;
}
