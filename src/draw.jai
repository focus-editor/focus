draw_frame :: () {
    {
        using Colors.BACKGROUND;
        Simp.clear_render_target(r, g, b, a);
    }

    footer_rect, main_area := cut_bottom(screen, line_height * 1.4);
    draw_rect(footer_rect, Colors.BACKGROUND_BRIGHT);

    if #complete editors_layout == {
        case .None;
            // TODO: draw shortcut cheat-sheet?
        case .Single;
            draw_editor(editor_active, main_area);
        case .Double;
            left_rect, right_rect := cut_left(main_area, main_area.w / 2);
            draw_editor(editor_left,  left_rect);
            draw_editor(editor_right, right_rect);

            splitter_rect := right_rect;
            splitter_rect.x -= 1;
            splitter_rect.w = 2;
            draw_rect(splitter_rect, Colors.BACKGROUND_BRIGHT);
    }

    Simp.swap_buffers(window);
}

draw_editor :: (editor_id: s64, rect: Rect) {
    set_scissor(rect);
    defer Simp.clear_scissor();

    editor := open_editors[editor_id];
    buffer := open_buffers[editor.buffer_id];

    text_offset := make_vector2(char_size * 2);

    draw_cursor(editor, rect, text_offset, editor_id == editor_active);

    x := rect.x + text_offset.x;
    y := rect.y + rect.h - line_height + (line_height - char_size) / 2 - text_offset.y;
    x -= editor.viewport.left;
    y += editor.viewport.top;

    visible_lines_start := cast(s64) (editor.viewport.top / line_height) - 1;
    visible_lines_end   := visible_lines_start + cast(s64) (rect.h / line_height) + 1;
    visible_lines_start = clamp(visible_lines_start, 0, buffer.lines.count);
    visible_lines_end   = clamp(visible_lines_end,   0, buffer.lines.count);

    y -= visible_lines_start * line_height;
    for line : array_view(buffer.lines, visible_lines_start, visible_lines_end) {
        line_len := clamp(line.end - line.start, 0, 1000);  // so that we don't bother checking for visible chars
        line_text := to_string(array_view(buffer.bytes, line.start, line_len));
        Simp.draw_text(font, xx x, xx y, line_text, color = Colors.CODE_PUNCTUATION);
        y -= line_height;
    }
}

draw_cursor :: (using editor: Editor, editor_rect: Rect, text_offset: Vector2, is_active: bool) {
    width  := char_size;
    height := line_height;
    x := editor_rect.x + cursor.pos.col * width + text_offset.x;
    y := editor_rect.y + editor_rect.h - cursor.pos.line * height - height - text_offset.y + ifx dpi_scale > 1.0 then 1 else 0;  // @Hack: cursor would not look right without the extra adjustment. Need to do something about it;
    x -= viewport.left;
    y += viewport.top;

    rect := make_rect(x, y, width, height);
    draw_rect(rect, Colors.CURSOR_ACTIVE);
}

draw_rect :: (using rect: Rect, color: Color) {
    Simp.set_shader_for_color();
    Simp.immediate_quad(x, y, x + w, y + h, color);
}

set_scissor :: (rect: Rect) {
    x0 := cast(s32) rect.x;
    y0 := cast(s32) rect.y;
    x1 := cast(s32) (rect.x + rect.w);
    y1 := cast(s32) (rect.y + rect.h);
    Simp.set_scissor(x0, y0, x1, y1);
}
