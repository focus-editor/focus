draw_frame :: () {
    {
        using Colors.BACKGROUND;
        Simp.clear_render_target(r, g, b, a);
    }

    // Check whether we need to deactivate elements before drawing
    if !mouse.left.is_down || mouse.left.just_released then ui.active = .none;

    footer_height := font_ui_line_height * 1.6;

    // Draw editors
    if #complete editors.layout == {
        case .None;
            editors_snap_splitter(0.5);
            // TODO: draw a shortcut cheat-sheet?
        case .Single;
            editors_snap_splitter(0.5);
            draw_editor(editors.active, screen, footer_height, .editor_single);
        case .Double;
            // Drag splitter
            if ui.active == .editor_splitter {
                editors_snap_splitter((mouse.pointer.x - screen.x) / screen.w);
                editors.expanded = false;
            }
            if !values_are_close(splitter_pos, splitter_anim.target) {
                redraw_requested = true;
                splitter_pos = get_animation_value(splitter_anim);  // removed the clamp because we want to close smoothly. Will this cause problems? Not sure
            } else if editors.closing {
                finish_closing_editor();
            }
            if editors.expanded {
                if editors.active == editors.left  && !values_are_close(splitter_anim.target, 0.9) then editors_start_moving_splitter(0.9);
                if editors.active == editors.right && !values_are_close(splitter_anim.target, 0.1) then editors_start_moving_splitter(0.1);
            }

            split_x := screen.w * splitter_pos;
            left_rect, right_rect := cut_left(screen, split_x, margin = 2);

            draw_editor(editors.left,  left_rect,  footer_height, .editor_left,  screen);
            draw_editor(editors.right, right_rect, footer_height, .editor_right, screen);

            splitter_rect := make_rect(left_rect.x + left_rect.w, left_rect.y + footer_height, 2, left_rect.h - footer_height);
            draw_splitter(splitter_rect, split_x, .editor_splitter);
    }

    // Open file dialog is modal so if it's shown it means it receives input
    if active_global_widget == .open_file_dialog then draw_open_file_dialog();
    if active_global_widget == .finder           then draw_finder();

    // Reset UI state after drawing
    if !mouse.left.is_down || mouse.left.just_released {
        ui.active = .none;
    } else if ui.active == .none {
        ui.active = .unavailable;  // so that we don't activate anything by dragging on it
    }
    ui.hot_last_frame = ui.hot;

    Simp.swap_buffers(window);
}

draw_splitter :: (splitter_rect: Rect, split_x: float, ui_id: Ui_Id) {
    color := Colors.SPLITTER;

    rect := splitter_rect;
    rect_fat := expand(splitter_rect, 3 * dpi_scale);

    maybe_set_hot_or_active(ui_id, rect_fat, .DRAGGING_HORIZONTAL);

    if (ui.hot_last_frame == ui_id && ui.active == .none) || ui.active == ui_id {
        if ui.active == ui_id then color = Colors.SPLITTER_HOVER;
        rect = expand(rect, 2);
    }

    draw_rect(rect, color);
}

