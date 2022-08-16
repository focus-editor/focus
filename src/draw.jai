draw_frame :: () {
    {
        using Colors.BACKGROUND;
        Simp.clear_render_target(r, g, b, a);
    }
    time := get_time();

    footer_rect, main_area := cut_bottom(screen, char_size * 2);
    editor1_rect, editor2_rect := cut_left(main_area, main_area.w / 2);
    editor1_rect = shrink(editor1_rect, char_size * 2);
    editor2_rect = shrink(editor2_rect, char_size * 2);

    editor, buffer := get_active_editor_and_buffer();
    if editor {
        rect := editor2_rect;

        draw_cursor(editor, rect);

        x := rect.x;
        y := rect.y + rect.h - line_height + (line_height - char_size) / 2;
        x -= editor.viewport.left;
        y -= editor.viewport.top;
        for line : split(to_string(buffer.bytes), cast(u8) #char "\n") {
            Simp.draw_text(font, xx x, xx y, line);
            y -= line_height;
        }
        Simp.immediate_flush();
    }

    Simp.swap_buffers(window);
}

draw_cursor :: (using editor: Editor, editor_rect: Rect) {
    width  := char_size;
    height := line_height;
    x := editor_rect.x + cursor.pos.col  * width;
    y := editor_rect.y + editor_rect.h - cursor.pos.line * height - height + ifx dpi_scale > 1.0 then 1 else 0;  // @Hack: cursor would not look right without the extra adjustment. Need to do something about it;
    x -= viewport.left;
    y -= viewport.top;

    rect := make_rect(x, y, width, height);
    draw_rect(rect, Colors.CURSOR_ACTIVE);
}

draw_rect :: (using rect: Rect, color: Color) {
    Simp.set_shader_for_color();
    Simp.immediate_quad(x, y, x + w, y + h, Colors.CURSOR_ACTIVE);
}
