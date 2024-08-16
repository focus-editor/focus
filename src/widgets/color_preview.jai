deinit_color_preview :: () {
    // Assuming that the editor and the buffer will be cleaned up separately
    panel_buffer_id = -1;
    panel_editor_id = -1;
}

toggle_color_preview :: () {
    if color_preview_is_shown {
        hide_color_preview();
    } else {
        show_color_preview();
    }
}

show_color_preview :: () {
    if !color_preview_is_shown {
        previously_active_editor = editors.active;
    }
    color_preview_is_shown = true;
}

hide_color_preview :: () {
    color_preview_lose_focus();
    color_preview_is_shown = false;
}

is_color_preview :: inline (editor_id: s64) -> bool {
    return editor_id == panel_editor_id;
}

color_preview_on_activate :: () {
    previously_active_editor = editors.active;
}

color_preview_lose_focus :: () {
    // Sometimes we might want to make the previously active editor active, e.g. when deciding on new buffer placement
    if editors.active != editors.left && editors.active != editors.right && editors.left >= 0 && editors.right >= 0 {
        // If we still have the same editors open when the panel was opened, go back to the previously active one,
        // otherwise default to left.
        make_editor_active(ifx previously_active_editor == editors.right then editors.right else editors.left);
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

color_preview_is_active :: inline () -> bool {
    return color_preview_is_shown && panel_editor_id >= 0 && editors.active == panel_editor_id;
}

color_preview_get_editor_id :: inline () -> s64 {
    if panel_editor_id < 0 {
        assert(panel_buffer_id < 0, "Code helper panel already has a buffer. This is a bug");
        panel_buffer_id = find_or_create_an_empty_buffer();
        panel_editor_id = find_or_create_editor(panel_buffer_id);
        editor, buffer := *open_editors[panel_editor_id], *open_buffers[panel_buffer_id];
        buffer.readonly = true;
        buffer.deleted  = true;  // so that it doesn't appear in the open file dialog
    }
    return panel_editor_id;
}

color_preview_is_shown := false;

color_preview_width:  float = 0.5;
color_preview_height: float = 0.5;


#scope_file

panel_buffer_id := -1;
panel_editor_id := -1;

previously_active_editor := -1;
saved_position := Panel_Position.right;

Panel_Position :: enum { left; right; }