draw_editor :: (editor_id: s64, main_area: Rect, footer_height: float, ui_id: Ui_Id, total_editor_area := Rect.{}) {
    scrollbar_id := get_ui_id_from_loc(parent_id = ui_id);

    footer_rect, rect := cut_bottom(main_area, footer_height);
    if !is_valid(rect) return;

    using editor := *open_editors[editor_id];
    buffer := *open_buffers[buffer_id];

    editor_is_active := editor_id == editors.active && Input.input_application_has_focus;

    // Calculate text origin in screen coordinates
    text_offset := make_vector2(char_size * 2, -char_size * 2);
    text_origin := top_left(rect) + text_offset - make_vector2(xx viewport.left, line_height - viewport.top);

    // Draw editor
    {
        push_scissor(rect);
        defer pop_scissor();

        became_active := maybe_set_hot_or_active(ui_id, rect, .TEXT_SELECT);
        if became_active then active_global_widget = .editors;
        
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
            if mouse.left.just_triple_clicked then select_lines(cursor, buffer);

            editor.refresh_highlights = true;

            // Activate editor
            editors.active = editor_id;
            redraw_requested = true;  // so that we don't draw 2 active editors
        }

        // Handle editor scrolling here because we only know the layout at this point.
        // Some people would say this is not "clean", but hey, we'll see if we have any issues.
        max_y_scroll := get_max_y_scroll(buffer);
        if (ui.hot_last_frame == ui_id || ui.hot_last_frame == scrollbar_id) && mouse_pointer_is_within(rect) && mouse.scroll_y_delta != 0 {
            using editor.viewport;
            new_target := clamp(scroll_y.target - mouse.scroll_y_delta, 0, max_y_scroll);
            start_animation(*scroll_y, top, new_target);
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

                left_target := max(viewport.left + cast(s32) offset.x, 0);
                top_target  := clamp(viewport.top - cast(s32) offset.y, 0, max_y_scroll);

                if left_target != viewport.scroll_x.target then start_animation(*viewport.scroll_x, viewport.left, left_target);
                if top_target  != viewport.scroll_y.target then start_animation(*viewport.scroll_y, viewport.top,  top_target);
            }
        } else if scroll_to_cursor != .no {
            using editor.viewport;
            
            // Use the target editor width (not current width) when a new editor is appearing
            editor_width := ifx scroll_to_cursor == .yes_new_editor then total_editor_area.w / 2 else rect.w;
            
            cursor_pos_from_left := cursors[main_cursor].pos.col * char_size + text_offset.x;
            left_target := cast(s32)(cursor_pos_from_left - editor_width + char_size * 3);
            if left_target < 0 then left_target = 0;
            if left_target != scroll_x.target then start_animation(*viewport.scroll_x, viewport.left, left_target);

            cursor_pos_from_top := cursors[main_cursor].pos.line * line_height;
            top_target := cast(s32)(cursor_pos_from_top - rect.h / 2);
            if top_target < 0 then top_target = 0;
            if top_target != scroll_y.target then start_animation(*viewport.scroll_y, viewport.top, top_target);            

            scroll_to_cursor = .no;
        }

        // Maybe update selection highlights
        if editor.refresh_highlights {
            editor.refresh_highlights = false;
            array_reset_keeping_memory(*editor.highlights);
            
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
        new_scroll_target := draw_scrollbar(rect, scrollbar_size, rect.h + xx max_y_scroll, viewport.top, viewport.scroll_y.target, max_y_scroll, scrollbar_id);
        if new_scroll_target != viewport.scroll_y.target {
            // Jump immediately to the scroll point when dragging or clicking scrollbar
            viewport.top = new_scroll_target;
            viewport.scroll_y.target = new_scroll_target;
            redraw_requested = true;
        }

        // Smooth keyboard scrolling
        if editor_smooth_scroll.active && editor_id == editors.active {
            speed := 60 * line_height;  // pixels per second
            time_elapsed := cast(float) (frame_time - editor_smooth_scroll.started_at);
            new_scroll_pos := editor_smooth_scroll.start_y + time_elapsed * speed * (ifx editor_smooth_scroll.up then -1 else 1);
            viewport.top = clamp(cast(s32) new_scroll_pos, 0, max_y_scroll);
            viewport.scroll_y.target = viewport.top;
            redraw_requested = true;
        }

        // Vertical scrolling
        if viewport.top != viewport.scroll_y.target {
            redraw_requested = true;
            viewport.top = get_animation_value(viewport.scroll_y);
        }

        // Horizontal scrolling
        if viewport.left != viewport.scroll_x.target {
            redraw_requested = true;
            viewport.left = get_animation_value(viewport.scroll_x);
        }

        // Need to update after updating scrolling to reduce latency
        text_origin = top_left(rect) + text_offset - make_vector2(xx viewport.left, line_height - viewport.top);

        visible_lines_start := cast(s64) (viewport.top / line_height) - 1;
        visible_lines_start  = clamp(visible_lines_start, 0, buffer.lines.count);
        visible_lines_end := visible_lines_start + cast(s64) (rect.h / line_height) + 1;
        visible_lines_end  = clamp(visible_lines_end,   0, buffer.lines.count);

        // Draw scrollbar marks
        {
            Simp.set_shader_for_color(enable_blend = true);
            
            marks_rect := cut_right(rect, scrollbar_size);
            marks_rect =  cut_top(marks_rect, rect.h * max_y_scroll / (rect.h + xx max_y_scroll));  // account for the non-text area at the bottom
            marks_rect_top := marks_rect.y + marks_rect.h;
            assert(buffer.lines.count > 0);
            mark_line_height := marks_rect.h / cast(float)buffer.lines.count;  // the height of the rect which corresponds to one line

            highlight_mark_rect := shrink_x(marks_rect, marks_rect.w / 3);
            highlight_mark_rect.h = 4 * dpi_scale;

            if search_bar_is_open(editor) && search_bar.results {
                // Search results
                for search_bar.results {
                    highlight_mark_rect.y = marks_rect_top - it.start_pos.line * mark_line_height - highlight_mark_rect.h;
                    draw_rect_raw(highlight_mark_rect, ifx it_index == search_bar.selected_result then Colors.SEARCH_RESULT_ACTIVE else Colors.SEARCH_RESULT_INACTIVE);
                }
            }

            if !search_bar_is_open(editor) {
                // Selection highlights
                for highlights {
                    highlight_mark_rect.y = marks_rect_top - it.start_pos.line * mark_line_height - highlight_mark_rect.h;
                    draw_rect_raw(highlight_mark_rect, Colors.SELECTION_HIGHLIGHT);
                }
            }

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

        // Draw selection highlights
        if !search_bar_is_open(editor) {
            for highlights {
                if it.start_pos.line < visible_lines_start continue;
                if it.start_pos.line > visible_lines_end   break;

                range: Range = ---;
                range.start = it.start_pos;
                range.end   = offset_to_pos(buffer, it.offset + selected_text_length);
                draw_range(range, buffer, visible_lines_start, visible_lines_end, text_origin, Colors.SELECTION_HIGHLIGHT);
            }
        }

        // Draw cursors after selection highlights, but before search results
        cursors_active := editor_is_active && active_global_widget == .editors;
        draw_selections(editor, buffer, rect, text_origin, visible_lines_start, visible_lines_end, cursors_active);

        // Draw search results
        if search_bar_is_open(editor) {
            for search_bar.results {
                if it.start_pos.line < visible_lines_start continue;
                if it.start_pos.line > visible_lines_end   break;

                range: Range = ---;
                range.start = it.start_pos;
                range.end   = offset_to_pos(buffer, it.offset + search_bar.input.text.count);
                color := ifx search_bar.selected_result == it_index then Colors.SEARCH_RESULT_ACTIVE else Colors.SEARCH_RESULT_INACTIVE;
                draw_range(range, buffer, visible_lines_start, visible_lines_end, text_origin, color);
            }
        }

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
        hidden_chars_on_left := cast(s32) (viewport.left / char_size) - 2;
        if hidden_chars_on_left < 0 then hidden_chars_on_left = 0;
        max_chars_per_page   := cast(s32) (main_area.w   / char_size) + 2;
        pen.x += hidden_chars_on_left * char_size;
        code_ranges: [..] Simp.Code_Range;  // visible code ranges
        code_ranges.allocator = temp;
        for line : visible_lines {
            range := array_add(*code_ranges);
            range.start = move_offset_by_chars(line.start,  hidden_chars_on_left, buffer.bytes, line.end);
            range.end   = move_offset_by_chars(range.start, max_chars_per_page,   buffer.bytes, line.end);
        }
        if buffer.needs_coloring || buffer.colors.count != buffer.bytes.count then recalculate_colors(buffer);  // right before drawing
        Simp.draw_code(font, xx pen.x, xx pen.y, char_size, line_height, code_ranges, buffer.bytes, buffer.colors, CODE_COLOR_MAP);
        
        // Draw cursors on top of text
        if !editor.search_bar.active {
            draw_cursors(editor, buffer, rect, text_origin, cursors_active);
        }
    }

    // Draw search bar
    if search_bar_is_open(editor) {
        using search_bar;
        input_id := get_ui_id_from_loc(parent_id = ui_id);

        // Update openness
        if openness != open_anim.target {
            openness = clamp(get_animation_value(open_anim), 0.0, 1.0);
            redraw_requested = true;
        }
        
        if width_percentage != width_anim.target {
            width_percentage = get_animation_value(width_anim);
            redraw_requested = true;
        }

        margin_x := 12 * dpi_scale;
        margin_y :=  7 * dpi_scale;
        padding  :=  4 * dpi_scale;
        bar_rect_height := font_ui_line_height + 2 * padding + 2 * margin_y + 2;

        bar_rect := cut_top(main_area, bar_rect_height);
        bar_rect = cut_right(bar_rect, bar_rect.w * width_percentage);
        bar_rect.x -= 2 * char_size;
        bar_rect.y += bar_rect_height * (1.0 - openness);
        
        draw_rounded_rect_with_shadow(bar_rect, Colors.BACKGROUND_LIGHT);
        
        push_scissor(bar_rect);
        defer pop_scissor();

        // Clicking on the bar should activate input
        maybe_set_hot_or_active(input_id, bar_rect, .NORMAL);

        result_label: string;
        if results {
            result_label = tprint("% of %", selected_result + 1, results.count);
        } else {
            result_label = "No results";
        }
        results_width := cast(float) Simp.prepare_text(font_ui_small, result_label);
        bar_rect = shrink_x(bar_rect, margin_x);
        bar_rect = shrink_y(bar_rect, margin_y);
        results_rect, input_rect := cut_right(bar_rect, results_width + padding);

        Simp.draw_prepared_text(font_ui_small, xx (results_rect.x + padding), xx (results_rect.y + (results_rect.h - font_ui_small.character_height) / 2.0), color = Colors.UI_DEFAULT);
        input_active := editor_is_active && search_bar.active && active_global_widget == .editors;
        draw_text_input(*search_bar.input, input_rect, active = input_active, ui_id = input_id, label = "Find in buffer");

        if ui.active != .none && ui.active != input_id {
            active = false;  // deactivate on clicks elsewhere
            redraw_requested = true;
        }
        if ui.active == input_id {
            active = true;  // activate on click
            editors.active = editor_id;  // make sure the editor is also activated
            redraw_requested = true;
        }
    }

    // Draw footer
    {
        footer_color := Colors.BACKGROUND_BRIGHT;
        draw_rect(footer_rect, footer_color);
        draw_top_shadow(footer_rect);

        push_scissor(footer_rect);
        defer pop_scissor();

        footer_rect = shrink_x(footer_rect, text_offset.x);

        width   := 0.0;
        padding := 4 * dpi_scale;

        pen := make_vector2(
            footer_rect.x,
            footer_rect.y + (footer_rect.h - font_ui.character_height) / 2 + 2 * dpi_scale,
        );

        // Draw file name and path
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

            pen.x += width;
        } else {
            // No file
            icon_char := convert_utf32_to_utf8(xx File_Icon.text);
            width = xx Simp.prepare_text(font_icons, to_string(*icon_char));
            Simp.draw_prepared_text(font_icons, xx pen.x, xx pen.y, color = file_name_color);

            // File name
            pen.x += width + padding;
            width = xx Simp.prepare_text(font_ui, "<new file>");
            Simp.draw_prepared_text(font_ui, xx pen.x, xx pen.y, color = file_name_color);

            pen.x += width;
        }

        // Draw line and column numbers
        {
            cut_rect := footer_rect;
            cut_rect.x = pen.x + padding;
            cut_rect.w = footer_rect.x + footer_rect.w - cut_rect.x;
            push_scissor(cut_rect);
            defer pop_scissor();

            cursor := cursors[main_cursor];
            width = xx Simp.prepare_text(font_ui_bold, tprint("Line: %  Col: %", cursor.pos.line + 1, cursor.pos.col + 1));
            line_col_start_x := footer_rect.x + footer_rect.w - width;
            Simp.draw_prepared_text(font_ui_bold, xx line_col_start_x, xx pen.y, color = Colors.CODE_COMMENT);

            // Make sure the text is cut nicely
            fadeout_rect := cut_rect;
            fadeout_rect.w = 4 * padding;
            trans := footer_color;
            trans.a = 0;
            Simp.set_shader_for_color(enable_blend = true);
            draw_rect_raw(fadeout_rect, c00 = footer_color, c10 = trans, c01 = footer_color, c11 = trans);
        }
    }

}

