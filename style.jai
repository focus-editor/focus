Color :: struct {
    vec4 : Vector4 = ---;

    #place vec4;
    using components : struct { r, g, b, a : float = 1; };

    #place vec4;
    floats : [4] float = ---;
}

Colors :: struct {
    BACKGROUND :: Color.{ r = 0.086, g = 0.133, b = 0.165 };
    BACKGROUND_DARK :: Color.{ r = 0.065, g = 0.101, b = 0.125 };
    BACKGROUND_HIGHLIGHT :: Color.{ r = 0.097, g = 0.15, b = 0.185 };
    BACKGROUND_LIGHT :: Color.{ r = 0.102, g = 0.158, b = 0.195 };
    BACKGROUND_BRIGHT :: Color.{ r = 0.131, g = 0.202, b = 0.25 };
    CURSOR_ACTIVE :: Color.{ r = 0.2, g = 0.8, b = 0.8 };
    CURSOR_INACTIVE :: Color.{ r = 0.2, g = 0.239, b = 0.267 };
    SELECTION_ACTIVE :: Color.{ r = 0.11, g = 0.267, b = 0.29 };
    SELECTION_INACTIVE :: Color.{ r = 0.11, g = 0.267, b = 0.29 };
    SEARCH_RESULT_ACTIVE :: Color.{ r = 0.559, g = 0.469, b = 0.184 };
    SEARCH_RESULT_INACTIVE :: Color.{ r = 0.322, g = 0.302, b = 0.173 };
    SCROLLBAR :: Color.{ r = 0.131, g = 0.202, b = 0.25 };
};

color_as_3_floats :: (color: Color) -> [3] float {
    result : [3] float = ---;
    result[0] = color.r;
    result[1] = color.g;
    result[2] = color.b;
    return result;
}
