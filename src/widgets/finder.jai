finder_is_open :: () -> bool {
    return finder.width > 0 || finder.active;
}

toggle_finder :: () {
    if finder_is_open() then close_finder(); else open_finder();
}

activate_finder :: () {
    finder.active = true;
}

open_finder :: () {
    using finder;
    active = true;

    // Select text when opening
    input.cursor.sel = 0;
    input.cursor.pos = get_num_chars(input.text);

    start_animation(*open_anim, width, Finder.DEFAULT_WIDTH);
}

close_finder :: () {
    using finder;
    active = false;

    start_animation(*open_anim, width, 0);
}

maybe_animate_finder :: () {
    using finder;
    if finder.width != open_anim.target {
        redraw_requested = true;
        finder.width = get_animation_value(open_anim);
    }
}

Finder :: struct {
    active := false;   // active means it's receiving input
    width: float = 0;  // percentage of window width. Zero means it's hidden
    input: Text_Input;

    open_anim: Tween_Animation(float);
    MAX_WIDTH     :: 0.8;
    DEFAULT_WIDTH :: 0.2;
}

finder: Finder;