draw_open_file_dialog :: () {
    using open_file_dialog;

    ui_id := Ui_Id.open_file_dialog;
    scrollbar_id := get_ui_id_from_loc(parent_id = ui_id);

    if ui.active != .none && ui.active != ui_id && !is_child(ui.active, ui_id) {
        // Close the dialog on clicks elsewhere
        hide_open_file_dialog();
        return;
    }

    margin  := floor(12 * dpi_scale);
    padding := floor( 4 * dpi_scale);
    input_rect_height := font_ui_line_height + 2 * padding + 2 * margin + 2;
    entry_height := font_ui_line_height + padding * 2;

    // Figure out the dialog box size
    box_rect: Rect = ---;
    {
        if width_percentage != width_anim.target {
            width_percentage = get_animation_value(width_anim);
            redraw_requested = true;
        }
        width  := floor(clamp(screen.w * width_percentage, 400 * dpi_scale, 2000 * dpi_scale));        
        height := floor(clamp(input_rect_height + entry_height * entries.filtered.count + padding, 0, screen.h / 1.5));
        x := floor((screen.w - width) / 2);
        y := floor(clamp(100 * dpi_scale, 0, (screen.h - height) / 2));
        box_rect = make_rect(x, screen.h - height - y, width, height);
        if !is_valid(box_rect) return;
    }
    draw_rounded_rect_with_shadow(box_rect, Colors.BACKGROUND_LIGHT, radius = rounding_radius_large);

    maybe_set_hot_or_active(ui_id, box_rect, .NORMAL);

    // Draw the filter input
    input_rect, files_rect := cut_top(box_rect, input_rect_height);
    input_rect = shrink(input_rect, margin);
    input_id := get_ui_id_from_loc(parent_id = ui_id);
    
    if mode == .search {
        label := ifx finder.initted then " Search files by name" else " Still indexing project files. Please wait...";
        draw_text_input(*open_file_dialog.input, input_rect, ui_id = input_id, active = true, label = label);
        if !finder.initted then redraw_requested = true;  // update as soon as we're done
    } else {
        label := ifx path_chunks then "" else " Navigate to file";
        
        half_padding := floor(padding / 2);
        
        // Figure out how much to pad on the left (if only there were a Javascript library for that…)
        margin_left := 0.0;
        for path_chunks { margin_left += cast(float) Simp.get_text_width(font_ui, it) + padding * 2 + half_padding * 3; }
        
        draw_text_input(*open_file_dialog.input, input_rect, ui_id = input_id, active = true, label = label, margin_left = margin_left);
        
        push_scissor(shrink_x(input_rect, padding));
        defer pop_scissor();
        
        dir_rect := shrink(input_rect, padding);
        text_y := dir_rect.y + floor((dir_rect.h - cast(float)font_ui.em_width) / 2);
        for path_chunks {
            width := cast(float) Simp.prepare_text(font_ui, it);
            dir_rect.w = width + 2 * padding + 2 * half_padding;
            color := Colors.SELECTION_ACTIVE;
            if ui.hot_last_frame == input_id && mouse_pointer_is_within(dir_rect) {
                color = Colors.LIST_CURSOR;
                set_pointer_image(.PRESSABLE);
                if mouse.left.just_pressed { open_file_dialog_truncate_path_chunks(it_index); redraw_requested = true; }
            }
            draw_rounded_rect(dir_rect, color);
            Simp.draw_prepared_text(font_ui, xx (dir_rect.x + padding + half_padding), xx text_y, Colors.UI_DEFAULT);
            dir_rect.x += dir_rect.w + half_padding;
        }
    }
    
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
            new_scroll_target := draw_scrollbar(files_rect, scrollbar_size, content_height, scroll_y, scroll_anim.target, xx max_y_scroll, scrollbar_id);
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
                if target != scroll_anim.target then start_animation(*scroll_anim, scroll_y, target);
                scroll_to_cursor = false;
            }

            // Mouse scrolling
            if (ui.hot_last_frame == ui_id || ui.hot_last_frame == scrollbar_id) && mouse_pointer_is_within(files_rect) {
                if ui.hot_last_frame == ui_id && ui.active == .none then set_pointer_image(.PRESSABLE);
                if mouse.scroll_y_delta != 0 {
                    target := clamp(scroll_anim.target - mouse.scroll_y_delta, 0, xx max_y_scroll);
                    start_animation(*scroll_anim, scroll_y, target);
                }
            }

            if scroll_y != scroll_anim.target {
                redraw_requested = true;
                scroll_y = get_animation_value(scroll_anim);
            }
        }

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
                if entries.selected_by_mouse == -1 then draw_rect(entry_rect, Colors.LIST_CURSOR_LITE);
                placement := ifx ctrl_pressed() then Editor_Placement.on_the_side else .in_place;
                if entries.selected_by_mouse == entry_index && mouse.left.just_released {
                    open_file_dialog_open_entry(entry_index, placement);
                    redraw_requested = true;
                    break;  // don't finish drawing entries because the entries will likely change
                }
            }
            if entries.selected_by_mouse == entry_index then draw_rect(entry_rect, Colors.LIST_CURSOR);
            if entry_index == selected then draw_rect(entry_rect, Colors.LIST_CURSOR);

            pen := make_vector2(
                entry_rect.x + margin + padding,
                entry_rect.y + (entry_rect.h - font_ui.character_height) / 2 + 2 * dpi_scale,
            );
            width: float;
            
            name_color := ifx entry.flags & .MODIFIED then Colors.UI_WARNING else Colors.UI_DEFAULT;

            // Draw file icon
            icon_char := convert_utf32_to_utf8(xx entry.icon);
            icon_width := Simp.prepare_text(font_icons, to_string(*icon_char));
            icon_x := pen.x - (icon_width - font_icons.em_width) / 2.0;
            Simp.draw_prepared_text(font_icons, xx icon_x, xx pen.y, color = name_color);

            // Draw name
            pen.x += xx font_icons.em_width + padding * 1.5;
            width = xx Simp.draw_text_with_highlights(font_ui, xx pen.x, xx pen.y, entry.name, entry.name_highlights, color = name_color, highlight_color = Colors.LETTER_HIGHLIGHT);
            
            if entry.flags & .MODIFIED_ON_DISK {
                pen.x += width + padding;
                width = xx Simp.draw_text(font_ui_bold, xx pen.x, xx pen.y, "[modified on disk]", color = Colors.UI_ERROR);
            }

            // // Draw score
            // pen.x += width + padding;
            // width = xx Simp.prepare_text(font_ui_small, tprint("%", formatInt(entry.sort_key, base=16)));
            // Simp.draw_prepared_text(font_ui_small, xx pen.x, xx pen.y, color = Colors.CODE_COMMENT);

            // Draw file path
            pen.x += width + padding;
            if pen.x < path_align_x then pen.x = path_align_x;
            width = xx Simp.draw_text_with_highlights(font_ui, xx pen.x, xx pen.y, entry.path, entry.path_highlights, color = Colors.CODE_COMMENT, highlight_color = Colors.LETTER_HIGHLIGHT);
        }

        // Deselect any previously clicked entry
        if mouse.left.just_released || !mouse.left.is_down then entries.selected_by_mouse = -1;

        if scroll_y != 0 then draw_top_down_shadow(cut_top(files_rect, char_size));
    }
}

