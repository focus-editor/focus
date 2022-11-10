finder_handle_event :: (event: Input.Event) {

}

finder_is_open :: () -> bool {
    return finder.openness > 0;
}

toggle_finder :: () {
    if finder_is_open() then close_finder(); else open_finder();
}

activate_finder :: inline () {
    active_global_widget = .finder;
}

deactivate_finder :: inline () {
    // Currently the only one other global widget available when the finder is open is the editors,
    // because open_file_dialog is modal and will close if finder opens.
    // If that changes we may have to change this code, too.
    active_global_widget = .editors;
}

open_finder :: () {
    using finder;

    activate_finder();

    // Select text when opening
    input.cursor.sel = 0;
    input.cursor.pos = get_num_chars(input.text);

    start_animation(*open_anim, openness, Finder.DEFAULT_OPENNESS);
}

close_finder :: () {
    active_global_widget = .editors;

    start_animation(*finder.open_anim, finder.openness, 0);
}

finder_set_openness :: (value: float) {
    using finder;
    openness = clamp(value, 0, Finder.MAX_OPENNESS);;
    open_anim.target = openness;
    if openness == 0 then deactivate_finder();
}

maybe_animate_finder :: () {
    using finder;
    if finder.openness != open_anim.target {
        redraw_requested = true;
        finder.openness = get_animation_value(open_anim);
    }
}

finder: Finder;

Finder :: struct {
    openness: float = 0;  // percentage of window width. Zero means it's hidden
    input: Text_Input;

    open_anim: Tween_Animation(float);
    MAX_OPENNESS     :: 0.8;
    DEFAULT_OPENNESS :: 0.2;
}

