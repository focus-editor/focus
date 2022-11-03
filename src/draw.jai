draw_frame :: () {
    {
        using Colors.BACKGROUND;
        Simp.clear_render_target(r, g, b, a);
    }

    // Check whether we need to deactivate elements before drawing
    if !mouse.left.is_down || mouse.left.just_released then ui.active = .none;

    footer_height := font_ui_line_height * 1.6;

    // Draw editors
    if #complete editors_layout == {
        case .None;
            splitter_pos = 0;
            // TODO: draw a shortcut cheat-sheet?
        case .Single;
            splitter_pos = 0;
            draw_editor(editor_active, screen, footer_height, .editor_single);
        case .Double;
            // Drag splitter
            if ui.active == .editor_splitter {
                splitter_pos = (mouse.pointer.x - screen.x) / screen.w;
                if splitter_pos == 0 then splitter_pos = 0.1;  // avoid jitter
                editor_expanded = false;
            }
            if splitter_pos != 0 then splitter_pos = clamp(splitter_pos, 0.1, 0.9);
            if editor_expanded {
                if editor_active == editor_left  && !values_are_close(splitter_pos, 0.9) then splitter_pos = 0.9;
                if editor_active == editor_right && !values_are_close(splitter_pos, 0.1) then splitter_pos = 0.1;
            }

            split_x := ifx splitter_pos > 0 then screen.w * splitter_pos else screen.w / 2;
            left_rect, right_rect := cut_left(screen, split_x);
            left_rect.w  -= 1;
            right_rect.w -= 1;
            right_rect.x += 1;

            draw_editor(editor_left,  left_rect,  footer_height, .editor_left);
            draw_editor(editor_right, right_rect, footer_height, .editor_right);

            splitter_rect := make_rect(left_rect.x + left_rect.w, left_rect.y + footer_height, 2, left_rect.h - footer_height);
            draw_splitter(splitter_rect, split_x);
    }

    if open_file_dialog.show then draw_open_file_dialog();

    // Reset UI state after drawing
    if !mouse.left.is_down || mouse.left.just_released {
        ui.active = .none;
    } else if no_active_ui_item() {
        ui.active = .unavailable;  // so that we don't activate anything by dragging on it
    }
    ui.hot_last_frame = ui.hot;

    Simp.swap_buffers(window);
}

draw_splitter :: (splitter_rect: Rect, split_x: float) {
    ui_id := Ui_Id.editor_splitter;
    color := Colors.SPLITTER;

    rect := splitter_rect;
    rect_fat := expand(splitter_rect, 2 * dpi_scale);

    if mouse_pointer_is_within(rect_fat) {
        ui.hot = ui_id;
        if ui.hot_last_frame == ui_id && mouse.left.just_pressed then ui.active = ui_id; // TODO: highlight animation?
    }

    if ui.active == .none && ui.hot_last_frame == ui_id || ui.active == ui_id {
        set_pointer_image(.DRAGGING_HORIZONTAL);
        color = Colors.SPLITTER_HOVER;
        rect = expand(rect, 1);
    }

    draw_rect(rect, color);
}