draw_finder :: () {
    using finder;

    ui_id := Ui_Id.finder;
    scrollbar_id := get_ui_id_from_loc(parent_id = ui_id);

    if ui.active != .none && ui.active != ui_id && !is_child(ui.active, ui_id) {
        finder_close();
        return;
    }

    margin  := 12 * dpi_scale;
    padding :=  4 * dpi_scale;
    input_rect_height := font_ui_line_height + 2 * padding + 2 * margin + 2;
    entry_height := font_ui_line_height + padding * 2;

    // Figure out the dialog box size
    box_rect: Rect = ---;
    {
        if width_percentage != width_anim.target {
            width_percentage = get_animation_value(width_anim);
            redraw_requested = true;
        }
        width := screen.w * width_percentage;
        if width < 700 * dpi_scale then width = 700 * dpi_scale;
        
        height := clamp(input_rect_height + entry_height * results.count + padding, 0, screen.h / 1.2);
        x := (screen.w - width) / 2;
        y := clamp(100 * dpi_scale, 0, (screen.h - height) / 2);
        box_rect = make_rect(x, screen.h - height - y, width, height);
        if !is_valid(box_rect) return;
    }
    draw_rounded_rect_with_shadow(box_rect, Colors.BACKGROUND_LIGHT, radius = rounding_radius_large);

    maybe_set_hot_or_active(ui_id, box_rect, .NORMAL);

    // Draw the filter input
    input_rect, files_rect := cut_top(box_rect, input_rect_height);
    input_rect = shrink(input_rect, margin);
    input_id := get_ui_id_from_loc(parent_id = ui_id);
    label := ifx initted then "Type to search within project" else "Still indexing. Please wait...";
    draw_text_input(*finder.input, input_rect, ui_id = input_id, active = true, label = label);
    _pad: Rect = ---;  // allow some space at the bottom so that we don't cover up the rounded corners with the cursor
    _pad, files_rect = cut_bottom(files_rect, padding);

    // Draw search results
    {
        // Remember how many fits per page
        per_page = cast(s64) (files_rect.h / entry_height);
        if per_page <= 0 then per_page = 2;

        push_scissor(files_rect);
        defer pop_scissor();

        {
            // Scrollbar
            content_height := results.count * entry_height;
            max_y_scroll := content_height - files_rect.h;
            new_scroll_target := draw_scrollbar(files_rect, scrollbar_size, content_height, scroll_y, scroll_anim.target, xx max_y_scroll, scrollbar_id);
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
                if target != scroll_anim.target then start_animation(*scroll_anim, scroll_y, target);
                scroll_to_cursor = false;
            }

            // Mouse scrolling
            if (ui.hot_last_frame == ui_id || ui.hot_last_frame == scrollbar_id) && mouse_pointer_is_within(files_rect) {
                if ui.hot_last_frame == ui_id && ui.active == .none then set_pointer_image(.PRESSABLE);
                if mouse.scroll_y_delta != 0 {
                    target := clamp(scroll_anim.target - mouse.scroll_y_delta, 0, xx max_y_scroll);
                    start_animation(*scroll_anim, scroll_y, target);
                }
            }

            if scroll_y != scroll_anim.target {
                redraw_requested = true;
                scroll_y = get_animation_value(scroll_anim);
            }
        }
        
        if !initted {
            redraw_requested = true;
            return;
        }

        visible_start := clamp(cast(s64) (scroll_y / entry_height), 0, results.count);
        visible_count := cast(s64) (files_rect.h / entry_height) + 2;
        visible_entries := array_view(results, visible_start, visible_count);

        line_num_col_width := char_size * 6;
        line_num_x := files_rect.x + files_rect.w / 4;
        text_x     := line_num_x + line_num_col_width + 2 * char_size;
        
        max_code_chars := cast(s32)((files_rect.x + files_rect.w - text_x) / char_size) - 1;  // NOTE: counts tab as one char
            
        entry_rect := cut_top(files_rect, entry_height);
        filename_scissor := cut_left(files_rect, line_num_x - entry_rect.x - char_size);
        if !is_valid(filename_scissor) then filename_scissor = entry_rect;

        for entry, i : visible_entries {
            entry_index := visible_start + i;
            entry_rect.y = files_rect.y + files_rect.h - (entry_index + 1) * entry_height + scroll_y;

            if mouse_pointer_is_within(entry_rect) && ui.hot_last_frame == ui_id && (ui.active == .none || ui.active == ui_id) {
                if mouse.left.just_pressed then selected_by_mouse = entry_index;
                if selected_by_mouse == -1 then draw_rect(entry_rect, Colors.LIST_CURSOR_LITE);
                placement := ifx ctrl_pressed() then Editor_Placement.on_the_side else .in_place;
                if selected_by_mouse == entry_index && mouse.left.just_released then finder_open_selected_result(entry_index, placement);
            }
            if selected_by_mouse == entry_index then draw_rect(entry_rect, Colors.LIST_CURSOR);
            if entry_index == selected then draw_rect(entry_rect, Colors.LIST_CURSOR);

            pen := make_vector2(
                entry_rect.x + 2 * margin,
                entry_rect.y + (entry_rect.h - font_ui.character_height) / 2 + 2 * dpi_scale,
            );
            width: float;
            
            // Not sure if it's cheaper to do this for the visible results only, but every frame,
            // or do it once when searching, but for every resuls (and bloat the search result size).
            // Chose the first option at least for now.
            buffer := *open_buffers[entry.buffer_id];
            line_num := offset_to_line(buffer, min(entry.match_offset, xx buffer.bytes.count));
            buffer_line := buffer.lines[line_num];
            
            // Draw file info
            {
                push_scissor(filename_scissor);
                defer pop_scissor();
                
                name_color := ifx buffer.modified then Colors.UI_WARNING else Colors.UI_DEFAULT;
    
                // Draw file icon
                icon_char := convert_utf32_to_utf8(xx buffer.file.icon);
                Simp.draw_text(font_icons, xx pen.x, xx pen.y, to_string(*icon_char), color = name_color);
    
                // Draw name
                pen.x += xx font_icons.em_width + padding;
                width += xx Simp.prepare_text(font_ui, buffer.file.name);
                Simp.draw_prepared_text(font_ui, xx pen.x, xx pen.y, color = name_color);
                
                if buffer.modified_on_disk {
                    pen.x += width + padding;
                    width = xx Simp.prepare_text(font_ui_bold, "[modified on disk]");
                    Simp.draw_prepared_text(font_ui_bold, xx pen.x, xx pen.y, color = Colors.UI_ERROR);
                }
    
                // Draw separator
                pen.x += width + padding;
                width = xx Simp.prepare_text(font_ui_small, BULLET_CHAR);
                Simp.draw_prepared_text(font_ui_small, xx pen.x, xx pen.y, color = Colors.CODE_COMMENT);
    
                // Draw file path
                pen.x += width + padding;
                width = xx Simp.prepare_text(font_ui_small, buffer.file.path);
                Simp.draw_prepared_text(font_ui_small, xx pen.x, xx pen.y, color = Colors.CODE_COMMENT);
            }
            
            // Line number
            width = xx Simp.prepare_text(font_ui_small, tprint("%", line_num + 1));
            Simp.draw_prepared_text(font_ui_small, xx (line_num_x + line_num_col_width - width), xx pen.y, color = Colors.CODE_COMMENT);
            
            // Draw code line
            {
                match_start := entry.match_offset;
                match_end   := min(entry.match_offset + finder.needle.count, buffer_line.end);  // if we have a multi-line match, we will still show only the first line
                line_start  := ifx buffer_line.text_start <= match_start then buffer_line.text_start else buffer_line.start;
                chars_until_match_start := get_num_chars(array_view(buffer.bytes, line_start, match_start - line_start));
                chars_until_match_end   := get_num_chars(array_view(buffer.bytes, line_start, match_end   - line_start));
                
                // Figure out whether we need to cut the line so that the match is visible
                char_offset := 0;
                byte_offset := 0;
                pad_chars := 2;
                if chars_until_match_end > max_code_chars {
                    if (chars_until_match_end - chars_until_match_start) >= max_code_chars {
                        // The match won't fit on the screen anyway - stick it to the left
                        char_offset = xx max(0, chars_until_match_start - pad_chars);
                    } else {
                        // Stick the match to the right
                        char_offset = chars_until_match_end - xx (max_code_chars - pad_chars);
                    }
                }
                if char_offset > 0 {
                    line_str := to_string(array_view(buffer.bytes, line_start, buffer_line.end));
                    byte_offset = slice_chars(line_str, 0, xx char_offset).count;
                }
                
                pen.x = text_x;
                if char_offset > 0 {
                    // Line was cut on the left, draw an ellipsis
                    Simp.draw_text(font, xx pen.x, xx pen.y, "…", color = Colors.CODE_COMMENT);
                    pen.x += char_size;
                }
                
                code_line: [1] Simp.Code_Range;  // one line
                code_line[0].start = line_start + xx byte_offset;
                code_line[0].end   = min(buffer_line.end, line_start + xx byte_offset + 4 * max_code_chars);  // max 4 bytes per char
                if buffer.needs_coloring || buffer.colors.count != buffer.bytes.count then recalculate_colors(buffer);  // right before drawing
                
                // Draw highlight
                highlight_rect := entry_rect;
                highlight_rect.x = pen.x + char_size * (chars_until_match_start - char_offset);
                highlight_rect.w = char_size * (chars_until_match_end - chars_until_match_start);
                draw_rect(shrink_y(highlight_rect, padding), Colors.SEARCH_RESULT_INACTIVE);
                
                Simp.draw_code(font, xx pen.x, xx pen.y, char_size, line_height, code_line, buffer.bytes, buffer.colors, CODE_COLOR_MAP);
            }
        }

        // Deselect any previously clicked entry
        if mouse.left.just_released || !mouse.left.is_down then selected_by_mouse = -1;

        if scroll_y != 0 then draw_top_down_shadow(cut_top(files_rect, char_size));
    }
}

