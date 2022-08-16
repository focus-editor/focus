draw_frame :: () {
    {
        using Colors.BACKGROUND;
        Simp.clear_render_target(r, g, b, a);
    }
    time := get_time();

    footer_rect, main_area := cut_bottom(screen, char_size * 2);
    editor1_rect, editor2_rect := cut_left(main_area, main_area.w / 2);
    text_offset := make_vector2(char_size * 2);
    // editor1_rect = shrink(editor1_rect, char_size * 2);
    // editor2_rect = shrink(editor2_rect, char_size * 2);

    editor, buffer := get_active_editor_and_buffer();
    if editor {
        rect := editor2_rect;

        set_scissor(rect);
        defer Simp.clear_scissor();

        draw_cursor(editor, rect, text_offset);

        x := rect.x + text_offset.x;
        y := rect.y + rect.h - line_height + (line_height - char_size) / 2 - text_offset.y;
        x -= editor.viewport.left;
        y -= editor.viewport.top;
        for line : split(to_string(buffer.bytes), cast(u8) #char "\n") {
            Simp.draw_text(font, xx x, xx y, line, color = Colors.CODE_PUNCTUATION);
            y -= line_height;
        }
    }

    Simp.swap_buffers(window);
}

draw_cursor :: (using editor: Editor, editor_rect: Rect, text_offset: Vector2) {
    width  := char_size;
    height := line_height;
    x := editor_rect.x + cursor.pos.col * width + text_offset.x;
    y := editor_rect.y + editor_rect.h - cursor.pos.line * height - height - text_offset.y + ifx dpi_scale > 1.0 then 1 else 0;  // @Hack: cursor would not look right without the extra adjustment. Need to do something about it;
    x -= viewport.left;
    y -= viewport.top;

    rect := make_rect(x, y, width, height);
    draw_rect(rect, Colors.CURSOR_ACTIVE);
}

draw_rect :: (using rect: Rect, color: Color) {
    Simp.set_shader_for_color();
    Simp.immediate_quad(x, y, x + w, y + h, Colors.CURSOR_ACTIVE);
}

set_scissor :: (rect: Rect) {
    x0 := cast(s32) rect.x;
    y0 := cast(s32) rect.y;
    x1 := cast(s32) (rect.x + rect.w);
    y1 := cast(s32) (rect.y + rect.h);
    Simp.set_scissor(x0, y0, x1, y1);
}