draw_editor :: (editor_id: s64, main_area: Rect, footer_height: float, ui_id: Ui_Id) {
    scrollbar_id := get_ui_id_from_loc(parent_id = ui_id);

    footer_rect, rect := cut_bottom(main_area, footer_height);

    using editor := *open_editors[editor_id];
    buffer := open_buffers[buffer_id];

    // Calculate text origin in screen coordinates
    text_offset := make_vector2(char_size * 2, -char_size * 2);
    text_origin := top_left(rect) + text_offset - make_vector2(xx viewport.left, line_height - viewport.top);

    // Draw editor
    {
        push_scissor(rect);
        defer pop_scissor();

        if mouse_pointer_is_within(rect) {
            if ui.hot_last_frame == ui_id && no_active_ui_item() && mouse.left.just_pressed then ui.active = ui_id;
            ui.hot = ui_id;
            set_pointer_image(.TEXT_SELECT);
        }

        if ui.active == ui_id && (mouse.left.just_pressed || mouse.left.is_dragging) {
            pointer := snap_to_rect(mouse.pointer, rect);  // when we drag outside the editor we still want to interact

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
            if !mouse_pointer_is_within(rect) then cursor_moved = true;

            if !shift_pressed() && mouse.left.just_pressed then remove_selection(cursor);
            if mouse.left.just_double_clicked then select_word(cursor, buffer);

            array_reset_keeping_memory(*editor.highlights);

            // Activate editor
            editor_active = editor_id;
            redraw_requested = true;  // so that we don't draw 2 active editors
        }

        // Handle editor scrolling here because we only know the layout at this point.
        // Some people would say this is not "clean", but hey, we'll see if we have any issues.
        max_y_scroll := get_max_y_scroll(buffer);
        if (ui.hot_last_frame == ui_id || ui.hot_last_frame == scrollbar_id) && mouse_pointer_is_within(rect) && mouse.scroll_y_delta != 0 {
            using editor.viewport;
            set_scroll_target(*scroll_y, top, scroll_y.target - mouse.scroll_y_delta, max_y_scroll);
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

        // Maybe update selection highlights
        if editor.highlights.count == 0 {
            // @Speed: we're recalculating it quite often. We should probably not do it as often
            selected_text := get_selected_text_all_cursors(editor, buffer);
            if selected_text.count > 2 && selected_text.count < 1000 && !is_all_whitespace(selected_text) {
                search_func: (s: string, substring: string, start_index := 0) -> s64;
                search_func = ifx editor.search_whole_words then find_index_from_left_whole_word else find_index_from_left;
                buffer_str := to_string(buffer.bytes);
                offset := 0;
                while true {
                    offset = search_func(buffer_str, selected_text, start_index = offset);
                    if offset < 0 break;

                    highlight := array_add(*editor.highlights);
                    highlight.offset = offset;
                    highlight.start_pos = offset_to_pos(buffer, offset);

                    offset += selected_text.count;
                }
            }
            editor.selected_text_length = selected_text.count;
        }

        // Scrollbar
        scrollbar_width := 1.5 * char_size;
        new_scroll_target := draw_scrollbar(rect, scrollbar_width, rect.h + xx max_y_scroll, viewport.top, viewport.scroll_y.target, max_y_scroll, scrollbar_id);
        if new_scroll_target != viewport.scroll_y.target {
            // Jump immediately to the scroll point when dragging or clicking scrollbar
            viewport.top = new_scroll_target;
            viewport.scroll_y.target = new_scroll_target;
            redraw_requested = true;
        }

        // Smooth keyboard scrolling
        if editor_smooth_scroll.active && editor_id == editor_active {
            speed := 60 * line_height;  // pixels per second
            time_elapsed := cast(float) (frame_time - editor_smooth_scroll.started_at);
            new_scroll_pos := editor_smooth_scroll.start_y + time_elapsed * speed * (ifx editor_smooth_scroll.up then -1 else 1);
            viewport.top = clamp(cast(s32) new_scroll_pos, 0, max_y_scroll);
            viewport.scroll_y.target = viewport.top;
            redraw_requested = true;
        }

        // This will handle any "normal" scrolling with a target
        if animate_scrolling(editor) then redraw_requested = true;

        // Need to update after updating scrolling to reduce latency
        text_origin = top_left(rect) + text_offset - make_vector2(xx viewport.left, line_height - viewport.top);

        is_active := editor_id == editor_active && Input.input_application_has_focus;

        visible_lines_start := cast(s64) (viewport.top / line_height) - 1;
        visible_lines_start  = clamp(visible_lines_start, 0, buffer.lines.count);
        visible_lines_end := visible_lines_start + cast(s64) (rect.h / line_height) + 1;
        visible_lines_end  = clamp(visible_lines_end,   0, buffer.lines.count);

        // Draw scrollbar marks
        {
            marks_rect := cut_right(rect, scrollbar_width);
            marks_rect =  cut_top(marks_rect, rect.h * max_y_scroll / (rect.h + xx max_y_scroll));  // account for the non-text area at the bottom
            marks_rect_top := marks_rect.y + marks_rect.h;
            assert(buffer.lines.count > 0);
            mark_line_height := marks_rect.h / cast(float)buffer.lines.count;  // the height of the rect which corresponds to one line

            // Selection highlights
            highlight_mark_rect := shrink_x(marks_rect, marks_rect.w / 3);
            highlight_mark_rect.h = 5 * dpi_scale;
            for highlights {
                highlight_mark_rect.y = marks_rect_top - it.start_pos.line * mark_line_height - highlight_mark_rect.h;
                draw_rect_raw(highlight_mark_rect, Colors.SELECTION_HIGHLIGHT);
            }

            // TODO: search results (probably if available then don't draw selection highlights?)

            // Cursors
            cursor_mark_rect := marks_rect;
            cursor_mark_rect.h = 2 * dpi_scale;
            selection_mark_rect := cut_left(marks_rect, marks_rect.w / 3);
            for cursors {
                cursor_mark_rect.y = marks_rect_top - it.pos.line * mark_line_height - cursor_mark_rect.h;
                if has_selection(it) {
                    selection := get_selection(it);
                    selection_mark_rect.y = marks_rect_top - selection.end.line * mark_line_height - cursor_mark_rect.h;
                    selection_mark_rect.h = (selection.end.line - selection.start.line + 1) * mark_line_height;
                    draw_rect_raw(selection_mark_rect, Colors.SELECTION_INACTIVE);
                }
                draw_rect_raw(cursor_mark_rect, Colors.CURSOR);
            }
        }

        // Visible highlights
        for highlights {
            if it.start_pos.line < visible_lines_start continue;
            if it.start_pos.line > visible_lines_end   break;

            range: Range = ---;
            range.start = it.start_pos;
            range.end   = offset_to_pos(buffer, it.offset + selected_text_length);
            draw_range(range, buffer, visible_lines_start, visible_lines_end, text_origin, Colors.SELECTION_HIGHLIGHT);
        }

        draw_cursors(editor, buffer, rect, text_origin, visible_lines_start, visible_lines_end, is_active);

        // Draw paste animations
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

        // Draw text
        pen := text_origin;
        pen.y += (line_height - char_size) / 2 - visible_lines_start * line_height;
        visible_lines := array_view(buffer.lines, visible_lines_start, visible_lines_end - visible_lines_start);
        for line : visible_lines {
            line_len  := clamp(line.end - line.start, 0, 1000);  // TODO: count max line length in chars
            line_text := to_string(array_view(buffer.bytes, line.start, line_len));
            Simp.draw_text(font, xx pen.x, xx pen.y, line_text, color = Colors.CODE_PUNCTUATION);
            pen.y -= line_height;
        }

    }

    // Draw search bar
    if search_bar_is_open(editor) {
        using search_bar;

        // Update openness
        if openness > openness_target {
            t := cast(float)(anim_should_finish - frame_time) / Search_Bar.OPEN_SPEED;
            openness = clamp(t, 0.0, 1.0);
            redraw_requested = true;
        } else if openness < openness_target {
            t := cast(float)(anim_should_finish - frame_time) / Search_Bar.OPEN_SPEED;
            openness = clamp(1.0 - t, 0.0, 1.0);
            redraw_requested = true;
        }

        margin  :=  5 * dpi_scale;
        padding :=  5 * dpi_scale;
        bar_rect_height := font_ui_line_height + 2 * padding + 2 * margin + 2;

        bar_rect := cut_top(main_area, bar_rect_height);
        bar_rect.w /= 2;
        bar_rect.x += bar_rect.w - 2 * char_size;
        bar_rect.y += bar_rect_height * (1.0 - openness);
        draw_rounded_rect_with_shadow(bar_rect, Colors.BACKGROUND_LIGHT);

        input_rect := shrink(bar_rect, margin);
        draw_text_input(*search_bar.input, input_rect);
    }

    // Draw footer
    {
        footer_color := Colors.BACKGROUND_BRIGHT;
        draw_rect(footer_rect, footer_color);
        draw_top_shadow(footer_rect);

        footer_rect = shrink_x(footer_rect, text_offset.x);

        width   := 0.0;
        padding := 5 * dpi_scale;

        pen := make_vector2(
            footer_rect.x,
            footer_rect.y + (footer_rect.h - font_ui.character_height) / 2 + 2 * dpi_scale,
        );

        // Draw line and column numbers
        cursor := cursors[main_cursor];
        width = xx Simp.prepare_text(font_ui_bold, tprint("Line: %  Col: %", cursor.pos.line, cursor.pos.col));
        line_col_start_x := footer_rect.x + footer_rect.w - width;
        Simp.draw_prepared_text(font_ui_bold, xx line_col_start_x, xx pen.y, color = Colors.CODE_COMMENT);

        // Draw file name and path
        footer_rect.w -= width + padding;
        if footer_rect.w > 0 {
            push_scissor(footer_rect);
            defer pop_scissor();

            file_name_color := Colors.UI_DEFAULT;
            if buffer.modified then file_name_color = Colors.UI_WARNING;

            if buffer.has_file {
                // Icon
                icon_char := convert_utf32_to_utf8(xx buffer.file.icon);
                width = xx Simp.prepare_text(font_icons, to_string(*icon_char));
                Simp.draw_prepared_text(font_icons, xx pen.x, xx pen.y, color = file_name_color);

                // File name
                pen.x += width + padding;
                width = xx Simp.prepare_text(font_ui_bold, buffer.file.name);
                Simp.draw_prepared_text(font_ui_bold, xx pen.x, xx pen.y, color = file_name_color);

                // Maybe warnings
                if buffer.deleted {
                    pen.x += width + padding;
                    width = xx Simp.prepare_text(font_ui_bold, "[deleted on disk]");
                    Simp.draw_prepared_text(font_ui_bold, xx pen.x, xx pen.y, color = Colors.UI_ERROR);
                } else if buffer.modified_on_disk {
                    pen.x += width + padding;
                    width = xx Simp.prepare_text(font_ui_bold, "[modified on disk]");
                    Simp.draw_prepared_text(font_ui_bold, xx pen.x, xx pen.y, color = Colors.UI_ERROR);
                }

                // Draw separator
                pen.x += width + padding;
                width = xx Simp.prepare_text(font_ui_small, BULLET_CHAR);
                Simp.draw_prepared_text(font_ui_small, xx pen.x, xx pen.y, color = Colors.UI_DIM);

                // Draw file path
                pen.x += width + padding;
                width = xx Simp.prepare_text(font_ui_small, buffer.file.path);
                Simp.draw_prepared_text(font_ui_small, xx pen.x, xx pen.y, color = Colors.UI_DIM);
            } else {
                // No file
                icon_char := convert_utf32_to_utf8(xx File_Icon.text);
                width = xx Simp.prepare_text(font_icons, to_string(*icon_char));
                Simp.draw_prepared_text(font_icons, xx pen.x, xx pen.y, color = file_name_color);

                // File name
                pen.x += width + padding;
                width = xx Simp.prepare_text(font_ui, "<new file>");
                Simp.draw_prepared_text(font_ui, xx pen.x, xx pen.y, color = file_name_color);
            }

            // Make sure the text is cut nicely
            fadeout_rect := cut_right(footer_rect, 2 * padding);
            trans := footer_color;
            trans.a = 0;
            Simp.set_shader_for_color(enable_blend = true);
            draw_rect_raw(fadeout_rect, c00 = trans, c10 = footer_color, c01 = trans, c11 = footer_color);
        }
    }

}

draw_open_file_dialog :: () {
    using open_file_dialog;

    ui_id := Ui_Id.open_file_dialog;
    scrollbar_id := get_ui_id_from_loc(parent_id = ui_id);

    if ui.active != .none && ui.active != ui_id && ui.active != scrollbar_id {
        // Close the dialog on clicks elsewhere
        show = false;
        return;
    }

    margin  := 10 * dpi_scale;
    padding :=  5 * dpi_scale;
    input_rect_height := font_ui_line_height + 2 * padding + 2 * margin + 2;
    entry_height := font_ui_line_height + padding * 2;

    // Figure out the dialog box size
    box_rect: Rect = ---;
    {
        width  := clamp(screen.w / 3,   400 * dpi_scale, 1500 * dpi_scale);
        height := clamp(input_rect_height + entry_height * entries.filtered.count + padding, 0, screen.h / 1.5);
        x := (screen.w - width) / 2;
        y := clamp(100 * dpi_scale, 0, (screen.h - height) / 2);
        box_rect = make_rect(x, screen.h - height - y, width, height);
    }
    draw_rounded_rect_with_shadow(box_rect, Colors.BACKGROUND_LIGHT, radius = char_size / 1.5, shadow_size = char_size * 1.5);

    if mouse_pointer_is_within(box_rect) {
        set_pointer_image(.NORMAL);
        ui.hot = ui_id;
        if ui.hot_last_frame == ui_id && no_active_ui_item() && mouse.left.just_pressed then ui.active = ui_id;
    }

    // Draw the filter input
    input_rect, files_rect := cut_top(box_rect, input_rect_height);
    input_rect = shrink(input_rect, margin);
    draw_text_input(*open_file_dialog.input, input_rect);
    _pad: Rect = ---;  // allow some space at the bottom so that we don't cover up the rounded corners with the cursor
    _pad, files_rect = cut_bottom(files_rect, padding);

    // Draw files
    {
        using entries;

        // Remember how many fits per page
        per_page = cast(s64) (files_rect.h / entry_height);
        if per_page <= 0 then per_page = 2;

        push_scissor(files_rect);
        defer pop_scissor();

        {
            // Scrollbar
            content_height := filtered.count * entry_height;
            max_y_scroll := content_height - files_rect.h;
            new_scroll_target := draw_scrollbar(files_rect, 1.5 * char_size, content_height, scroll_y, scroll_anim.target, xx max_y_scroll, scrollbar_id);
            if new_scroll_target != scroll_anim.target {
                scroll_y = new_scroll_target;
                scroll_anim.target = new_scroll_target;
                redraw_requested = true;
            }

            // Scrolling update
            if scroll_to_cursor {
                // We only want to scroll to cursor when cursor is moved by arrow keys
                target := scroll_anim.target;
                selected_top    := selected * entry_height - target;
                selected_bottom := selected_top + entry_height;
                if selected_top < 0 then target = cast(s32) (selected * entry_height);
                if selected_bottom > files_rect.h then target = cast(s32) ((selected + 1) * entry_height - files_rect.h);
                if target != scroll_anim.target then set_scroll_target(*scroll_anim, scroll_y, target, xx max_y_scroll);
                scroll_to_cursor = false;
            }

            // Mouse scrolling
            if (ui.hot_last_frame == ui_id || ui.hot_last_frame == scrollbar_id) && mouse_pointer_is_within(files_rect) {
                if ui.hot_last_frame == ui_id then set_pointer_image(.PRESSABLE);
                if mouse.scroll_y_delta != 0 {
                    set_scroll_target(*scroll_anim, scroll_y, scroll_anim.target - mouse.scroll_y_delta, xx max_y_scroll);
                }
            }

            scrolling := false;
            scroll_y, scrolling = animate_scrolling(*scroll_anim, scroll_y);
            if scrolling then redraw_requested = true;
        }

        highlight_color_lite := Colors.BACKGROUND_BRIGHT;
        highlight_color_lite.a = 0.4;

        visible_start := clamp(cast(s64) (scroll_y / entry_height), 0, filtered.count);
        visible_count := cast(s64) (files_rect.h / entry_height) + 2;
        visible_entries := array_view(filtered, visible_start, visible_count);

        entry_rect := cut_top(files_rect, entry_height);

        path_align_x := files_rect.x + files_rect.w / 2.5;

        for entry, i : visible_entries {
            entry_index := visible_start + i;
            entry_rect.y = files_rect.y + files_rect.h - (entry_index + 1) * entry_height + scroll_y;

            if mouse_pointer_is_within(entry_rect) && ui.hot_last_frame == ui_id && (ui.active == .none || ui.active == ui_id) {
                if mouse.left.just_pressed then entries.selected_by_mouse = entry_index;
                if entries.selected_by_mouse == -1 then draw_rect(entry_rect, highlight_color_lite);
                if entries.selected_by_mouse == entry_index && mouse.left.just_released then open_file_dialog_open_entry(entry_index, on_the_side = ctrl_pressed());
            }
            if entries.selected_by_mouse == entry_index {
                highlight_color_lite.a = 0.8;
                draw_rect(entry_rect, highlight_color_lite);
            }
            if entry_index == selected then draw_rect(entry_rect, Colors.BACKGROUND_BRIGHT);

            pen := make_vector2(
                entry_rect.x + 2 * margin,
                entry_rect.y + (entry_rect.h - font_ui.character_height) / 2 + 2 * dpi_scale,
            );
            width: float;

            // Draw file icon
            icon_char := convert_utf32_to_utf8(xx entry.icon);
            Simp.draw_text(font_icons, xx pen.x, xx pen.y, to_string(*icon_char), color = Colors.CODE_PUNCTUATION);

            // Draw name
            pen.x += xx font_icons.em_width + padding;
            width += xx Simp.prepare_text(font_ui, entry.name);
            Simp.draw_prepared_text(font_ui, xx pen.x, xx pen.y, color = Colors.CODE_PUNCTUATION);

            // // Draw separator
            // pen.x += width + padding;
            // width = xx Simp.prepare_text(font_ui_small, BULLET_CHAR);
            // Simp.draw_prepared_text(font_ui_small, xx pen.x, xx pen.y, color = Colors.CODE_COMMENT);

            // Draw file path
            pen.x += width + padding;
            if pen.x < path_align_x then pen.x = path_align_x;
            width = xx Simp.prepare_text(font_ui_small, entry.path);
            Simp.draw_prepared_text(font_ui_small, xx pen.x, xx pen.y, color = Colors.CODE_COMMENT);
        }

        // Deselect any previously clicked entry
        if mouse.left.just_released || !mouse.left.is_down then entries.selected_by_mouse = -1;

        // Shadow
        if scroll_y != 0 {
            shadow_rect := cut_top(files_rect, char_size);
            t := Colors.SHADOW_TRANSPARENT;
            s := Colors.SHADOW_DARK;
            Simp.set_shader_for_color(enable_blend = true);
            draw_rect_raw(shadow_rect, c00 = t, c10 = t, c01 = s, c11 = s);
        }
    }

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

draw_text_input :: (using input: *Text_Input, rect: Rect, font: *Simp.Dynamic_Font = null, color := Colors.UI_DEFAULT) {
    if font == null then font = font_ui;
    padding := (rect.h - cast(float) font.default_line_spacing) / 2;

    draw_rounded_rect(rect, Colors.BACKGROUND_DARK);
    input_rect := shrink(rect, 1);

    if mouse_pointer_is_within(input_rect) then set_pointer_image(.TEXT_SELECT);

    push_scissor(shrink_x(input_rect, 1));
    defer pop_scissor();

    draw_rounded_rect(input_rect, Colors.BACKGROUND);
    input_rect = shrink(input_rect, padding);

    input_text := to_string(text);
    cursor_width := 2 * dpi_scale;
    cursor_pos_x := Simp.get_text_width(font, slice_chars(input_text, 0, cursor.pos));

    scroll_x_target := scroll_anim.target;
    if cursor_pos_x - scroll_x_target >= cast(s32) input_rect.w then scroll_x_target = cast(s32) cursor_pos_x - cast(s32) input_rect.w;
    if cursor_pos_x < scroll_x_target then scroll_x_target = xx cursor_pos_x;
    if scroll_x_target != scroll_anim.target then set_scroll_target(*scroll_anim, scroll_x, scroll_x_target, S32_MAX);

    scrolling := false;
    scroll_x, scrolling = animate_scrolling(*scroll_anim, scroll_x);
    if scrolling then redraw_requested = true;

    x := input_rect.x - scroll_x;
    cursor_rect := cut_left(input_rect, cursor_width);
    cursor_rect.y -= 1;  // manual alignment
    cursor_rect.x = x + cursor_pos_x;

    if cursor.pos != cursor.sel {
        cursor_sel_x := Simp.get_text_width(font, slice_chars(input_text, 0, cursor.sel));
        left  := min(cursor_pos_x, cursor_sel_x);
        right := max(cursor_pos_x, cursor_sel_x);
        selection_rect := cursor_rect;
        selection_rect.x = x + left;
        selection_rect.w = xx (right - left);
        draw_rect(selection_rect, Colors.SELECTION_ACTIVE);
    }

    draw_rect(cursor_rect, Colors.CURSOR);

    y := input_rect.y + (input_rect.h - font.character_height) / 2 + 2 * dpi_scale;  // I don't know why we need this extra + 2, but without it the text doesn't look in the right place
    Simp.draw_text(font, xx x, xx y, input_text, color = color);
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


#scope_file

push_scissor :: (rect: Rect) {
    set_scissor_rect(rect);
    array_add(*scissor_stack, rect);
}

pop_scissor :: () {
    assert(scissor_stack.count > 0);
    pop(*scissor_stack);
    if scissor_stack.count > 0 {
        rect := peek(scissor_stack);
        set_scissor_rect(rect);
    } else {
        Simp.clear_scissor();
    }
}

set_scissor_rect :: (rect: Rect) {
    x0 := cast(s32) rect.x;
    y0 := cast(s32) rect.y;
    x1 := cast(s32) (rect.x + rect.w);
    y1 := cast(s32) (rect.y + rect.h);
    Simp.set_scissor(x0, y0, x1, y1);
}

no_active_ui_item :: inline () -> bool {
    return ui.active == .none;
}

get_ui_id_from_loc :: inline (loc := #caller_location, parent_id: Ui_Id = .none) -> Ui_Id {
    REALLY_BIG_NUMBER :: 100_000;  // jk, just needs to be less than we have widgets
    if parent_id != .none {
        return cast(Ui_Id) (loc.line_number + REALLY_BIG_NUMBER * cast(s64) parent_id);
    }
    return cast(Ui_Id) loc.line_number;
}

draw_scrollbar :: (main_rect: Rect, width: float, content_height: float, scroll: s32, scroll_target: s32, max_scroll: s32, ui_id: Ui_Id) -> new_scroll_target: s32 {
    if max_scroll <= 0 return scroll_target;

    area := cut_right(main_rect, width);  // the scrollbar area of the main rect
    scrollbar := area;  // handle
    scrollbar.h = area.h * (area.h / content_height);
    scroll_zone_size := area.h - scrollbar.h;  // the room for y to move

    if scroll_zone_size <= 0 return scroll_target;  // don't draw

    if mouse_pointer_is_within(area) {
        ui.hot = ui_id;
        if ui.hot_last_frame == ui_id && mouse.left.just_pressed then ui.active = ui_id;
    }

    // Draw
    color := Colors.SCROLLBAR;
    rounding_radius := 2 * dpi_scale;

    if ui.active == ui_id || (ui.hot_last_frame == ui_id && ui.active == .none) {
        set_pointer_image(.NORMAL);
        draw_rounded_rect(area, Colors.SCROLLBAR_BACKGROUND, radius = rounding_radius);
        color = Colors.SCROLLBAR_HOVER;
    }
    separator_rect := shrink_y(cut_left(area, 1), rounding_radius);
    draw_rect(separator_rect, Colors.SCROLLBAR_BACKGROUND);
    scrollbar.y += (cast(float) (max_scroll - scroll) / max_scroll) * scroll_zone_size;
    scrollbar = shrink(scrollbar, 1);
    if scrollbar.h < 5 then scrollbar.h = 5;  // don't make it too tiny
    draw_rounded_rect(scrollbar, color, radius = rounding_radius);

    // Maybe drag the slider
    if ui.active == ui_id {
        if mouse.left.just_pressed {
            if mouse_pointer_is_within(scrollbar) {
                // Grab the slider at this point
                scrollbar_grab_point = mouse.pointer.y - (scrollbar.y + scrollbar.h / 2);
            } else {
                // Clicked outside scrollbar, jump to it
                scrollbar_grab_point = 0;
            }
        }
        new_scrollbar_pos_from_top := (area.h - (mouse.pointer.y - scrollbar_grab_point - area.y)) - scrollbar.h / 2;
        new_scroll_percentage := new_scrollbar_pos_from_top / (area.h - scrollbar.h);
        new_scroll_target: = max_scroll * new_scroll_percentage;
        return clamp(cast(s32) new_scroll_target, 0, max_scroll);
    } else {
        return scroll_target;
    }
}

ui: struct {
    active: Ui_Id = .none;
    hot:    Ui_Id = .none;
    hot_last_frame: Ui_Id = .none;
}

Ui_Id :: enum s64 {
    unavailable :: -2;
    none :: -1;

    editor_single :: -3;
    editor_left   :: -4;
    editor_right  :: -5;
    editor_splitter   :: -6;
    open_file_dialog  :: -7;

    // The rest will be derived from loc
}

// NOTE: this is a silly global variable which represents the distance between
// the center of slider and the point where we grabbed it.
// Since we can only drag one slider at a time, this will work, but in a more
// clean way this should probably be stored in widget storage?
// Problem is, we don't have much else to store for scrollbars...
scrollbar_grab_point: float;

scissor_stack: [..] Rect;
