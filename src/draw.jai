draw_frame :: () {
    {
        using Colors.BACKGROUND;
        Simp.clear_render_target(r, g, b, a);
    }

    footer_rect, main_area := cut_bottom(screen, line_height * 1.4);

    if #complete editors_layout == {
        case .None;
            dragging_splitter = false;
            splitter_pos = 0;
            // TODO: draw a shortcut cheat-sheet?
        case .Single;
            dragging_splitter = false;
            splitter_pos = 0;
            draw_editor(editor_active, main_area);
            if mouse_pointer_is_within(main_area) then set_pointer_image(.TEXT_SELECT);
        case .Double;
            // Drag splitter
            if dragging_splitter {
                splitter_pos = (mouse_pointer.x - main_area.x) / main_area.w;
                if splitter_pos == 0 then splitter_pos = 0.1;  // avoid jitter
                if mouse_left_just_released() then dragging_splitter = false;
            }
            if splitter_pos != 0 then splitter_pos = clamp(splitter_pos, 0.1, 0.9);

            // Lay out editors and splitters
            split := ifx splitter_pos > 0 then main_area.w * splitter_pos else main_area.w / 2;
            left_rect, right_rect := cut_left(main_area, split);
            splitter_rect := right_rect;
            splitter_rect.x -= 1;
            splitter_rect.w = 2;
            splitter_rect_fat := expand(splitter_rect, 5 * dpi_scale);
            splitter_color := Colors.SPLITTER;

            if mouse_pointer_is_within(main_area) then set_pointer_image(.TEXT_SELECT);
            if mouse_pointer_is_within(splitter_rect_fat) {
                if mouse_left_just_pressed() then dragging_splitter = true;
                set_pointer_image(.DRAGGING_HORIZONTAL);
                splitter_color = Colors.SPLITTER_HOVER;
                splitter_rect = expand(splitter_rect, 1);
            } else if dragging_splitter {
                splitter_color = Colors.SPLITTER_HOVER;
                splitter_rect = expand(splitter_rect, 1);
            }

            // Draw
            draw_editor(editor_left,  left_rect);
            draw_editor(editor_right, right_rect);
            draw_rect(splitter_rect, splitter_color);
    }

    // Draw footer rect
    draw_rect(footer_rect, Colors.BACKGROUND_BRIGHT);
    draw_top_shadow(footer_rect);

    Simp.swap_buffers(window);
}

draw_editor :: (editor_id: s64, rect: Rect) {
    set_scissor(rect);
    defer Simp.clear_scissor();

    editor := *open_editors[editor_id];
    buffer :=  open_buffers[editor.buffer_id];

    // Handle mouse scroll here because we only know the layout at this point.
    // Some people would say this is not "clean", but hey, we'll see if we have any issues.
    max_scroll := cast(s32) ((buffer.lines.count - 2)  * line_height);
    if mouse_pointer_is_within(rect) then editor_scroll(editor, Input.mouse_delta_z, max_scroll);
    if animate_scrolling(editor) then redraw_requested = true;

    text_offset := make_vector2(char_size * 2, -char_size * 2);

    if mouse_left_just_released() editor.dragging_left = false;

    if (mouse_left_just_pressed() || editor.dragging_left) && mouse_pointer_is_within(rect) && !dragging_splitter {
        // Handle left click inside editor
        using editor;

        // Maybe change cursor position
        mouse_pos := mouse_pointer - bottom_left(rect) - text_offset;
        mouse_pos.x -= viewport.left;
        mouse_pos.y = rect.h - mouse_pos.y + viewport.top - ifx dpi_scale > 1.0 then 1 else 0;
        cursor.pos.line = xx (mouse_pos.y / line_height);
        cursor.pos.col  = xx ((mouse_pos.x / char_size) + 0.5);
        cursor.pos = make_valid_pos(buffer, cursor.pos);
        cursor.col_wanted = cursor.pos.col;
        if !shift_pressed() && !dragging_left then cursor.sel = cursor.pos;

        // Activate editor
        editor_active = editor_id;
        redraw_requested = true;  // so that we don't draw 2 active editors

        if mouse_left_just_pressed() then dragging_left = true;
    }

    is_active := editor_id == editor_active && Input.input_application_has_focus;

    x := rect.x + text_offset.x;
    y := rect.y + rect.h - line_height + (line_height - char_size) / 2 + text_offset.y;
    x -= editor.viewport.left;
    y += editor.viewport.top;

    visible_lines_start := cast(s64) (editor.viewport.top / line_height) - 1;
    visible_lines_start  = clamp(visible_lines_start, 0, buffer.lines.count);
    visible_lines_end := visible_lines_start + cast(s64) (rect.h / line_height) + 1;
    visible_lines_end  = clamp(visible_lines_end,   0, buffer.lines.count);

    draw_cursor(editor, buffer, rect, text_offset, visible_lines_start, visible_lines_end, is_active);

    y -= visible_lines_start * line_height;
    for line : array_view(buffer.lines, visible_lines_start, visible_lines_end) {
        line_len := clamp(line.end - line.start, 0, 1000);  // TODO: count max line length in chars
        line_text := to_string(array_view(buffer.bytes, line.start, line_len));
        Simp.draw_text(font, xx x, xx y, line_text, color = Colors.CODE_PUNCTUATION);
        y -= line_height;
    }
}