get_cursor_screen_pos :: (text_origin: Vector2, pos: Pos) -> Vector2 {
    return make_vector2(
        text_origin.x + pos.col * char_size,
        text_origin.y - pos.line * line_height,
    );
}

draw_selections :: (using editor: Editor, buffer: Buffer, editor_rect: Rect, text_origin: Vector2, visible_start: s64, visible_end: s64, is_active: bool) {
    Simp.set_shader_for_rects();
    for cursor : cursors {
        if has_selection(cursor) {
            // Draw selection
            selection := get_selection(cursor);
            color := ifx is_active then Colors.SELECTION_ACTIVE else Colors.SELECTION_INACTIVE;
            draw_range(selection, buffer, visible_start, visible_end, text_origin, color);
        }
    }
}

draw_cursors :: (using editor: Editor, buffer: Buffer, editor_rect: Rect, text_origin: Vector2, is_active: bool) {
    Simp.set_shader_for_rects();
    for cursor : cursors {
        cursor_pos := get_cursor_screen_pos(text_origin, cursor.pos);

        // Uncomment if you need a line highlight
        // line_rect := cut_top(editor_rect, line_height);
        // line_rect.y = cursor_pos.y;
        // draw_rect_raw(line_rect, Colors.BACKGROUND_HIGHLIGHT);

        rect := make_rect(cursor_pos.x, cursor_pos.y, char_size, line_height);
        draw_rounded_rect(rect, Colors.CURSOR, radius = rounding_radius_small, set_shader = true);
        if !is_active {
            draw_rounded_rect(shrink(rect, 1), Colors.BACKGROUND, radius = rounding_radius_small, set_shader = false);
        }
        // Draw the letter on top for better visibility
        letter := get_letter_at_pos(buffer, cursor.pos);
        if letter != "\n" {
            Simp.draw_text(font, xx rect.x, xx (rect.y + (line_height - char_size) / 2), letter);
        }
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
            if next_start > first_char || next_end < first_char || next_end == 0 then bl = .in;
            if next_end < last_char then br = .in;
            if next_end > last_char then br = .out;
        }
        draw_rounded_rect_with_corners(rect, color, tl, tr, br, bl);
    }
}

