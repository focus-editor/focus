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

    using editor := *open_editors[editor_id];
    buffer :=  open_buffers[buffer_id];

    // Calculate text origin in screen coordinates
    text_offset := make_vector2(char_size * 2, -char_size * 2);
    text_origin := top_left(rect) + text_offset - make_vector2(xx viewport.left, line_height - viewport.top);

    drag, drag_started := mouse_left_is_dragging();
    dragging_left = drag && point_within(drag_started, rect);
    if (mouse_left_just_pressed() || dragging_left) && mouse_pointer_is_within(rect) && !dragging_splitter {
        // Maybe change cursor position
        mouse_pos := mouse_pointer - bottom_left(rect) - text_offset;
        mouse_pos.x += viewport.left;
        mouse_pos.y = rect.h - mouse_pos.y + viewport.top - ifx dpi_scale > 1.0 then 1 else 0;
        cursor.pos.line = xx (mouse_pos.y / line_height);
        cursor.pos.col  = xx ((mouse_pos.x / char_size) + 0.5);
        cursor.pos = make_valid_pos(buffer, cursor.pos);
        cursor.col_wanted = cursor.pos.col;
        cursor_moved = true;
        if !shift_pressed() && !dragging_left then cursor.sel = cursor.pos;

        // Activate editor
        editor_active = editor_id;
        redraw_requested = true;  // so that we don't draw 2 active editors
    }

    // Handle editor scrolling here because we only know the layout at this point.
    // Some people would say this is not "clean", but hey, we'll see if we have any issues.
    max_y_scroll := cast(s32) ((buffer.lines.count - 2)  * line_height);
    if mouse_pointer_is_within(rect) && Input.mouse_delta_z {
        editor_mouse_scroll(editor, Input.mouse_delta_z, max_y_scroll);
    } else if cursor_moved {
        // Detect if cursor is off screen and start scrolling to it
        bounds := shrink_x(rect, text_offset.x + char_size * 3);
        bounds  = shrink_y(bounds, -text_offset.y + line_height * 3);
        bounds.h += 2;
        bounds.y -= line_height + 2;
        // draw_rect(bounds, Colors.BACKGROUND_DARK);

        cursor_pos := get_cursor_screen_pos(text_origin, cursor.pos);
        if !point_within(cursor_pos, bounds) {
            left, top, right, bottom := get_rect_sides(bounds);
            offset: Vector2;
            if cursor_pos.x < left   then offset.x = cursor_pos.x - left;
            if cursor_pos.y < bottom then offset.y = cursor_pos.y - bottom;
            if right < cursor_pos.x  then offset.x = cursor_pos.x - right;
            if top   < cursor_pos.y  then offset.y = cursor_pos.y - top;

            left_target := clamp(viewport.left + cast(s32) offset.x, 0, xx (1000 * char_size));  // TODO: set a proper limit
            top_target  := clamp(viewport.top  - cast(s32) offset.y, 0, max_y_scroll);

            if left_target != viewport.scroll_x.target {
                using viewport.scroll_x;
                start  = viewport.left;
                target = left_target;
                started_at = frame_time;
            }
            if top_target != viewport.scroll_y.target {
                using viewport.scroll_y;
                start  = viewport.top;
                target = top_target;
                started_at = frame_time;
            }
        }
    }
    if animate_scrolling(editor) {
        text_origin = top_left(rect) + text_offset - make_vector2(xx viewport.left, line_height - viewport.top);  // need to update after scrolling to reduce latency
        redraw_requested = true;
    }

    is_active := editor_id == editor_active && Input.input_application_has_focus;

    visible_lines_start := cast(s64) (viewport.top / line_height) - 1;
    visible_lines_start  = clamp(visible_lines_start, 0, buffer.lines.count);
    visible_lines_end := visible_lines_start + cast(s64) (rect.h / line_height) + 1;
    visible_lines_end  = clamp(visible_lines_end,   0, buffer.lines.count);

    draw_cursor(editor, buffer, rect, text_origin, visible_lines_start, visible_lines_end, is_active);

    pen := text_origin;
    pen.y += (line_height - char_size) / 2 - visible_lines_start * line_height;
    for line : array_view(buffer.lines, visible_lines_start, visible_lines_end) {
        line_len  := clamp(line.end - line.start, 0, 1000);  // TODO: count max line length in chars
        line_text := to_string(array_view(buffer.bytes, line.start, line_len));
        Simp.draw_text(font, xx pen.x, xx pen.y, line_text, color = Colors.CODE_PUNCTUATION);
        pen.y -= line_height;
    }
}

get_cursor_screen_pos :: (text_origin: Vector2, pos: Pos) -> Vector2 {
    return make_vector2(
        text_origin.x + pos.col * char_size,
        text_origin.y - pos.line * line_height,
    );
}

draw_cursor :: (using editor: Editor, buffer: Buffer, editor_rect: Rect, text_origin: Vector2, visible_start: s64, visible_end: s64, is_active: bool) {
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
                text_origin.x + first * char_size,
                text_origin.y - line_num * line_height,
                (last - first) * char_size,
                line_height,
            );
            draw_rect(rect, ifx is_active then Colors.SELECTION_ACTIVE else Colors.SELECTION_INACTIVE);
        }
    }

    cursor_pos := get_cursor_screen_pos(text_origin, cursor.pos);
    rect := make_rect(cursor_pos.x, cursor_pos.y, char_size, line_height);
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
