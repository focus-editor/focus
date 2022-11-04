Color :: struct {
    #as vec4 : Vector4 = ---;

    #place vec4;
    using components : struct { r, g, b, a : float = 1; };

    #place vec4;
    floats : [4] float = ---;
}

Colors :: struct {
    NONE :: Color.{ r = -1, g = -1, b = -1, a = -1 };  // an invalid color to denote no color

    BACKGROUND              :: Color.{ r = 0.086, g = 0.133, b = 0.165 };
    BACKGROUND_DARK         :: Color.{ r = 0.065, g = 0.101, b = 0.125 };
    BACKGROUND_HIGHLIGHT    :: Color.{ r = 0.097, g = 0.15, b = 0.185 };
    BACKGROUND_LIGHT        :: Color.{ r = 0.102, g = 0.158, b = 0.195 };
    BACKGROUND_BRIGHT       :: Color.{ r = 0.131, g = 0.202, b = 0.25 };
    SELECTION_ACTIVE        :: Color.{ r = 0.11, g = 0.267, b = 0.29 };
    SELECTION_INACTIVE      :: Color.{ r = 0.11, g = 0.267, b = 0.29, a = 0.5 };
    SELECTION_HIGHLIGHT     :: Color.{ r = 0.8, g = 0.6, b = 0.8, a = 0.2 };
    SEARCH_RESULT_ACTIVE    :: Color.{ r = 0.559, g = 0.469, b = 0.184 };
    SEARCH_RESULT_INACTIVE  :: Color.{ r = 0.322, g = 0.302, b = 0.173 };
    SCROLLBAR               :: Color.{ r = 0.131, g = 0.202, b = 0.25, a = 0.3 };
    SCROLLBAR_HOVER         :: Color.{ r = 0.131, g = 0.202, b = 0.25, a = 0.8 };
    SCROLLBAR_BACKGROUND    :: Color.{ r = 0.065, g = 0.101, b = 0.125, a = 0.3 };
    CURSOR                  :: Color.{ r = 0.2, g = 0.8, b = 0.8 };
    CURSOR_INACTIVE         :: Color.{ r = 0.1, g = 0.4, b = 0.4 };
    PASTE_ANIMATION         :: Color.{ r = 0.11, g = 0.267, b = 0.29 };
    SPLITTER                :: Color.{ r = 0.131, g = 0.202, b = 0.25 };
    SPLITTER_HOVER          :: Color.{ r = 0.110, g = 0.267, b = 0.29 };

    CODE_DEFAULT        :: Color.{ r = 0.81, g = 0.77, b = 0.66, a = 1.0 };
    CODE_COMMENT        :: Color.{ r = 0.533, g = 0.569, b = 0.616, a = 1.0 };
    CODE_TYPE           :: Color.{ r = 0.51, g = 0.67, b = 0.64, a = 1.0 };
    CODE_FUNCTION       :: Color.{ r = 0.67, g = 0.74, b = 0.49, a = 1.0 };
    CODE_PUNCTUATION    :: Color.{ r = 0.75, g = 0.79, b = 0.86, a = 1.0 };
    CODE_STRING         :: Color.{ r = 0.85, g = 0.68, b = 0.33, a = 1.0 };
    CODE_VALUE          :: Color.{ r = 0.84, g = 0.60, b = 0.71, a = 1.0 };
    CODE_HIGHLIGHT      :: Color.{ r = 0.85, g = 0.61, b = 0.46, a = 1.0 };
    CODE_ERROR          :: Color.{ r = 1.00, g = 0.00, b = 0.00, a = 1.0 };
    CODE_KEYWORD        :: Color.{ r = 0.902, g = 0.493, b = 0.457, a = 1.0 };

    SHADOW_DARK         :: Color.{ r = 0.057, g = 0.089, b = 0.11, a = 0.5 };
    SHADOW_TRANSPARENT  :: Color.{ r = 0.057, g = 0.089, b = 0.11, a = 0 };  // for interpolation

    UI_DEFAULT          :: Color.{ r = 0.75, g = 0.79, b = 0.86, a = 1.0 };
    UI_DIM              :: Color.{ r = 0.533, g = 0.569, b = 0.616, a = 1.0 };
    UI_WARNING          :: Color.{ r = 0.85, g = 0.68, b = 0.33, a = 1.0 };
    UI_ERROR            :: Color.{ r = 1.00, g = 0.00, b = 0.00, a = 1.0 };
    UI_TEXT_INPUT_LABEL :: Color.{ r = 0.233, g = 0.269, b = 0.316, a = 1.0 };
};

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