draw_text_input :: (using input: *Text_Input, rect_: Rect, ui_id: Ui_Id, active := false, label: string = "", font: *Simp.Dynamic_Font = null, color := Colors.UI_DEFAULT, margin_left := 1.0, margin_right := 1.0) {
    if !is_valid(rect_) return;

    rect := align_to_grid(rect_);  // to get a consistent outline

    if font == null then font = font_ui;
    padding := (rect.h - cast(float) font.default_line_spacing) / 2;

    draw_rect(rect, ifx active then Colors.CURSOR_INACTIVE else Colors.BACKGROUND_DARK);
    input_rect := shrink(rect, 1);
    draw_rect(input_rect, Colors.BACKGROUND);

    maybe_set_hot_or_active(ui_id, input_rect, .TEXT_SELECT);

    input_rect.w -= (margin_left + margin_right);
    input_rect.x += margin_left;
        
    if !is_valid(input_rect) return;
    
    push_scissor(input_rect);
    defer pop_scissor();

    input_rect = shrink(input_rect, padding);

    input_text := to_string(text);
    cursor_width := 2 * dpi_scale;
    
    // Maybe set cursor on mouse click
    if is_hovering_over(ui_id) {
        if mouse.left.just_pressed || mouse.left.is_dragging {
            rel_x := cast(s64) (mouse.pointer.x - input_rect.x) + scroll_x;
            cursor.pos = Simp.get_cursor_pos_for_width(font, input_text, rel_x);
            if !shift_pressed() && !mouse_selection_mode then cursor.sel = cursor.pos;
        }
        if mouse.left.just_pressed then mouse_selection_mode = true;
        if mouse.left.just_double_clicked then select_word(input);
        if mouse.left.just_triple_clicked then select_all(input);
    }
    if mouse.left.just_released || !mouse.left.is_down then mouse_selection_mode = false;

    // @Speed: we currently don't limit the text size, so if it's too big we'll do a lot of work here every frame
    cursor_pos_x     := Simp.get_text_width(font, slice_chars(input_text, 0, cursor.pos));
    total_text_width := Simp.get_text_width(font, input_text);

    scroll_x_target := scroll_anim.target;
    if cursor_pos_x - scroll_x_target >= cast(s32) input_rect.w then scroll_x_target = cast(s32) cursor_pos_x - cast(s32) input_rect.w;
    if cursor_pos_x < scroll_x_target then scroll_x_target = xx cursor_pos_x;
    if total_text_width - scroll_x_target < cast(s32) input_rect.w then {
        scroll_x_target = max(cast(s32) total_text_width - cast(s32) input_rect.w, 0);  // always show as much text as possible
    }
    if scroll_x_target != scroll_anim.target then start_animation(*scroll_anim, scroll_x, scroll_x_target, snappy = true);

    if scroll_x != scroll_anim.target {
        redraw_requested = true;
        scroll_x = get_animation_value(scroll_anim);
    }

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

    y := input_rect.y + (input_rect.h - font.character_height) / 2 + 2 * dpi_scale;  // I don't know why we need this extra + 2, but without it the text doesn't look in the right place

    if !input_text then Simp.draw_text(font, xx x, xx y, label, color = Colors.UI_TEXT_INPUT_LABEL);
    draw_rect(cursor_rect, ifx active then Colors.CURSOR else Colors.CURSOR_INACTIVE);
    Simp.draw_text(font, xx x, xx y, input_text, color = color);
}

