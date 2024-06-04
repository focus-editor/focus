Saved_Window_Info :: LD.Saved_Window_Info;

toggle_fullscreen :: (win: Window_Type, desire_fullscreen: bool, saved: *LD.Saved_Window_Info) -> success: bool, width: s32, height: s32 {
    s, w, h := LD.toggle_fullscreen(win, desire_fullscreen, saved);
    return s, w, h;
}

create_window :: (width: int, height: int, window_name: string, window_x := 0, window_y := 0, parent := INVALID_WINDOW, background_color_rgb := DEFAULT_WINDOW_CREATION_COLOR) -> Window_Type {
    return LD.create_window(width, height, window_name, window_x, window_y, parent, background_color_rgb);
}

get_dimensions :: (win: Window_Type, right_handed: bool) -> (x: s32, y: s32, width: s32, height: s32, success := true) {
    x, y, w, h, s := LD.get_dimensions(win, right_handed);
    return x, y, w, h, s;
}

get_mouse_pointer_position :: (win: Window_Type, right_handed: bool) -> x: int, y: int, success: bool {
    x, y, s := LD.get_mouse_pointer_position(win, right_handed);
    return x, y, s;
}

get_mouse_pointer_position :: inline (right_handed := false) -> x: int, y: int, success: bool {
    x, y, s := LD.get_mouse_pointer_position(right_handed);
    return x, y, s;
}

#scope_file
LD :: #import "Linux_Display";
#assert(LD.JAI_STDLIB_INTEROP);
