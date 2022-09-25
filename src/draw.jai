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

            if mouse_left_just_released() then dragging_splitter = false;
    }

    // Draw footer rect
    draw_rect(footer_rect, Colors.BACKGROUND_BRIGHT);
    draw_top_shadow(footer_rect);

    if show_open_file_dialog then draw_open_file_dialog();

    Simp.swap_buffers(window);
}

draw_editor :: (editor_id: s64, rect: Rect) {
    set_scissor(rect);
    defer Simp.clear_scissor();

    using editor := *open_editors[editor_id];
    buffer := open_buffers[buffer_id];

    // Calculate text origin in screen coordinates
    text_offset := make_vector2(char_size * 2, -char_size * 2);
    text_origin := top_left(rect) + text_offset - make_vector2(xx viewport.left, line_height - viewport.top);

    active_drag, drag_started_at_point := mouse_left_is_dragging();
    dragging_lmb = active_drag && point_within(drag_started_at_point, rect);
    if ((mouse_left_just_pressed() && mouse_pointer_is_within(rect)) || dragging_lmb) && !dragging_splitter {
        pointer := snap_to_rect(mouse_pointer, rect);  // when we drag outside the editor we still want to interact

        // Maybe change cursor position
        cursor := leave_only_original_cursor(editor);
        mouse_pos := pointer - bottom_left(rect) - text_offset;
        mouse_pos.x += viewport.left;
        mouse_pos.y = rect.h - mouse_pos.y + viewport.top - ifx dpi_scale > 1.0 then 1 else 0;
        cursor.pos.line = xx (mouse_pos.y / line_height);
        cursor.pos.col  = xx ((mouse_pos.x / char_size) + 0.5);
        cursor.pos = make_valid_pos(buffer, cursor.pos);
        cursor.col_wanted = cursor.pos.col;

        // We mark cursor as moved to trigger auto-scroll if we drag outside the editor
        if dragging_lmb && !mouse_pointer_is_within(rect) then cursor_moved = true;

        if !shift_pressed() && !dragging_lmb then remove_selection(cursor);
        if mouse_left_just_double_clicked then select_word(cursor, buffer);

        // Activate editor
        editor_active = editor_id;
        redraw_requested = true;  // so that we don't draw 2 active editors
    }

    // Handle editor scrolling here because we only know the layout at this point.
    // Some people would say this is not "clean", but hey, we'll see if we have any issues.
    max_y_scroll := get_max_y_scroll(buffer);
    if mouse_pointer_is_within(rect) && Input.mouse_delta_z {
        editor_mouse_scroll(editor, Input.mouse_delta_z, max_y_scroll);
    } else if cursor_moved {
        // Detect if cursor is off screen and start scrolling to it
        bounds := shrink_x(rect, text_offset.x + char_size * 3);
        bounds  = shrink_y(bounds, -text_offset.y + line_height * 3);
        bounds.h += 2;
        bounds.y -= line_height + 2;
        if bounds.w < 0 || bounds.h < 0 then bounds = rect;  // fall back
        // draw_rect(bounds, Colors.BACKGROUND_DARK);

        cursor_pos := get_cursor_screen_pos(text_origin, cursors[main_cursor].pos);
        if !point_within(cursor_pos, bounds) {
            left, top, right, bottom := get_rect_sides(bounds);
            offset: Vector2;
            if cursor_pos.x < left   then offset.x = cursor_pos.x - left;
            if cursor_pos.y < bottom then offset.y = cursor_pos.y - bottom;
            if right < cursor_pos.x  then offset.x = cursor_pos.x - right;
            if top   < cursor_pos.y  then offset.y = cursor_pos.y - top;

            max_x_scroll := cast(s32) (1000 * char_size);  // TODO: set a proper limit
            left_target := clamp(viewport.left + cast(s32) offset.x, 0, max_x_scroll);
            top_target  := clamp(viewport.top  - cast(s32) offset.y, 0, max_y_scroll);

            if left_target != viewport.scroll_x.target then set_scroll_target(*viewport.scroll_x, viewport.left, left_target, max_x_scroll);
            if top_target  != viewport.scroll_y.target then set_scroll_target(*viewport.scroll_y, viewport.top,  top_target,  max_y_scroll);
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

    draw_cursors(editor, buffer, rect, text_origin, visible_lines_start, visible_lines_end, is_active);

    for anim : editor.paste_animations {
        t := (frame_time - anim.started_at) / Paste_Animation.SPEED;
        if t < 1 {
            color := Colors.PASTE_ANIMATION;
            color.a = xx (1 - t);
            draw_range(anim.range, buffer, visible_lines_start, visible_lines_end, text_origin, color);
        } else {
            remove anim;
        }
    }
    if editor.paste_animations.count > 0 then redraw_requested = true;

    pen := text_origin;
    pen.y += (line_height - char_size) / 2 - visible_lines_start * line_height;
    for line : array_view(buffer.lines, visible_lines_start, visible_lines_end) {
        line_len  := clamp(line.end - line.start, 0, 1000);  // TODO: count max line length in chars
        line_text := to_string(array_view(buffer.bytes, line.start, line_len));
        Simp.draw_text(font, xx pen.x, xx pen.y, line_text, color = Colors.CODE_PUNCTUATION);
        pen.y -= line_height;
    }
}

draw_open_file_dialog :: () {
    // Figure out the dialog box size
    box_rect: Rect = ---;
    {
        width  := clamp(screen.w / 3,   400 * dpi_scale, 1500 * dpi_scale);
        height := clamp(screen.h / 1.5, 200 * dpi_scale, 800  * dpi_scale);
        x := (screen.w - width) / 2;
        y := clamp(100 * dpi_scale, 0, (screen.h - height) / 2);
        box_rect = make_rect(x, screen.h - height - y, width, height);
    }
    draw_rounded_rect_with_shadow(box_rect, Colors.BACKGROUND_LIGHT, radius = char_size / 1.5, shadow_size = char_size);

    margin  := 10 * dpi_scale;
    padding :=  5 * dpi_scale;
    input_rect_height := font_ui_line_height + 2 * padding + 2 * margin + 2;
    input_rect, results_rect := cut_top(box_rect, input_rect_height);
    input_rect = shrink(input_rect, margin);
    draw_rounded_rect(input_rect, Colors.BACKGROUND_DARK);
    input_rect = shrink(input_rect, 1);
    draw_rounded_rect(input_rect, Colors.BACKGROUND);
    str := "vasia poupkine";
    x := input_rect.x + padding;
    y := input_rect.y + (input_rect.h - font_ui.character_height) / 2 + 2 * dpi_scale;  // I don't know why we need this extra + 2, but without it the text doesn't look in the right place
    Simp.draw_text(font_ui, xx x, xx y, str, color = Colors.CODE_PUNCTUATION);
}

get_cursor_screen_pos :: (text_origin: Vector2, pos: Pos) -> Vector2 {
    return make_vector2(
        text_origin.x + pos.col * char_size,
        text_origin.y - pos.line * line_height,
    );
}

draw_cursors :: (using editor: Editor, buffer: Buffer, editor_rect: Rect, text_origin: Vector2, visible_start: s64, visible_end: s64, is_active: bool) {
    for cursor : cursors {
        if has_selection(cursor) {
            // Draw selection
            selection := get_selection(cursor);
            color := ifx is_active then Colors.SELECTION_ACTIVE else Colors.SELECTION_INACTIVE;
            draw_range(selection, buffer, visible_start, visible_end, text_origin, color);
        }

        cursor_pos := get_cursor_screen_pos(text_origin, cursor.pos);
        rect := make_rect(cursor_pos.x, cursor_pos.y, char_size, line_height);
        draw_rect(rect, Colors.CURSOR);
        if !is_active then draw_rect(shrink(rect, 1), Colors.BACKGROUND);
    }
}

draw_range :: (using range: Range, buffer: Buffer, visible_start: s64, visible_end: s64, text_origin: Vector2, color: Color) {
    selected_lines := array_view(buffer.lines, start.line, end.line - start.line + 1);
    for line, i : selected_lines {
        line_num := start.line + i;
        if line_num < visible_start || visible_end < line_num then continue;

        is_first := i == 0;
        is_last  := i == selected_lines.count - 1;

        first_char := 0;
        last_char  := line.num_chars + 1;
        if is_first then first_char = start.col;
        if is_last  then last_char  = end.col;

        if first_char == last_char continue;  // nothing is selected on this line

        rect := make_rect(
            text_origin.x + first_char * char_size,
            text_origin.y - line_num * line_height,
            (last_char - first_char) * char_size,
            line_height,
        );

        // @Speed: probably can be optimised?
        tl, tr, bl, br: Corner_Rounding = .none;
        if is_first {
            tl = .in; tr = .in;
        } else {
            prev_start := ifx i == 1 then start.col else 0;
            prev_end   := selected_lines[i - 1].num_chars + 1;
            if prev_start < first_char then tl = .out;
            if prev_start > first_char then tl = .in;
            if prev_end > last_char then tr = .out;
            if prev_end < last_char || prev_start > last_char then tr = .in;
        }
        if is_last {
            bl = .in; br = .in;
        } else {
            next_start := 0;
            next_end   := ifx i == selected_lines.count - 2 then end.col else selected_lines[i + 1].num_chars + 1;
            if next_start < first_char then bl = .out;
            if next_start > first_char || next_end < first_char then bl = .in;
            if next_end < last_char then br = .in;
            if next_end > last_char then br = .out;
        }
        draw_rounded_rect(rect, color, tl, tr, br, bl);
    }
}

Corner_Rounding :: enum { none; in; out; }

draw_rounded_rect :: (rect: Rect, color: Color,
                      tl: Corner_Rounding = .in, tr: Corner_Rounding = .in,
                      br: Corner_Rounding = .in, bl: Corner_Rounding = .in,
                      radius := 0.0) {
    Simp.set_shader_for_color(enable_blend = true);
    r := ifx radius > 0 then radius else char_size / 3.0;  // rounding radius
    top, bottom, base, corner: Rect = ---;
    top,    base = cut_top(rect, r);
    bottom, base = cut_bottom(base, r);
    draw_rect_raw(base, color);

    // Draw top
    if tl == {
        case .in;
            corner, top = cut_left(top, r);
            draw_corner(color, bottom_right(corner), bottom_right(corner), PI/2, PI, r);
        case .out;
            corner = top; corner.w = r; corner.x -= r;
            draw_corner(color, top_right(corner), bottom_left(corner), 0, PI/2, r);
    }
    if tr == {
        case .in;
            corner, top = cut_right(top, r);
            draw_corner(color, bottom_left(corner), bottom_left(corner), 0, PI/2, r);
        case .out;
            corner = top; corner.w = r; corner.x += top.w;
            draw_corner(color, top_left(corner), bottom_right(corner), PI/2, PI, r);
    }
    draw_rect_raw(top, color);

    // Draw bottom
    if bl == {
        case .in;
            corner, bottom = cut_left(bottom, r);
            draw_corner(color, top_right(corner), top_right(corner), PI, 3*PI/2, r);
        case .out;
            corner = bottom; corner.w = r; corner.x -= r;
            draw_corner(color, bottom_right(corner), top_left(corner), 3*PI/2, 2*PI, r);
    }
    if br == {
        case .in;
            corner, bottom = cut_right(bottom, r);
            draw_corner(color, top_left(corner), top_left(corner), 3*PI/2, 2*PI, r);
        case .out;
            corner = bottom; corner.w = r; corner.x += bottom.w;
            draw_corner(color, bottom_left(corner), top_right(corner), PI, 3*PI/2, r);
    }
    draw_rect_raw(bottom, color);
}

draw_rounded_rect_with_shadow :: (rect: Rect, color: Color, radius := 0.0, shadow_size := 10.0) {
    r := ifx radius > 0 then radius else char_size / 3.0;  // rounding radius
    shadow_rect := expand(rect, shadow_size);
    shadow_radius := r + shadow_size;

    top, bottom, left, right, base, corner: Rect = ---;
    top,    base = cut_top(shadow_rect, shadow_radius);
    bottom, base = cut_bottom(base, shadow_radius);
    left,   base = cut_left(base, shadow_radius);
    right,  base = cut_right(base, shadow_radius);

    s  := Colors.SHADOW_DARK;
    t := Colors.SHADOW_TRANSPARENT;

    Simp.set_shader_for_color(enable_blend = true);

    // Draw corners
    {
        corner, top = cut_left(top, shadow_radius);  // top left
        draw_corner(t, bottom_right(corner), bottom_right(corner), PI/2, PI, shadow_radius, base_color = s);

        corner, top = cut_right(top, shadow_radius); // top right
        draw_corner(t, bottom_left(corner), bottom_left(corner), 0, PI/2, shadow_radius, base_color = s);

        corner, bottom = cut_left(bottom, shadow_radius);  // bottom left
        draw_corner(t, top_right(corner), top_right(corner), PI, 3*PI/2, shadow_radius, base_color = s);

        corner, bottom = cut_right(bottom, shadow_radius); // bottom right
        draw_corner(t, top_left(corner), top_left(corner), 3*PI/2, 2*PI, shadow_radius, base_color = s);
    }

    // Draw side shadows
    draw_rect_raw(left,   t, t, s, s);
    draw_rect_raw(right,  s, s, t, t);
    draw_rect_raw(top,    s, t, s, t);
    draw_rect_raw(bottom, t, s, t, s);

    draw_rounded_rect(rect, color, radius = r);
}

draw_corner :: (color: Color, base: Vector2, pivot: Vector2, angle_start: float, angle_end: float, radius: float, base_color := Colors.NONE) {
    // base -  the base of triangle fan
    // pivot - the center of the circle
    NUM_TRIANGLES :: 7;
    step := (angle_end - angle_start) / NUM_TRIANGLES;
    points: [NUM_TRIANGLES + 1] Vector2 = ---;
    angle := angle_start;
    for * p : points {
        p.x = pivot.x + cos(angle) * radius;
        p.y = pivot.y + sin(angle) * radius;
        angle += step;
    }
    Simp.immediate_triangle_fan(base, points, color, base_color = ifx is_none(base_color) then color else base_color);
}

draw_rect :: (rect: Rect, color: Color) {
    Simp.set_shader_for_color(enable_blend = true);
    draw_rect_raw(rect, color);
}

draw_rect_raw :: inline (using rect: Rect, color: Color) {
    Simp.immediate_quad(x, y, x + w, y + h, color);
}

draw_rect_raw :: inline (using rect: Rect, c00: Color, c01: Color, c10: Color, c11: Color) {
    Simp.immediate_quad(x, y, x + w, y + h, c00, c01, c10, c11);
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