draw_cursor :: (using editor: Editor, buffer: Buffer, editor_rect: Rect, text_offset: Vector2, visible_start: s64, visible_end: s64, is_active: bool) {
    left := editor_rect.x + text_offset.x - viewport.left;
    top  := editor_rect.y + editor_rect.h + text_offset.y - line_height + viewport.top + ifx dpi_scale > 1.0 then 1 else 0;  // @Hack: cursor would not look right without the extra adjustment. Need to do something about it;

    if cursor.pos != cursor.sel {
        // Draw selection
        using cursor;
        start, end: Pos;
        if pos < sel { start = pos; end = sel; } else { start = sel; end = pos; }
        selected_lines := array_view(buffer.lines, start.line, end.line - start.line + 1);
        for line, i : selected_lines {
            line_num := start.line + i;
            if line_num < visible_start || visible_end < line_num then continue;
            first := 0;
            last  := line.num_chars + 1;
            if i == 0 then first = start.col;
            if i == selected_lines.count - 1 then last = end.col;
            rect := make_rect(
                left + first * char_size,
                top - line_num * line_height,
                (last - first) * char_size,
                line_height,
            );
            draw_rect(rect, ifx is_active then Colors.SELECTION_ACTIVE else Colors.SELECTION_INACTIVE);
        }
    }

    rect := make_rect(left + cursor.pos.col * char_size, top - cursor.pos.line * line_height, char_size, line_height);
    draw_rect(rect, Colors.CURSOR);
    if !is_active then draw_rect(shrink(rect, 1), Colors.BACKGROUND);
}

draw_rect :: (using rect: Rect, color: Color) {
    Simp.set_shader_for_color(enable_blend = true);
    Simp.immediate_quad(x, y, x + w, y + h, color);
}

draw_top_shadow :: (using rect: Rect, size: float = 10.0) {
    Simp.set_shader_for_color(enable_blend = true);
    s := Colors.SHADOW_DARK;
    t := Colors.SHADOW_TRANSPARENT;
    Simp.immediate_quad(x, y + h, x + w, y + h + size * dpi_scale, c00 = s, c01 = t, c10 = s, c11 = t);
}

set_scissor :: (rect: Rect) {
    x0 := cast(s32) rect.x;
    y0 := cast(s32) rect.y;
    x1 := cast(s32) (rect.x + rect.w);
    y1 := cast(s32) (rect.y + rect.h);
    Simp.set_scissor(x0, y0, x1, y1);
}