Corner_Rounding :: enum { none; in; out; }

draw_rounded_rect :: (rect: Rect, color: Color, radius := 0.0, softness := 1.0, $set_shader := true) {
    if !is_valid(rect) return;
    #if set_shader then Simp.set_shader_for_rects();
    if radius <= 0 then radius = rounding_radius;
    
    center := Vector2.{ x = rect.x + rect.w / 2, y = rect.y + rect.h / 2 };
    size   := Vector2.{ x = rect.w / 2, y = rect.h / 2 };    
    p0 := bottom_left(rect);
    p2 := top_right(rect);
    
    Simp.immediate_rounded_rect(p0, p2, color, center, size, radius, softness);
}


draw_rounded_rect_with_corners :: (rect: Rect, color: Color,
                                   tl: Corner_Rounding = .in, tr: Corner_Rounding = .in,
                                   br: Corner_Rounding = .in, bl: Corner_Rounding = .in, 
                                   radius := 0.0, softness := 1.0) {
    if radius <= 0 then radius = rounding_radius;
    
    center := Vector2.{ x = rect.x + rect.w / 2, y = rect.y + rect.h / 2 };
    size   := Vector2.{ x = rect.w / 2, y = rect.h / 2 };    
    
    top, bottom, base, corner: Rect = ---;
    top,    base = cut_top(rect, radius);
    bottom, base = cut_bottom(base, radius);
    
    Simp.set_shader_for_rects();
    
    // Draw top corners
    if tl == {
        case .in;
            corner, top = cut_left(top, radius);
            if is_valid(corner) Simp.immediate_rounded_rect(bottom_left(corner), top_right(corner), color, center, size, radius, softness);
        case .out;
            corner = top; corner.w = radius; corner.x -= radius;
            fake_center := center - Vector2.{ x = rect.w - 1, y = -1 };
            if is_valid(corner) Simp.immediate_rounded_rect(bottom_left(corner), top_right(corner), color, fake_center, size, radius, -softness);
    }
    if tr == {
        case .in;
            corner, top = cut_right(top, radius);
            if is_valid(corner) Simp.immediate_rounded_rect(bottom_left(corner), top_right(corner), color, center, size, radius, softness);
        case .out;
            corner = top; corner.w = radius; corner.x += top.w;
            fake_center := center + Vector2.{ x = rect.w - 1, y = 1 };
            if is_valid(corner) Simp.immediate_rounded_rect(bottom_left(corner), top_right(corner), color, fake_center, size, radius, -softness);
    }

    // Draw bottom corners
    if bl == {
        case .in;
            corner, bottom = cut_left(bottom, radius);
            if is_valid(corner) Simp.immediate_rounded_rect(bottom_left(corner), top_right(corner), color, center, size, radius, softness);
        case .out;
            corner = bottom; corner.w = radius; corner.x -= radius;
            fake_center := center - Vector2.{ x = rect.w - 1, y = 1 };
            if is_valid(corner) Simp.immediate_rounded_rect(bottom_left(corner), top_right(corner), color, fake_center, size, radius, -softness);
    }
    if br == {
        case .in;
            corner, bottom = cut_right(bottom, radius);
            if is_valid(corner) Simp.immediate_rounded_rect(bottom_left(corner), top_right(corner), color, center, size, radius, softness);
        case .out;
            corner = bottom; corner.w = radius; corner.x += bottom.w;
            fake_center := center + Vector2.{ x = rect.w - 1, y = -1 };
            if is_valid(corner) Simp.immediate_rounded_rect(bottom_left(corner), top_right(corner), color, fake_center, size, radius, -softness);
    }
    
    // Draw base rects
    Simp.set_shader_for_color(enable_blend = true);
    draw_rect_raw(base, color);
    draw_rect_raw(top, color);
    draw_rect_raw(bottom, color);
}

draw_rounded_rect_with_shadow :: (rect: Rect, color: Color, radius := 0.0, shadow_size := 0.0) {
    if radius <= 0 then radius = rounding_radius;
    if shadow_size <= 0 then shadow_size = char_size * 2;
    shadow_rect := expand(rect, shadow_size);
    shadow_radius := radius + shadow_size;

    top, bottom, left, right, base: Rect = ---;
    top,    base = cut_top(shadow_rect, shadow_radius);
    bottom, base = cut_bottom(base, shadow_radius);
    left,   base = cut_left(base, shadow_radius);
    right,  base = cut_right(base, shadow_radius);
    
    shadow_color  := Colors.SHADOW_DARK;
    center := Vector2.{ x = rect.x + rect.w / 2, y = rect.y + rect.h / 2 };
    size   := Vector2.{ x = rect.w / 2, y = rect.h / 2 };
    
    Simp.set_shader_for_rects();
    
    Simp.immediate_rounded_rect(bottom_left(top),    top_right(top),    shadow_color, center, size, radius, softness = shadow_size);
    Simp.immediate_rounded_rect(bottom_left(bottom), top_right(bottom), shadow_color, center, size, radius, softness = shadow_size);
    Simp.immediate_rounded_rect(bottom_left(left),   top_right(left),   shadow_color, center, size, radius, softness = shadow_size);
    Simp.immediate_rounded_rect(bottom_left(right),  top_right(right),  shadow_color, center, size, radius, softness = shadow_size);

    draw_rounded_rect(rect, color, radius = radius, set_shader = false);
}

draw_top_down_shadow :: (rect: Rect) {
    t := Colors.SHADOW_TRANSPARENT;
    s := Colors.SHADOW_DARK;
    Simp.set_shader_for_color(enable_blend = true);
    draw_rect_raw(rect, c00 = t, c10 = t, c01 = s, c11 = s);
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

draw_scrollbar :: (main_rect: Rect, width: float, content_height: float, scroll: s32, scroll_target: s32, max_scroll: s32, ui_id: Ui_Id) -> new_scroll_target: s32 {
    if max_scroll <= 0 return scroll_target;

    area := cut_right(main_rect, width);  // the scrollbar area of the main rect
    scrollbar := area;  // handle
    scrollbar.h = floor(area.h * (area.h / content_height));
    scroll_zone_size := area.h - scrollbar.h;  // the room for y to move

    if scroll_zone_size <= 0 return scroll_target;  // don't draw

    maybe_set_hot_or_active(ui_id, area, .NORMAL);

    // Draw
    color := Colors.SCROLLBAR;

    if ui.active == ui_id || (ui.hot_last_frame == ui_id && ui.active == .none) {
        draw_rounded_rect(area, Colors.SCROLLBAR_BACKGROUND, radius = rounding_radius_small);
        color = Colors.SCROLLBAR_HOVER;
    }
    separator_rect := shrink_y(cut_left(area, 1), rounding_radius_small);
    draw_rect(separator_rect, Colors.SCROLLBAR_BACKGROUND);
    scrollbar.y += (cast(float) (max_scroll - scroll) / max_scroll) * scroll_zone_size;
    scrollbar.y = floor(scrollbar.y);
    scrollbar = shrink(scrollbar, 1);
    if scrollbar.h < 5 then scrollbar.h = 5;  // don't make it too tiny
    draw_rounded_rect(scrollbar, color, radius = rounding_radius_small);

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
    Simp.set_scissor(x0, y0, max(x0, x1), max(y0, y1));
}

get_ui_id_from_loc :: inline (loc := #caller_location, parent_id: Ui_Id = .none) -> Ui_Id {
    if parent_id != .none {
        return cast(Ui_Id) (loc.line_number + NUM_LINES_OF_CODE * cast(s64) parent_id);
    }
    return cast(Ui_Id) loc.line_number;
}

is_child :: (ui_id: Ui_Id, parent_id: Ui_Id) -> bool {
    // A ui id is considered a child if it was obtained by the get_ui_id_from_loc function above
    num := cast(s64) ui_id;
    parent_min := cast(s64) parent_id * NUM_LINES_OF_CODE;
    parent_max := parent_min + NUM_LINES_OF_CODE - 1;
    return parent_min <= num && num <= parent_max;
}

maybe_set_hot_or_active :: (ui_id: Ui_Id, rect: Rect, pointer_image: Pointer_Image) -> became_active: bool {
    if !is_valid(rect) || !mouse_pointer_is_within(rect) return false;

    ui.hot = ui_id;
    if ui.hot_last_frame == ui_id && ui.active == .none || ui.active == ui_id then set_pointer_image(pointer_image);
    if ui.hot_last_frame == ui_id && ui.active == .none && mouse.left.just_pressed {
        ui.active = ui_id;
        return true;
    }

    return false;
}

is_hovering_over :: (ui_id: Ui_Id) -> bool {
    return ui.hot_last_frame == ui_id && ui.active == .none || ui.active == ui_id;
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
    finder            :: -8;

    // The rest will be derived from loc
}

// NOTE: this is a silly global variable which represents the distance between
// the center of slider and the point where we grabbed it.
// Since we can only drag one slider at a time, this will work, but in a more
// clean way this should probably be stored in widget storage?
// Problem is, we don't have much else to store for scrollbars...
scrollbar_grab_point: float;

scissor_stack: [..] Rect;

// Please keep at the bottom - needed for ui elements parent-child relationships
NUM_LINES_OF_CODE :: #run #location().line_number;
