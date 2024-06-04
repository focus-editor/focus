draw_frame :: () {
    {
        using Colors.BACKGROUND_DARK;
        Simp.clear_render_target(r, g, b, a);
    }

    maybe_set_hot_or_active(.none, screen, .NORMAL);

    // Check whether we need to deactivate elements before drawing
    if !mouse.left.is_down || mouse.left.just_released then ui.active = .none;

    footer_height := font_ui_line_height * 1.6;

    active_pane_rect: Rect = ---;

    // Draw editors
    if #complete editors.layout == {
        case .None;
            editors_snap_splitter(0.5);
            draw_welcome_screen(screen);
        case .Single;
            editors_snap_splitter(0.5);
            draw_editor(editors.active, screen, footer_height, .editor_single);
            active_pane_rect = screen;
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

            if just_dropped_file {
                if mouse_pointer_is_within(left_rect)  then editors_open_file(just_dropped_file, .left);
                if mouse_pointer_is_within(right_rect) then editors_open_file(just_dropped_file, .right);
                just_dropped_file = "";
            }

            draw_editor(editors.left,  left_rect,  footer_height, .editor_left,  screen);
            draw_editor(editors.right, right_rect, footer_height, .editor_right, screen);

            active_pane_rect = ifx editors.active == editors.left then left_rect else right_rect;

            splitter_rect := make_rect(left_rect.x + left_rect.w, left_rect.y + footer_height, 2, left_rect.h - footer_height);
            draw_splitter(splitter_rect, split_x, .editor_splitter);
    }

    if active_global_widget == {
        case .open_file_dialog;         draw_open_file_dialog();
        case .finder;                   draw_finder();
        case .go_to_line_dialog;        draw_go_to_line_dialog(active_pane_rect);
        case .unsaved_buffers_dialog;   draw_unsaved_buffers_dialog();
        case .commands_dialog;          draw_commands_dialog();
        case .open_project_dialog;      draw_open_project_dialog();
    }

    draw_user_messages(screen, footer_height);

    // Reset UI state after drawing
    if !mouse.left.is_down || mouse.left.just_released {
        ui.active = .none;
    } else if ui.active == .none {
        ui.active = .unavailable;  // so that we don't activate anything by dragging on it
    }
    ui.hot_last_frame    = ui.hot;
    ui.active_last_frame = ui.active;

    Simp.swap_buffers(window);
}

draw_welcome_screen :: (main_area: Rect) {
    ui_id := get_ui_id_from_loc();

    right_area, left_area := cut_right(main_area, main_area.w / GOLDEN_RATIO);
    logo_area, info_area  := cut_top(left_area, left_area.h / GOLDEN_RATIO);

    logo_rect := logo_area;
    logo_rect.w = min(logo_area.w, logo_area.h) / GOLDEN_RATIO;
    logo_rect.h = logo_rect.w;
    logo_rect.x = (logo_area.w - logo_rect.w) / 2;

    margin      := logo_rect.x;
    shrink_step := logo_rect.w / 6.5;

    // Draw the left part
    {
        draw_rect(left_area, Colors.BACKGROUND_LIGHT);

        // TODO: fix the circle shader
        // center := center_of(logo_rect);
        // draw_circle(center, Colors.BACKGROUND_DARK, radius = logo_rect.w / 2);
        // shrink_step := logo_rect.w / 6.5;
        // logo_rect = shrink(logo_rect, shrink_step);
        // draw_circle(center, Colors.BACKGROUND, radius = logo_rect.w / 2);
        // logo_rect = shrink(logo_rect, shrink_step);
        // draw_circle(center, Colors.BACKGROUND_LIGHT, radius = logo_rect.w / 2);

        Simp.set_shader_for_rects();

        circle := logo_rect;
        draw_rounded_rect(circle, Colors.BACKGROUND_DARK, radius = circle.w / 2, set_shader = false);
        circle = shrink(circle, shrink_step);
        draw_rounded_rect(circle, Colors.BACKGROUND, radius = circle.w / 2, set_shader = false);
        circle = shrink(circle, shrink_step);
        draw_rounded_rect(circle, Colors.BACKGROUND_LIGHT, radius = circle.w / 2, set_shader = false);

        font := font_ui_big;
        version_text := tprint("Version %", VERSION);
        version_width := cast(float) Simp.prepare_text(font, version_text);
        if version_width / info_area.w > 0.4 {
            font = font_ui;
            version_width = cast(float) Simp.prepare_text(font, version_text);
        }
        if version_width < info_area.w {
            x := (info_area.w - version_width) / 2;
            y := info_area.y + info_area.h - shrink_step - font_ui_line_height;
            Simp.draw_prepared_text(font, xx x, xx y, color = Colors.UI_DIM);

            date_width := Simp.prepare_text(font_ui_medium, RELEASE_DATE);
            x = (info_area.w - date_width) / 2;
            y -= 1.5 * font_ui_big_line_height;
            Simp.draw_prepared_text(font_ui_medium, xx x, xx y, color = Colors.UI_DIM);
        }
    }

    // Draw the right part
    {
        draw_rect(right_area, Colors.BACKGROUND);

        Shortcut :: struct { action: Action_Common; description: string; }

        SHORTCUTS_TO_DISPLAY :: Shortcut.[
            .{ .show_commands,                                      "Show All Commands" },
            .{ .show_open_file_dialog_in_search_mode,               "Open File By Name" },
            .{ .show_open_file_dialog_in_navigate_mode,             "Navigate To File" },
            .{ .show_open_file_dialog_in_navigate_mode_from_root,   "Navigate To File From Root" },
            .{ .search_in_buffer,                                   "Search In Open File" },
            .{ .search_in_buffer_dropdown_mode,                     "Search In Open File (Dropdown Mode)" },
            .{ .search_in_project,                                  "Search In Workspace" },
        ];

        right_area = shrink(right_area, margin);

        padding_v := floor(4 * dpi_scale);
        padding_h := floor(6 * dpi_scale);
        align_x := right_area.w - (right_area.w / GOLDEN_RATIO);

        key_height  := cast(float) font_ui.character_height + 2 * padding_v;
        line_height := max(key_height * 2, (logo_rect.h - key_height * SHORTCUTS_TO_DISPLAY.count) / (SHORTCUTS_TO_DISPLAY.count - 1) + key_height);
        line_height = min(line_height, key_height * 3);

        total_height := line_height * SHORTCUTS_TO_DISPLAY.count - key_height;

        x := right_area.x;
        y := logo_rect.y + logo_rect.h - key_height - (logo_rect.h - total_height) / 2;

        for shortcut : SHORTCUTS_TO_DISPLAY {
            key_sequence_strings := get_first_matching_key_sequence_from_action(shortcut.action);

            // Figure out key sequence width for aligning right
            key_sequence_width := 0.0;
            plus_width  := cast(float) Simp.get_text_width(font_ui, "+");
            padding_between_parts := plus_width + 2 * padding_h;

            for combo_strings: key_sequence_strings {
                for combo_strings {
                    key_sequence_width += xx Simp.get_text_width(font_ui, it) + 2 * padding_h;
                    if it_index < combo_strings.count - 1 {
                        key_sequence_width += plus_width + 2 * padding_h;
                    }
                }

                if it_index < key_sequence_strings.count - 1 {
                    key_sequence_width += padding_between_parts;
                }
            }

            x = right_area.x + align_x - key_sequence_width;
            text_y := y + padding_v * 1.5;

            for combo_strings: key_sequence_strings {
                key_rect := Rect.{ x = x, y = y, w = 0, h = key_height };
                for combo_strings {
                    key_rect.x = x;
                    key_rect.w = xx Simp.prepare_text(font_ui, it) + 2 * padding_h;
                    key_rect = align_to_grid(key_rect);
                    shadow_rect := expand(key_rect, 1);
                    shadow_rect.y -= 2;
                    draw_rounded_rect(shadow_rect, Colors.BACKGROUND_DARK);
                    draw_rounded_rect(key_rect, Colors.SELECTION_ACTIVE);
                    Simp.draw_prepared_text(font_ui, xx (x + padding_h), xx text_y, Colors.UI_DEFAULT);
                    x += key_rect.w;
                    if it_index < combo_strings.count - 1 {
                        Simp.draw_text(font_ui, xx (x + padding_h), xx text_y, "+", Colors.UI_DEFAULT);
                        x += plus_width + 2 * padding_h;
                    }
                }

                x += padding_between_parts;
            }

            Simp.draw_text(font_ui, xx (x + padding_h * 10), xx text_y, shortcut.description, Colors.UI_DEFAULT);

            y -= line_height;
        }
    }

}

draw_user_messages :: (main_area: Rect, footer_height: float) {
    user_messages := get_user_messages(frame_time);
    if !user_messages return;

    ui_id := get_ui_id_from_loc();

    margin  := floor(12 * dpi_scale);
    padding := floor( 8 * dpi_scale);

    message_rect_src := shrink(main_area, margin);
    if !is_valid(message_rect_src) return;

    message_rect_src.y += footer_height;

    for * user_messages {
        if it.dismissed continue;
        if !it.message  continue;

        // Figure out message height
        lines := split(it.message, cast(u8) #char "\n");

        max_seen_width := 0;
        for line : lines {
            line_width := Simp.get_text_width(font_ui, line);
            max_seen_width = max(line_width, max_seen_width);
        }
        message_height := lines.count * font_ui_line_height + 2 * padding;

        message_rect := message_rect_src;
        message_rect.h = message_height;
        message_rect.w = max_seen_width + 2 * padding;
        message_rect.x += message_rect_src.w - message_rect.w;

        maybe_set_hot_or_active(ui_id, message_rect, .PRESSABLE);

        is_hovering := mouse_pointer_is_within(message_rect) && is_hovering_over(ui_id);
        if is_hovering && mouse.left.just_pressed {
            it.dismissed = true;
            redraw_requested = true;
        }

        color: Color = ---;
        if #complete it.level == {
            case .error;    color = Colors.UI_ERROR;
            case .warning;  color = Colors.UI_WARNING_DIM;
            case .success;  color = Colors.UI_SUCCESS;
        }
        draw_rounded_rect_with_shadow(message_rect, color);

        text_color := Colors.UI_DEFAULT;
        pen_x := cast(s64) (message_rect.x + padding);
        pen_y := cast(s64) (message_rect.y + message_rect.h - padding) - font_ui.character_height;

        y := pen_y;
        for line : lines {
            x := pen_x;
            Simp.draw_text(font_ui, x, y, line, text_color);
            y -= xx font_ui_line_height;
        }

        message_rect_src.y += message_height + margin;
    }
}

draw_editor :: (editor_id: s64, main_area: Rect, footer_height: float, ui_id: Ui_Id, total_editor_area := Rect.{}) {
    scrollbar_id := get_ui_id_from_loc(parent_id = ui_id);

    footer_rect, rect := cut_bottom(main_area, footer_height);
    max_width := cast(float) config.settings.max_editor_width * dpi_scale;
    if max_width > 0 && rect.w > max_width {
        rect.x += (rect.w - max_width) / 2;
        rect.w = max_width;
    }
    rect = align_to_grid(rect);
    if !is_valid(rect) return;

    draw_rect(rect, Colors.BACKGROUND);

    became_active := maybe_set_hot_or_active(ui_id, rect, .TEXT_SELECT);
    if became_active then activate_editors();

    using editor := *open_editors[editor_id];
    buffer := *open_buffers[buffer_id];

    editor_is_active := editor_id == editors.active && Input.input_application_has_focus;

    // Calculate text origin in screen coordinates
    text_offset := make_vector2(char_x_advance, -char_x_advance);
    text_origin := top_left(rect) + text_offset - make_vector2(xx viewport.left, line_height - viewport.top);

    if ui.active == ui_id && (mouse.left.just_pressed || mouse.left.is_dragging) {
        // Calculate the position of the mouse
        pointer := snap_to_rect(mouse.pointer, rect);  // when we drag outside the editor we still want to interact
        mouse_pos := pointer - bottom_left(rect) - text_offset;
        mouse_pos.x += viewport.left;
        mouse_pos.y = rect.h - mouse_pos.y + viewport.top - ifx dpi_scale > 1.0 then 1 else 0;
        coords := Coords.{ line = xx (mouse_pos.y / line_height), col = xx ((mouse_pos.x / char_x_advance) + 0.5) };

        cursors_stop_blinking();

        if ctrl_or_cmd_pressed() && !(mouse.left.is_dragging || mouse.left.just_double_clicked || mouse.left.just_triple_clicked) {
            click_offset := coords_to_offset(buffer, coords);

            // Maybe delete a cursor if we clicked on an existing one
            deleted_cursor := false;
            if cursors.count > 1 {
                for cursor, i : cursors {
                    if cursor.pos == click_offset {
                        array_unordered_remove_by_index(*cursors, i);
                        if main_cursor >= i     then main_cursor -= 1;
                        if original_cursor >= i then original_cursor -= 1;
                        main_cursor     = clamp(main_cursor,     0, cursors.count - 1);
                        original_cursor = clamp(original_cursor, 0, cursors.count - 1);
                        deleted_cursor = true;
                        break;
                    }
                }
            }

            if !deleted_cursor {
                // Create new cursor
                same_clipboard, clipboard := cursors_have_the_same_clipboard(editor);
                new_cursor := array_add(*cursors);
                new_cursor.pos = click_offset;
                new_cursor.sel = new_cursor.pos;
                if same_clipboard then new_cursor.clipboard = clipboard;

                main_cursor = cursors.count - 1;
                new_cursor_just_created_using_mouse = true;
                last_cursor_created_using_mouse_at = frame_time;
            }

            organise_cursors(editor, *selection_mode);
        } else {
            cursor: *Cursor;
            if ctrl_or_cmd_pressed() && new_cursor_just_created_using_mouse {
                // Clicked or is dragging with ctrl pressed - select using the most recently added cursor
                cursor = *cursors[main_cursor];
            } else {
                // Either just clicked or is dragging without ctrl pressed
                cursor = leave_only_original_cursor(editor);
            }

            cursor.pos = coords_to_offset(buffer, coords);
            cursor.col_wanted = -1;

            if selection_mode.type == {
                case .chars;
                    search_whole_words = false;

                case .words;
                    char_type := get_char_type(get_char_at_offset(buffer, cursor.pos));

                    if cursor.pos < selection_mode.range.start {
                        cursor.sel = selection_mode.range.end;
                        cursor.pos = scan_through_similar_chars_on_the_left(buffer, cursor.pos, char_type, skip_one_space = false);
                    } else {
                        cursor.sel = selection_mode.range.start;
                        cursor.pos = scan_through_similar_chars_on_the_right(buffer, cursor.pos, char_type, skip_one_space = false);
                    }

                case .lines;
                    cursor.sel = selection_mode.range.start;
                    select_line(cursor, buffer);
                    if cursor.sel < selection_mode.range.start {
                        pos := cursor.pos - 1;  // don't select the last \n
                        cursor.pos = cursor.sel;
                        cursor.sel = pos;
                    }
            }

            // A special case when merging cursors - we want to preserve the combined selection
            if selection_mode.min_range.start != selection_mode.min_range.end {
                if cursor.pos <= selection_mode.min_range.start    then cursor.sel = selection_mode.min_range.end;
                else if cursor.pos >= selection_mode.min_range.end then cursor.sel = selection_mode.min_range.start;
                else {
                    using selection_mode;
                    mid_point := (min_range.end - min_range.start) / 2;
                    cursor.sel = ifx cursor.pos < mid_point then min_range.end   else min_range.start;
                    cursor.pos = ifx cursor.pos < mid_point then min_range.start else min_range.end;
                }
            }

            // We mark cursor as moved to trigger auto-scroll if we drag outside the editor
            if !mouse_pointer_is_within(rect) then cursor_moved = .refresh_only;

            if !shift_pressed() && mouse.left.just_pressed then cursor.sel = cursor.pos;

            if mouse.left.just_double_clicked {
                select_word(buffer, cursor);
                selection_mode.type  = .words;
                selection_mode.range = get_selection(cursor);
            }
            if mouse.left.just_triple_clicked {
                select_line(cursor, buffer);
                selection_mode.type  = .lines;
                selection_mode.range = get_selection(cursor);
            }

            organise_cursors(editor, *selection_mode);
        }

        editor.refresh_highlights = true;

        // Activate editor
        make_editor_active(editor_id);
        if mouse.left.just_pressed then redraw_requested = true;  // so that we don't draw 2 active editors
    }
    if !mouse.left.is_down || mouse.left.just_released {
        selection_mode.type = .chars;
        selection_mode.min_range.start = 0;
        selection_mode.min_range.end   = 0;
        if editor.new_cursor_just_created_using_mouse && (frame_time - editor.last_cursor_created_using_mouse_at) >= cast(Time) (2 * DOUBLE_CLICK_SPEED) then editor.new_cursor_just_created_using_mouse = false;
    }

    // Get the coordinates of all cursors
    // @Speed: instead of doing it every frame we could do it when cursors change only - but probably it's ok
    cursor_coords := NewArray(cursors.count, Cursor_Coords, initialized = false, allocator = temp);
    for cursors cursor_coords[it_index] = get_cursor_coords(buffer, it);

    // Draw editor
    {
        min_visible_chars :: 5;

        push_scissor(rect);
        defer pop_scissor();

        // Handle editor scrolling here because we only know the layout at this point.
        assert(!buffer.dirty);
        max_y_scroll := max(cast(s32)((buffer.line_starts.count - 2) * line_height), 0);

        if (ui.hot_last_frame == ui_id || ui.hot_last_frame == scrollbar_id) && mouse_pointer_is_within(rect) && mouse.scroll_y_delta != 0 && !dont_scroll_this_frame {
            // Mousewheel scrolling - vertical
            // We only handle vertical scrolling here because horizontal scrolling depends on the
            // length of the longest visible line, which we can only determine once we determine
            // the first visible line. Thus we need to "resolve" vertical scrolling before we can
            // properly handle horizontal scrolling.
            using editor.viewport;
            new_target := clamp(scroll_y.target - mouse.scroll_y_delta, 0, max_y_scroll);
            if mouse.smooth_scroll {
                start_animation(*scroll_y, top, new_target);
            } else {
                scroll_y.target = new_target;
                top = new_target;
                viewport_remember_glue_point(*viewport, buffer);
            }
        } else if cursor_moved {
            // Detect if cursor is off screen and start scrolling to it
            bounds := shrink_x(rect, text_offset.x + char_x_advance * min_visible_chars);
            bounds  = shrink_y(bounds, -text_offset.y + line_height * min_visible_chars);
            bounds.h += 2;
            bounds.y -= line_height + 2;
            if bounds.w < 0 || bounds.h < 0 then bounds = rect;  // fall back
            // draw_rect(bounds, Colors.BACKGROUND_DARK);

            screen_pos := get_cursor_screen_pos(text_origin, cursor_coords[main_cursor].pos);
            if !point_within(screen_pos, bounds) {
                left, top, right, bottom := get_rect_sides(bounds);
                offset: Vector2;
                if screen_pos.x < left   then offset.x = screen_pos.x - left;
                if screen_pos.y < bottom then offset.y = screen_pos.y - bottom;
                if right < screen_pos.x  then offset.x = screen_pos.x - right;
                if top   < screen_pos.y  then offset.y = screen_pos.y - top;

                left_target := max(viewport.left + cast(s32) offset.x, 0);
                top_target  := clamp(viewport.top - cast(s32) offset.y, 0, max_y_scroll);

                if left_target != viewport.scroll_x.target then start_animation(*viewport.scroll_x, viewport.left, left_target);
                if top_target  != viewport.scroll_y.target then start_animation(*viewport.scroll_y, viewport.top,  top_target);
            }
        } else if scroll_to_cursor != .no {
            using editor.viewport;

            // Use the target editor width (not current width) when a new editor is appearing
            editor_width := ifx scroll_to_cursor == .yes_new_editor then total_editor_area.w / 2 else rect.w;

            cursor_pos_from_left := cursor_coords[main_cursor].pos.col * char_x_advance + text_offset.x;
            left_target := cast(s32)(cursor_pos_from_left - editor_width + char_x_advance * 3);
            if left_target < 0 then left_target = 0;
            if left_target != scroll_x.target then start_animation(*viewport.scroll_x, viewport.left, left_target);

            cursor_pos_from_top := cursor_coords[main_cursor].pos.line * line_height;
            top_target := cast(s32)(cursor_pos_from_top - rect.h / 2);
            if top_target < 0 then top_target = 0;
            if top_target != scroll_y.target then start_animation(*viewport.scroll_y, viewport.top, top_target);

            scroll_to_cursor = .no;

            cursors_start_blinking();
        }

        // Maybe update selection highlights
        if editor.refresh_highlights && buffer.bytes.count <= MAX_BUFFER_SIZE_FOR_HIGHLIGHTS && config.settings.highlight_selection_occurrences {
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
                    highlight.line   = offset_to_line(buffer, offset);

                    offset += selected_text.count;
                }
            }
            editor.selected_text_length = selected_text.count;
        }
        if !config.settings.highlight_selection_occurrences {
            editor.refresh_highlights = false;
            array_reset_keeping_memory(*editor.highlights);
        }

        // Scrollbar
        new_scroll_target := draw_scrollbar(rect, scrollbar_size, rect.h + xx max_y_scroll, viewport.top, viewport.scroll_y.target, max_y_scroll, scrollbar_id);
        if new_scroll_target != viewport.scroll_y.target {
            // Jump immediately to the scroll point when dragging or clicking scrollbar
            viewport.top = new_scroll_target;
            viewport.scroll_y.target = new_scroll_target;
            viewport_remember_glue_point(*viewport, buffer);
            redraw_requested = true;
        }

        // Keyboard smooth scrolling - vertical
        // As mentioned above, we can properly perform horizontal scrolling only once vertical
        // scrolling is done, allowing us to determine the longest visible line.
        if (editor_smooth_scroll.direction == .up || editor_smooth_scroll.direction == .down) && editor_id == editors.active {
            speed := 60 * line_height;  // pixels per second
            if editor_smooth_scroll.fast then speed *= 2;
            time_elapsed := cast(float) (frame_time - editor_smooth_scroll.started_at);
            new_scroll_y := cast(float) editor_smooth_scroll.start_y;
            if editor_smooth_scroll.direction == {
                case .up;    new_scroll_y -= time_elapsed * speed;
                case .down;  new_scroll_y += time_elapsed * speed;
            }
            viewport.top = clamp(cast(s32) new_scroll_y, 0, max_y_scroll);
            viewport.scroll_y.target = viewport.top;
            viewport_remember_glue_point(*viewport, buffer);
            redraw_requested = true;
        }

        if viewport.top == viewport.scroll_y.target {
            viewport_glue_to_point(*viewport, buffer);
        } else {
            redraw_requested = true;
            viewport.top = get_animation_value(viewport.scroll_y);
            viewport_remember_glue_point(*viewport, buffer);
        }

        // Horizontal scrolling
        if viewport.left != viewport.scroll_x.target {
            redraw_requested = true;
            viewport.left = get_animation_value(viewport.scroll_x);
        }

        // Need to update after updating scrolling to reduce latency
        text_origin = top_left(rect) + text_offset - make_vector2(xx viewport.left, line_height - viewport.top);

        max_lines := cast(s32) buffer.line_starts.count - 2;
        visible_lines_start := clamp(cast(s32) (viewport.top / line_height) - 1, 0, max_lines);
        visible_lines_end   := clamp(visible_lines_start + cast(s32) (rect.h / line_height) + 1, 0, max_lines);
        num_visible_lines   := visible_lines_end - visible_lines_start + 1;
        visible_offset_range := Offset_Range.{
            start = get_line_start_offset(buffer, visible_lines_start),
            end   = get_line_start_offset(buffer, visible_lines_end + 1),
        };
        viewport.max_line_pixel_width = 0;
        for line_num : visible_lines_start .. visible_lines_end {
            line_start := get_line_start_offset(buffer, line_num);
            length := get_line_start_offset(buffer, line_num+1) - line_start;
            line := array_view(buffer.bytes, line_start, length);
            line_pixel_width := cast(s32) ((get_num_chars(line) + min_visible_chars) * char_x_advance);
            viewport.max_line_pixel_width = max(viewport.max_line_pixel_width, line_pixel_width);
        }
        viewport_width := cast(s32) rect.w;
        max_x_scroll := cast(s32) 0;
        if viewport.max_line_pixel_width > viewport_width then max_x_scroll = viewport.max_line_pixel_width - viewport_width;

        // Now that we can compute max_x_scroll we can handle horizontal scrolling.
        // We handle both scrollwheel and keyboard smooth scrolling below.
        // Mousewheel scrolling - horizontal
        if (ui.hot_last_frame == ui_id || ui.hot_last_frame == scrollbar_id) && mouse_pointer_is_within(rect) && mouse.scroll_x_delta != 0 && !dont_scroll_this_frame {
            using editor.viewport;
            new_target := clamp(scroll_x.target - mouse.scroll_x_delta, 0, max_x_scroll);
            if mouse.smooth_scroll {
                start_animation(*scroll_x, left, new_target);
            } else {
                scroll_x.target = new_target;
                left = new_target;
                viewport_remember_glue_point(*viewport, buffer);
            }
        }
        // Keyboard smooth scrolling - horizontal
        if (editor_smooth_scroll.direction == .left || editor_smooth_scroll.direction == .right) && editor_id == editors.active {
            speed := 60 * char_x_advance;
            if editor_smooth_scroll.fast then speed *= 2;
            time_elapsed := cast(float) (frame_time - editor_smooth_scroll.started_at);
            new_scroll_x := cast(float) editor_smooth_scroll.start_x;
            if editor_smooth_scroll.direction == {
                case .left;  new_scroll_x -= time_elapsed * speed;
                case .right; new_scroll_x += time_elapsed * speed;
            }
            if viewport.left <= max_x_scroll {
                viewport.left = clamp(cast(s32) new_scroll_x, 0, max_x_scroll);
            } else if editor_smooth_scroll.direction == .left {
                viewport.left = cast(s32) new_scroll_x;
                if viewport.left < 0 then viewport.left = 0;
            }
            viewport.scroll_x.target = viewport.left;
            viewport_remember_glue_point(*viewport, buffer);
            redraw_requested = true;
        }

        // Draw scrollbar marks
        {
            Simp.set_shader_for_color(enable_blend = true);

            marks_rect := cut_right(rect, scrollbar_size);
            marks_rect =  cut_top(marks_rect, rect.h * max_y_scroll / (rect.h + xx max_y_scroll));  // account for the non-text area at the bottom
            marks_rect_top := marks_rect.y + marks_rect.h;
            assert(buffer.line_starts.count > 0);
            mark_line_height := marks_rect.h / cast(float) buffer.line_starts.count;  // the height of the rect which corresponds to one line

            highlight_mark_rect := shrink_x(marks_rect, marks_rect.w / 3);
            highlight_mark_rect.h = floor(4 * dpi_scale);

            if search_bar_is_open(editor) && search_bar.results {
                // Search results
                for search_bar.results {
                    highlight_mark_rect.y = marks_rect_top - it.line * mark_line_height - highlight_mark_rect.h;
                    draw_rect_raw(highlight_mark_rect, ifx it_index == search_bar.selected_result then Colors.SEARCH_RESULT_ACTIVE else Colors.SEARCH_RESULT_INACTIVE);
                }
            }

            if !search_bar_is_open(editor) {
                // Selection highlights
                for highlights {
                    highlight_mark_rect.y = marks_rect_top - it.line * mark_line_height - highlight_mark_rect.h;
                    draw_rect_raw(highlight_mark_rect, Colors.SELECTION_HIGHLIGHT);
                }
            }

            // Cursor and selection marks
            cursor_mark_rect := marks_rect;
            cursor_mark_rect.h = 2 * dpi_scale;
            selection_mark_rect := cut_left(marks_rect, marks_rect.w / 3);
            for cursor : cursors {
                coords := cursor_coords[it_index];
                cursor_mark_rect.y = marks_rect_top - coords.pos.line * mark_line_height - cursor_mark_rect.h;
                if has_selection(cursor) {
                    selection_mark_rect.y = marks_rect_top - coords.sel.line * mark_line_height - cursor_mark_rect.h;
                    selection_mark_rect.h = (coords.sel.line - coords.pos.line + 1) * mark_line_height;
                    draw_rect_raw(selection_mark_rect, Colors.SELECTION_INACTIVE);
                }
                draw_rect_raw(cursor_mark_rect, Colors.CURSOR);
            }
        }

        // Draw selection highlights
        if !search_bar_is_open(editor) {
            for highlights {
                if it.line < visible_lines_start continue;
                if it.line > visible_lines_end   break;

                range: Coords_Range = ---;
                range.start = offset_to_coords(buffer, it.offset);
                range.end   = offset_to_coords(buffer, it.offset + selected_text_length);
                draw_range(range, buffer, visible_lines_start, visible_lines_end, text_origin, Colors.SELECTION_HIGHLIGHT);
            }
        }

        cursors_active := editor_is_active && active_global_widget == .editors;

        // Draw selections
        if !search_bar_is_open(editor) {
            Simp.set_shader_for_rects();
            for cursor : cursors {
                if has_selection(cursor) {
                    coords := cursor_coords[it_index];
                    selection := ifx cursor.pos < cursor.sel then Coords_Range.{ start = coords.pos, end = coords.sel } else .{ start = coords.sel, end = coords.pos };
                    if selection.end.line < visible_lines_start || selection.start.line > visible_lines_end continue;
                    color := ifx cursors_active then Colors.SELECTION_ACTIVE else Colors.SELECTION_INACTIVE;
                    draw_range(selection, buffer, visible_lines_start, visible_lines_end, text_origin, color);
                }
            }
        }

        // Draw search results
        if search_bar_is_open(editor) {
            for search_bar.results {
                if it.line < visible_lines_start continue;
                if it.line > visible_lines_end   break;

                range: Coords_Range = ---;
                range.start = offset_to_coords(buffer, it.offset);
                range.end   = offset_to_coords(buffer, it.offset + search_bar.input.text.count);
                color := ifx search_bar.selected_result == it_index then Colors.SEARCH_RESULT_ACTIVE else Colors.SEARCH_RESULT_INACTIVE;
                draw_range(range, buffer, visible_lines_start, visible_lines_end, text_origin, color);
            }
        }

        // Draw paste animations
        for * anim : editor.paste_animations {
            if !anim.initted {
                // We can't calculate coords when we're adding the animation, so have to defer to right before drawing
                anim.initted = true;
                anim.coords_range.start = offset_to_coords(buffer, anim.range.start);
                anim.coords_range.end   = offset_to_coords(buffer, anim.range.end);
            }
            t := (frame_time - anim.started_at) / Paste_Animation.SPEED;
            if t < 1 {
                color := Colors.PASTE_ANIMATION;
                color.a = xx (1 - t);
                draw_range(anim.coords_range, buffer, visible_lines_start, visible_lines_end, text_origin, color);
            } else {
                remove anim;
            }
        }
        if editor.paste_animations.count > 0 then redraw_requested = true;

        // Draw inactive cursors before text
        if !cursors_active && !search_bar_is_open(editor) && config.settings.cursor_as_block {
            Simp.set_shader_for_rects();
            for cursor : cursors {
                if cursor.pos < visible_offset_range.start || cursor.pos > visible_offset_range.end continue;
                screen_pos := get_cursor_screen_pos(text_origin, cursor_coords[it_index].pos);

                rect := make_rect(screen_pos.x, screen_pos.y, char_x_advance, line_height);
                draw_rounded_rect(rect, Colors.CURSOR, radius = rounding_radius_small, set_shader = true);
                draw_rounded_rect(shrink(rect, 1), Colors.BACKGROUND, radius = rounding_radius_small, set_shader = false);
            }
        }

        // Draw text
        if buffer.needs_coloring || buffer.colors.count != buffer.bytes.count then recalculate_colors(buffer);  // right before drawing

        hidden_chars_on_the_left := cast(s32) max((viewport.left / char_x_advance) - 2, 0);
        max_chars_horizontally   := cast(s32) (rect.w / char_x_advance) + 2;

        pen := text_origin;
        pen.y += (line_height - char_x_advance) / 2 - visible_lines_start * line_height;
        pen.x += hidden_chars_on_the_left * char_x_advance;

        code_lines := NewArray(num_visible_lines, Simp.Code_Line, initialized = false, allocator = temp);
        for line_num : visible_lines_start .. visible_lines_end {
            line_start := get_line_start_offset(buffer, line_num);
            length := get_line_start_offset(buffer, line_num+1) - line_start;
            line := to_string(array_view(buffer.bytes, line_start, length));
            tab_spaces := 0;
            line, tab_spaces = advance_by_chars  (line, hidden_chars_on_the_left);
            line = take_first_n_chars(line, max_chars_horizontally);
            line = trim_right(line, " \r\n");
            colors := ifx line then array_view(buffer.colors, line.data - buffer.bytes.data, line.count) else .[];
            code_lines[line_num-visible_lines_start] = .{ line = line, tab_spaces = tab_spaces, colors = colors };
        }
        Simp.draw_code(font, xx pen.x, xx pen.y, char_x_advance, line_height, code_lines, CODE_COLOR_MAP, TAB_SIZE);

        // Draw cursors when they are active
        cursor_width := ifx config.settings.cursor_as_block then char_x_advance else 2 * dpi_scale;

        if cursors_active && should_draw_cursors() && !search_bar_is_open(editor) {
            Simp.set_shader_for_rects();
            for cursor : cursors {
                if cursor.pos < visible_offset_range.start || cursor.pos > visible_offset_range.end continue;
                screen_pos := get_cursor_screen_pos(text_origin, cursor_coords[it_index].pos);

                rect := make_rect(screen_pos.x, screen_pos.y, cursor_width, line_height);
                draw_rounded_rect(rect, Colors.CURSOR, radius = rounding_radius_small, set_shader = true);

                // Draw the letter on top for better visibility
                if config.settings.cursor_as_block {
                    letter := get_char_at_offset_as_string(buffer, cursor.pos);
                    if letter != "\n" {
                        Simp.draw_text(font, xx rect.x, xx (rect.y + (line_height - char_x_advance) / 2), letter);
                    }
                }
            }
        }
    }

    // Draw search bar
    if active_global_widget != .editors then search_bar.active = false;

    if search_bar_is_open(editor) {
        using search_bar;

        input_id            := get_ui_id_from_loc(parent_id = ui_id);
        results_id          := get_ui_id_from_loc(parent_id = ui_id);
        search_scrollbar_id := get_ui_id_from_loc(parent_id = ui_id);

        if width_percentage != width_anim.target {
            width_percentage = get_animation_value(width_anim);
            redraw_requested = true;
        }

        margin  := floor(8 * dpi_scale);
        padding := floor(4 * dpi_scale);

        entry_height := font_ui_line_height + padding * 2;

        max_search_results := cast(s64) (rect.h * 0.3 / entry_height);
        num_search_results := min(results.count, max_search_results);

        if mode == .classic then num_search_results = 0;

        top_rect_height := font_ui_line_height + 2 * padding + 2 * margin + 2;
        bar_rect_height := top_rect_height + entry_height * num_search_results;

        bar_rect := cut_top(main_area, bar_rect_height);
        bar_rect = cut_right(bar_rect, bar_rect.w * width_percentage);
        bar_rect.x -= 2 * char_x_advance;

        top_rect, results_rect := cut_top(bar_rect, top_rect_height);

        draw_rounded_rect_with_shadow(bar_rect, Colors.BACKGROUND_LIGHT);

        maybe_set_hot_or_active(input_id,   bar_rect, .NORMAL);
        maybe_set_hot_or_active(results_id, bar_rect, .NORMAL);

        numbers_width := cast(float) Simp.prepare_text(font_ui_small, " No results ");
        if results {
            width := cast(float) Simp.prepare_text(font_ui_small, tprint(" % of % ", selected_result + 1, results.count));
            if width > numbers_width then numbers_width = width;
        }

        top_rect = shrink(top_rect, margin);
        numbers_rect, input_rect := cut_right(top_rect, numbers_width + padding);

        Simp.draw_prepared_text(font_ui_small, xx (numbers_rect.x + padding), xx (numbers_rect.y + (numbers_rect.h - font_ui_small.character_height) / 2.0), color = Colors.UI_DEFAULT);
        input_active := editor_is_active && search_bar.active && active_global_widget == .editors;
        draw_text_input(*search_bar.input, input_rect, active = input_active, ui_id = input_id, label = " Find in buffer", margin_right = input_rect.h * 2);

        button_width := input_rect.h;
        pressed, hover_match_case, hover_match_word := false, false, false;

        pressed, hover_match_case = draw_text_input_modifier_button(input_id, input_rect, button_width, case_sensitive, CASE_SENSITIVE_ICON);
        if pressed {
            search_bar_toggle_case_sensitive(editor, buffer);
            redraw_requested = true;
        }

        input_rect.w -= button_width - 4 * dpi_scale;

        pressed, hover_match_word = draw_text_input_modifier_button(input_id, input_rect, button_width, whole_word, WHOLE_WORD_ICON);
        if pressed {
            search_bar_toggle_whole_word(editor, buffer);
            redraw_requested = true;
        }

        // Draw tooltips last
        tooltip := "";
        if hover_match_case {
            tooltip = "Match Case";
            combo := key_sequence_for_action_as_string(Action_Search_Dialog.toggle_case_sensitive);
            if combo then tooltip = tprint("% (%)", tooltip, combo);
        } else if hover_match_word {
            tooltip = "Match Whole Word";
            combo := key_sequence_for_action_as_string(Action_Search_Dialog.toggle_whole_word);
            if combo then tooltip = tprint("% (%)", tooltip, combo);
        }
        if tooltip then draw_tooltip_bottom_left(tooltip, Vector2.{ x = mouse.pointer.x - input_rect.h / 2, y = input_rect.y + input_rect.h / 3 });

        // Draw search results
        if results && mode == .dropdown {
            // Remember how many fits per page
            per_page = cast(s64) (results_rect.h / entry_height);
            if per_page <= 0 then per_page = 2;

            push_scissor(results_rect);
            defer pop_scissor();

            {
                // Scrollbar
                content_height := results.count * entry_height;
                max_y_scroll := content_height - results_rect.h;
                new_scroll_target := get_new_scroll_target_from_scrollbar(results_rect, scrollbar_size, content_height, scroll_y, scroll_anim.target, xx max_y_scroll, search_scrollbar_id);
                if new_scroll_target != scroll_anim.target {
                    scroll_y = new_scroll_target;
                    scroll_anim.target = new_scroll_target;
                    redraw_requested = true;
                }

                // Scrolling update
                if scroll_to_selected != .no {
                    // We only want to scroll to cursor when cursor is moved by arrow keys
                    target := scroll_anim.target;
                    selected_top    := selected_result * entry_height - target;
                    selected_bottom := selected_top + entry_height;
                    if selected_top < entry_height then target = cast(s32) (selected_result * entry_height);
                    if selected_bottom > results_rect.h then target = cast(s32) ((selected_result + 1) * entry_height - results_rect.h);
                    if content_height - target < results_rect.h then target = cast(s32) (content_height - results_rect.h);
                    if target != scroll_anim.target {
                        if scroll_to_selected == .yes {
                            start_animation(*scroll_anim, scroll_y, target);
                        } else {
                            scroll_y = target;
                            scroll_anim.target = target;
                        }
                    }
                    scroll_to_selected = .no;
                }

                // Mouse scrolling
                if (ui.hot_last_frame == results_id || ui.hot_last_frame == search_scrollbar_id) && mouse_pointer_is_within(results_rect) {
                    if is_hovering_over(results_id) then set_pointer_image(.PRESSABLE);
                    if mouse.scroll_y_delta != 0 && !dont_scroll_this_frame {
                        target := clamp(scroll_anim.target - mouse.scroll_y_delta, 0, xx max_y_scroll);
                        if mouse.smooth_scroll {
                            start_animation(*scroll_anim, scroll_y, target);
                        } else {
                            scroll_anim.target = target;
                            scroll_y = target;
                        }
                    }
                }

                if scroll_y != scroll_anim.target {
                    redraw_requested = true;
                    scroll_y = get_animation_value(scroll_anim);
                }

                // The above operations could've updated scrollbar position, so drawing it here
                draw_scrollbar(results_rect, scrollbar_size, content_height, scroll_y, scroll_anim.target, xx max_y_scroll, search_scrollbar_id);
            }

            visible_start := clamp(cast(s64) (scroll_y / entry_height), 0, results.count);
            visible_count := cast(s64) (results_rect.h / entry_height) + 2;
            visible_entries := array_view(results, visible_start, visible_count);

            last_line_num := ifx results then results[results.count-1].line + 1 else 1;
            line_num_col_width := char_x_advance * tprint("%", last_line_num).count;
            line_num_x := results_rect.x + margin;
            text_x     := line_num_x + line_num_col_width + margin * 1.5;

            max_code_chars := cast(s32)((results_rect.x + results_rect.w - text_x) / char_x_advance) - 1;  // NOTE: counts tab as one char

            entry_rect := cut_top(results_rect, entry_height);
            filename_scissor := cut_left(results_rect, line_num_x - entry_rect.x - char_x_advance);
            if !is_valid(filename_scissor) then filename_scissor = entry_rect;

            for entry, i : visible_entries {
                entry_index := visible_start + i;
                entry_rect.y = results_rect.y + results_rect.h - (entry_index + 1) * entry_height + scroll_y;

                if mouse_pointer_is_within(entry_rect) && is_hovering_over(results_id) {
                    if mouse.left.just_pressed {
                        selected_result = entry_index;
                        jump_to_search_result(editor, buffer);
                        close_search_bar(editor);
                    }
                    draw_rect(entry_rect, Colors.LIST_CURSOR_LITE);
                }
                if entry_index == selected_result then draw_rect(entry_rect, Colors.LIST_CURSOR);

                pen := make_vector2(
                    entry_rect.x + margin + padding,
                    entry_rect.y + (entry_rect.h - font_ui.character_height) / 2 + 2 * dpi_scale,
                );
                width: float;

                line_range := Offset_Range.{ start = get_line_start_offset(buffer, entry.line), end = get_line_end_offset(buffer, entry.line) };
                text_start := line_range.start + count_whitespace(buffer.bytes, line_range.start, line_range.end);

                // Line number
                width = xx Simp.prepare_text(font_ui_small, tprint("%", entry.line + 1));
                Simp.draw_prepared_text(font_ui_small, xx (line_num_x + line_num_col_width - width), xx pen.y, color = Colors.UI_DIM);

                // Draw code line
                {
                    match_start := entry.offset;
                    match_end   := min(entry.offset + search_bar.input.text.count, line_range.end);  // if we have a multi-line match, we will still show only the first line
                    line_start  := ifx text_start <= match_start then text_start else line_range.start;
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
                        line_str := to_string(array_view(buffer.bytes, line_start, line_range.end));
                        byte_offset = slice_chars(line_str, 0, xx char_offset).count;
                    }

                    pen.x = text_x;
                    if char_offset > 0 {
                        // Line was cut on the left, draw an ellipsis
                        Simp.draw_text(font, xx pen.x, xx pen.y, "…", color = Colors.UI_DIM);
                        pen.x += char_x_advance;
                    }

                    // Draw highlight
                    highlight_rect := entry_rect;
                    highlight_rect.x = pen.x + char_x_advance * (chars_until_match_start - char_offset);
                    highlight_rect.w = char_x_advance * (chars_until_match_end - chars_until_match_start);
                    draw_rect(shrink_y(highlight_rect, padding), Colors.SEARCH_RESULT_INACTIVE);

                    // Draw line
                    visible_range := Offset_Range.{
                        start = line_start + xx byte_offset,
                        end   = min(line_range.end, line_start + xx byte_offset + 4 * max_code_chars),  // max 4 bytes per char
                    };
                    line_str := get_range_as_string(buffer, visible_range);
                    if line_str.count > 0 {
                        colors   := array_view(buffer.colors, visible_range.start, line_str.count);
                        code_lines: [1] Simp.Code_Line;
                        code_lines[0] = .{ line = line_str, tab_spaces = 0, colors = colors };
                        Simp.draw_code(font, xx pen.x, xx pen.y, char_x_advance, line_height, code_lines, CODE_COLOR_MAP, TAB_SIZE);
                    }
                }
            }

            if scroll_y != 0 then draw_top_down_shadow(cut_top(results_rect, char_x_advance));
        }

        if ui.active != .none && ui.active != input_id && ui.active != results_id && !is_child(ui.active, input_id) && ui.active != scrollbar_id && ui.active != search_scrollbar_id {
            active = false;  // deactivate on clicks elsewhere (except scrollbar)
            redraw_requested = true;
        }
        if ui.active == input_id {
            active = true;  // activate on click
            make_editor_active(editor_id);  // make sure the editor is also activated
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
        padding := floor(4 * dpi_scale);

        pen := make_vector2(
            footer_rect.x,
            footer_rect.y + (footer_rect.h - font_ui.character_height) / 2 + 2 * dpi_scale,
        );

        // Draw file name and path
        width, pen = draw_file_info(buffer, width, padding, pen, draw_crlf_warning = true, draw_config_warning = true);

        // Draw line and column numbers
        {
            cut_rect := footer_rect;
            cut_rect.x = pen.x + padding;
            cut_rect.w = footer_rect.x + footer_rect.w - cut_rect.x;
            push_scissor(cut_rect);
            defer pop_scissor();

            coords := cursor_coords[main_cursor].pos;
            width = xx Simp.prepare_text(font_ui_bold, tprint("Line: %  Col: %", coords.line + 1, coords.col + 1));
            line_col_start_x := footer_rect.x + footer_rect.w - width;
            Simp.draw_prepared_text(font_ui_bold, xx line_col_start_x, xx pen.y, color = Colors.UI_DIM);

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

draw_file_info :: (buffer: Buffer, width: float, padding: float, _pen: Vector2, bold := true, draw_crlf_warning := false, draw_config_warning := false) -> new_width: float, new_pen: Vector2 {
    file_name_color := Colors.UI_DEFAULT;
    if buffer.modified then file_name_color = Colors.UI_WARNING;

    pen := _pen;

    // Icon
    icon_char := convert_utf32_to_utf8(xx ifx buffer.has_file then buffer.file.icon else File_Icon.text);
    icon_width := Simp.prepare_text(font_icons, to_string(*icon_char));
    icon_x := pen.x - (icon_width - font_icons.em_width) / 2.0;
    Simp.draw_prepared_text(font_icons, xx icon_x, xx pen.y, color = file_name_color);
    width += font_icons.em_width * 1.2;

    // File name
    pen.x += width + padding;
    file_name_font := ifx bold then font_ui_bold else font_ui;
    width = xx Simp.prepare_text(file_name_font, get_buffer_name(buffer));
    Simp.draw_prepared_text(file_name_font, xx pen.x, xx pen.y, color = file_name_color);

    if buffer.modified {
        pen.x += width + padding;
        width = xx Simp.prepare_text(font_icons_tiny, PEN_ICON);
        y_padding := (font_icons.character_height - font_icons_tiny.character_height) / 4.0;
        Simp.draw_prepared_text(font_icons_tiny, xx pen.x, xx (pen.y + y_padding), color = file_name_color);
    }

    // Maybe warnings
    if buffer.deleted {
        pen.x += width + padding;
        width = xx Simp.prepare_text(font_ui_bold, "[deleted on disk]");
        Simp.draw_prepared_text(font_ui_bold, xx pen.x, xx pen.y, color = Colors.UI_ERROR_BRIGHT);
    } else if buffer.modified_on_disk {
        pen.x += width + padding;
        width = xx Simp.prepare_text(font_ui_bold, "[modified on disk]");
        Simp.draw_prepared_text(font_ui_bold, xx pen.x, xx pen.y, color = Colors.UI_ERROR_BRIGHT);
    }
    if buffer.readonly {
        pen.x += width + padding;
        width = xx Simp.prepare_text(font_ui_bold, "[readonly]");
        Simp.draw_prepared_text(font_ui_bold, xx pen.x, xx pen.y, color = Colors.UI_ERROR_BRIGHT);
    }
    if buffer.error_when_saving {
        pen.x += width + padding;
        width = xx Simp.prepare_text(font_ui_bold, "[couldn't save file]");
        Simp.draw_prepared_text(font_ui_bold, xx pen.x, xx pen.y, color = Colors.UI_ERROR_BRIGHT);
    }

    if buffer.crlf && draw_crlf_warning {
        pen.x += width + padding;
        width = xx Simp.prepare_text(font_ui, "[CRLF will be replaced with LF on save]");
        Simp.draw_prepared_text(font_ui, xx pen.x, xx pen.y, color = Colors.UI_WARNING);
    }

    if draw_config_warning && buffer.has_file {
        label: string;
        if buffer.file.full_path == global_config_path {
            label = "[current global config]";
        } else if buffer.file.full_path == project_config_path {
            label = "[current project config]";
        }
        if label {
            pen.x += width + padding;
            width = xx Simp.prepare_text(font_ui, label);
            Simp.draw_prepared_text(font_ui, xx pen.x, xx pen.y, color = Colors.UI_WARNING);
        }
    }

    if buffer.has_file {
        // Draw separator
        pen.x += width + padding;
        width = xx Simp.prepare_text(font_ui_small, BULLET_ICON);
        Simp.draw_prepared_text(font_ui_small, xx pen.x, xx pen.y, color = Colors.UI_DIM);

        // Draw file path
        pen.x += width + padding;
        width = xx Simp.prepare_text(font_ui_small, buffer.file.path);
        Simp.draw_prepared_text(font_ui_small, xx pen.x, xx pen.y, color = Colors.UI_DIM);
    }

    if key_sequence_input_state.key_sequence_in_progress {
        using key_sequence_input_state;

        // Draw separator
        pen.x += width + padding;
        width = xx Simp.prepare_text(font_ui_small, BULLET_ICON);
        Simp.draw_prepared_text(font_ui_small, xx pen.x, xx pen.y, color = Colors.UI_DIM);

        // Draw key sequence
        builder: String_Builder;
        builder.allocator = temp;

        for combo_index: 0..current_key_sequence_length - 1 {
            combo_strings := key_combo_strings(matches_for_current_key_sequence[0].key_sequence[combo_index]);
            for combo_strings {
                print_to_builder(*builder, "%", it);
                if it_index < combo_strings.count - 1  print_to_builder(*builder, "+");
            }

            print_to_builder(*builder, " ");
        }

        print_to_builder(*builder, "...");

        pen.x += width + padding;
        width = xx Simp.prepare_text(font_ui_small, builder_to_string(*builder));
        Simp.draw_prepared_text(font_ui_small, xx pen.x, xx pen.y, color = Colors.UI_DIM);
    }

    pen.x += width;

    return width, pen;
}

draw_splitter :: (splitter_rect: Rect, split_x: float, ui_id: Ui_Id) {
    color := Colors.SPLITTER;

    rect := splitter_rect;
    rect_fat := expand(splitter_rect, 3 * dpi_scale);

    maybe_set_hot_or_active(ui_id, rect_fat, .DRAGGING_HORIZONTAL);

    if is_hovering_over(ui_id) {
        if ui.active == ui_id then color = Colors.SPLITTER_HOVER;
        rect = expand(rect, 2);
    }

    draw_rect(rect, color);
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
        label := ifx finder.initted then " Search files by name" else " Still scanning the workspace. Please wait...";
        draw_text_input(*open_file_dialog.input, input_rect, ui_id = input_id, active = true, label = label);
        if !finder.initted then redraw_requested = true;  // draw the progress bar and update as soon as we're done

        scan_progress := get_workspace_scan_progress();
        if scan_progress < 1.0 {
            progress_bar_rect := shrink(input_rect, 1);
            progress_bar_rect.w *= scan_progress;
            draw_rect(progress_bar_rect, Colors.LIST_CURSOR_LITE);
        }
    } else {
        label := ifx path_chunks then "" else " Navigate to file";

        half_padding := floor(padding / 2);

        min_cursor_area_width := cast(float)font_ui.em_width * 5;  // leave enough space to type text

        // Figure out how much to pad on the left (if only there were a Javascript library for that…)
        margin_left  := 0.0;
        for path_chunks { margin_left += cast(float) Simp.get_text_width(font_ui, it) + padding * 2 + half_padding * 3; }

        margin_delta := margin_left + min_cursor_area_width - input_rect.w;
        if margin_delta > 0 {
            open_file_dialog_maybe_expand();
            margin_left -= margin_delta;
        }

        draw_text_input(*open_file_dialog.input, input_rect, ui_id = input_id, active = true, label = label, margin_left = margin_left);

        push_scissor(shrink_x(input_rect, padding));
        defer pop_scissor();

        dir_rect := shrink(input_rect, padding);
        if margin_delta > 0 then dir_rect.x -= margin_delta;
        text_y := dir_rect.y + floor((dir_rect.h - cast(float)font_ui.em_width) / 2);
        for path_chunks {
            width := cast(float) Simp.prepare_text(font_ui, it);
            dir_rect.w = width + 2 * padding + 2 * half_padding;
            color := Colors.SELECTION_ACTIVE;
            if ui.hot_last_frame == input_id && mouse_pointer_is_within(dir_rect) {
                color = Colors.LIST_CURSOR;
                set_pointer_image(.PRESSABLE);
                if mouse.left.just_pressed {
                    if shift_pressed() {
                        // Shift + Click = Open dir in explorer
                        path_chunks_trimmed := array_view(path_chunks, 1, it_index);
                        dir_path: string = ---;
                        if path_chunks_trimmed.count == 0 dir_path = root_dir;
                        else dir_path = tprint("%/%", root_dir, join(..path_chunks_trimmed, separator = "/"));
                        platform_open_in_explorer(dir_path);
                    } else {
                        // Regular Click = Trim chunks past this dir
                        open_file_dialog_truncate_path_chunks(it_index);
                        redraw_requested = true;
                    }
                }
            }
            draw_rounded_rect(dir_rect, color);
            Simp.draw_prepared_text(font_ui, xx (dir_rect.x + padding + half_padding), xx text_y, Colors.UI_DEFAULT);
            dir_rect.x += dir_rect.w + half_padding;
        }
    }

    _pad: Rect = ---;  // allow some space at the bottom so that we don't cover up the rounded corners with the cursor
    _pad, files_rect = cut_bottom(files_rect, padding);

    // Draw files
    if initted || mode == .navigate {
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
            new_scroll_target := get_new_scroll_target_from_scrollbar(files_rect, scrollbar_size, content_height, scroll_y, scroll_anim.target, xx max_y_scroll, scrollbar_id);
            if new_scroll_target != scroll_anim.target {
                scroll_y = new_scroll_target;
                scroll_anim.target = new_scroll_target;
                redraw_requested = true;
            }

            // Scrolling update
            if scroll_to_cursor != .no {
                // We only want to scroll to cursor when cursor is moved by arrow keys
                target := scroll_anim.target;
                selected_top    := selected * entry_height - target;
                selected_bottom := selected_top + entry_height;
                if selected_top < 0 then target = cast(s32) (selected * entry_height);
                if selected_bottom > files_rect.h then target = cast(s32) ((selected + 1) * entry_height - files_rect.h);
                if target != scroll_anim.target {
                    if scroll_to_cursor == .yes {
                        start_animation(*scroll_anim, scroll_y, target);
                    } else {
                        scroll_y = target;
                        scroll_anim.target = target;
                    }
                }
                scroll_to_cursor = .no;
            }

            // Mouse scrolling
            if (ui.hot_last_frame == ui_id || ui.hot_last_frame == scrollbar_id) && mouse_pointer_is_within(files_rect) {
                if is_hovering_over(ui_id) then set_pointer_image(.PRESSABLE);
                if mouse.scroll_y_delta != 0 && !dont_scroll_this_frame {
                    target := clamp(scroll_anim.target - mouse.scroll_y_delta, 0, xx max_y_scroll);
                    if mouse.smooth_scroll {
                        start_animation(*scroll_anim, scroll_y, target);
                    } else {
                        scroll_anim.target = target;
                        scroll_y = target;
                    }
                }
            }

            if scroll_y != scroll_anim.target {
                redraw_requested = true;
                scroll_y = get_animation_value(scroll_anim);
            }

            // The above operations could've updated scrollbar position, so drawing it here
            draw_scrollbar(files_rect, scrollbar_size, content_height, scroll_y, scroll_anim.target, xx max_y_scroll, scrollbar_id);
        }

        visible_start := clamp(cast(s64) (scroll_y / entry_height), 0, filtered.count);
        visible_count := cast(s64) (files_rect.h / entry_height) + 2;
        visible_entries := array_view(filtered, visible_start, visible_count);

        entry_rect := cut_top(files_rect, entry_height);

        path_align_x := files_rect.x + files_rect.w / 2.5;

        project_dir_id := -1;  // to draw project boundary

        for entry, i : visible_entries {
            entry_index := visible_start + i;
            entry_rect.y = files_rect.y + files_rect.h - (entry_index + 1) * entry_height + scroll_y;

            if entry.type != .nothing {
                if mouse_pointer_is_within(entry_rect) && is_hovering_over(ui_id) {
                    if mouse.left.just_pressed then entries.selected_by_mouse = entry_index;
                    if entries.selected_by_mouse == -1 then draw_rect(entry_rect, Colors.LIST_CURSOR_LITE);
                    if entries.selected_by_mouse == entry_index && mouse.left.just_released {
                        if shift_pressed() {
                            // Shift + Click = open entry in explorer
                            open_file_dialog_open_entry_in_explorer(entry_index);
                        } else {
                            // Regular click = open entry in editor
                            placement := ifx ctrl_or_cmd_pressed() then Editor_Placement.on_the_side else .in_place;
                            open_file_dialog_open_entry(entry_index, placement);
                            redraw_requested = true;
                            break;  // don't finish drawing entries because the entries will likely change
                        }
                    }
                }
                if entries.selected_by_mouse == entry_index then draw_rect(entry_rect, Colors.LIST_CURSOR);
                if entry_index == selected then draw_rect(entry_rect, Colors.LIST_CURSOR);
            }

            // Maybe draw project boundary
            if mode == .search {
                if project_dir_id < 0 then project_dir_id = entry.project_dir_id;
                if entry.project_dir_id != project_dir_id {
                    project_dir_id = entry.project_dir_id;
                    separator := cut_top(entry_rect, 2 * dpi_scale);
                    separator.y += 1;
                    draw_rect(separator, Colors.LIST_CURSOR_LITE);
                }
            }

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
            width = xx Simp.draw_text_with_highlights(font_ui, xx pen.x, xx pen.y, entry.entry_name, entry.name_highlights, color = name_color, highlight_color = Colors.LETTER_HIGHLIGHT);

            if entry.flags & .MODIFIED_ON_DISK {
                pen.x += width + padding;
                width = xx Simp.draw_text(font_ui_bold, xx pen.x, xx pen.y, "[modified on disk]", color = Colors.UI_ERROR_BRIGHT);
            }

            // // Draw score
            // pen.x += width + padding;
            // width = xx Simp.prepare_text(font_ui_small, tprint("%", formatInt(entry.sort_key, base=16)));
            // Simp.draw_prepared_text(font_ui_small, xx pen.x, xx pen.y, color = Colors.UI_DIM);

            // Draw file path
            pen.x += width + padding;
            if pen.x < path_align_x then pen.x = path_align_x;
            width = xx Simp.draw_text_with_highlights(font_ui, xx pen.x, xx pen.y, entry.path, entry.path_highlights, color = Colors.UI_DIM, highlight_color = Colors.LETTER_HIGHLIGHT);
        }

        // Deselect any previously clicked entry
        if mouse.left.just_released || !mouse.left.is_down then entries.selected_by_mouse = -1;

        if scroll_y != 0 then draw_top_down_shadow(cut_top(files_rect, char_x_advance));
    }
}

draw_commands_dialog :: () {
    using commands_dialog;

    ui_id := Ui_Id.commands_dialog;
    scrollbar_id := get_ui_id_from_loc(parent_id = ui_id);

    if ui.active != .none && ui.active != ui_id && !is_child(ui.active, ui_id) {
        // Close the dialog on clicks elsewhere
        hide_commands_dialog();
        return;
    }

    margin  := floor(12 * dpi_scale);
    padding := floor( 4 * dpi_scale);
    input_rect_height := font_ui_line_height + 2 * padding + 2 * margin + 2;
    entry_height := font_ui_line_height + padding * 2;

    // Figure out the dialog box size
    box_rect: Rect = ---;
    {
        width  := floor(clamp(screen.w * 0.4, 400 * dpi_scale, 1500 * dpi_scale));
        height := floor(clamp(input_rect_height + entry_height * filtered.count + padding, 0, screen.h / 1.5));
        x := floor((screen.w - width) / 2);
        y := floor(clamp(100 * dpi_scale, 0, (screen.h - height) / 2));
        box_rect = make_rect(x, screen.h - height - y, width, height);
        if !is_valid(box_rect) return;
    }
    draw_rounded_rect_with_shadow(box_rect, Colors.BACKGROUND_LIGHT, radius = rounding_radius_large);

    maybe_set_hot_or_active(ui_id, box_rect, .NORMAL);

    // Draw the filter input
    input_rect, entries_rect := cut_top(box_rect, input_rect_height);
    input_rect = shrink(input_rect, margin);
    input_id := get_ui_id_from_loc(parent_id = ui_id);

    draw_text_input(*commands_dialog.input, input_rect, ui_id = input_id, active = true, label = " Execute command");

    _pad: Rect = ---;  // allow some space at the bottom so that we don't cover up the rounded corners with the cursor
    _pad, entries_rect = cut_bottom(entries_rect, padding);

    // Draw commands
    {
        // Remember how many fits per page
        per_page = cast(s64) (entries_rect.h / entry_height);
        if per_page <= 0 then per_page = 2;

        push_scissor(entries_rect);
        defer pop_scissor();

        {
            // Scrollbar
            content_height := filtered.count * entry_height;
            max_y_scroll := content_height - entries_rect.h;
            new_scroll_target := get_new_scroll_target_from_scrollbar(entries_rect, scrollbar_size, content_height, scroll_y, scroll_anim.target, xx max_y_scroll, scrollbar_id);
            if new_scroll_target != scroll_anim.target {
                scroll_y = new_scroll_target;
                scroll_anim.target = new_scroll_target;
                redraw_requested = true;
            }

            // Scrolling update
            if scroll_to_cursor != .no {
                // We only want to scroll to cursor when cursor is moved by arrow keys
                target := scroll_anim.target;
                selected_top    := selected * entry_height - target;
                selected_bottom := selected_top + entry_height;
                if selected_top < 0 then target = cast(s32) (selected * entry_height);
                if selected_bottom > entries_rect.h then target = cast(s32) ((selected + 1) * entry_height - entries_rect.h);
                if target != scroll_anim.target {
                    if scroll_to_cursor == .yes {
                        start_animation(*scroll_anim, scroll_y, target);
                    } else {
                        scroll_y = target;
                        scroll_anim.target = target;
                    }
                }
                scroll_to_cursor = .no;
            }

            // Mouse scrolling
            if (ui.hot_last_frame == ui_id || ui.hot_last_frame == scrollbar_id) && mouse_pointer_is_within(entries_rect) {
                if is_hovering_over(ui_id) then set_pointer_image(.PRESSABLE);
                if mouse.scroll_y_delta != 0 && !dont_scroll_this_frame {
                    target := clamp(scroll_anim.target - mouse.scroll_y_delta, 0, xx max_y_scroll);
                    if mouse.smooth_scroll {
                        start_animation(*scroll_anim, scroll_y, target);
                    } else {
                        scroll_anim.target = target;
                        scroll_y = target;
                    }
                }
            }

            if scroll_y != scroll_anim.target {
                redraw_requested = true;
                scroll_y = get_animation_value(scroll_anim);
            }

            // The above operations could've updated scrollbar position, so drawing it here
            draw_scrollbar(entries_rect, scrollbar_size, content_height, scroll_y, scroll_anim.target, xx max_y_scroll, scrollbar_id);
        }

        visible_start := clamp(cast(s64) (scroll_y / entry_height), 0, filtered.count);
        visible_count := cast(s64) (entries_rect.h / entry_height) + 2;
        visible_entries := array_view(filtered, visible_start, visible_count);

        entry_rect := cut_top(entries_rect, entry_height);

        path_align_x := entries_rect.x + entries_rect.w / 2.5;

        project_dir_id := -1;  // to draw project boundary

        for entry, i : visible_entries {
            entry_index := visible_start + i;
            entry_rect.y = entries_rect.y + entries_rect.h - (entry_index + 1) * entry_height + scroll_y;


            if mouse_pointer_is_within(entry_rect) && is_hovering_over(ui_id) {
                if mouse.left.just_pressed then selected_by_mouse = entry_index;
                if selected_by_mouse == -1 then draw_rect(entry_rect, Colors.LIST_CURSOR_LITE);
                draw_rect(entry_rect, Colors.LIST_CURSOR_LITE);

                if selected_by_mouse == entry_index && mouse.left.just_released {
                    selected = entry_index;
                    commands_execute_selected();
                    redraw_requested = true;
                    break;
                }
            }
            if selected_by_mouse == entry_index then draw_rect(entry_rect, Colors.LIST_CURSOR);
            if entry_index == selected then draw_rect(entry_rect, Colors.LIST_CURSOR);

            pen := make_vector2(
                entry_rect.x + margin + padding,
                entry_rect.y + (entry_rect.h - font_ui.character_height) / 2 + 2 * dpi_scale,
            );
            width: float;

            // Draw name
            width = xx Simp.draw_text_with_highlights(font_ui, xx pen.x, xx pen.y, entry.name, entry.highlights, color = Colors.UI_DEFAULT, highlight_color = Colors.LETTER_HIGHLIGHT);

            // // Draw score
            // pen.x += width + padding;
            // width = xx Simp.prepare_text(font_ui_small, tprint("%", formatInt(entry.sort_key, base=16)));
            // Simp.draw_prepared_text(font_ui_small, xx pen.x, xx pen.y, color = Colors.UI_DIM);

            key_sequence := key_sequence_for_action_as_string(entry.action);
            if key_sequence {
                key_sequence_rect := shrink_x(entry_rect, margin);
                key_sequence_rect.x += width;
                key_sequence_rect.w -= width + padding;

                key_sequence_width := cast(float) Simp.prepare_text(font_ui_small, key_sequence);

                if is_valid(key_sequence_rect) && key_sequence_width < key_sequence_rect.w {
                    pen.x = key_sequence_rect.x + key_sequence_rect.w - key_sequence_width;
                    Simp.draw_prepared_text(font_ui_small, xx pen.x, xx pen.y, Colors.UI_DIM);
                }
            }
        }

        if mouse.left.just_released || !mouse.left.is_down then selected_by_mouse = -1;

        if scroll_y != 0 then draw_top_down_shadow(cut_top(entries_rect, char_x_advance));
    }
}

draw_open_project_dialog :: () {
    using open_project_dialog;

    ui_id := Ui_Id.open_project_dialog;
    scrollbar_id := get_ui_id_from_loc(parent_id = ui_id);

    if ui.active != .none && ui.active != ui_id && !is_child(ui.active, ui_id) {
        // Close the dialog on clicks elsewhere
        hide_open_project_dialog();
        return;
    }

    margin  := floor(12 * dpi_scale);
    padding := floor( 4 * dpi_scale);
    input_rect_height := font_ui_line_height + 2 * padding + 2 * margin + 2;
    entry_height := font_ui_line_height + padding * 2;

    // Figure out the dialog box size
    box_rect: Rect = ---;
    {
        width  := floor(clamp(screen.w * 0.4, 400 * dpi_scale, 1500 * dpi_scale));
        height := floor(clamp(input_rect_height + entry_height * filtered.count + padding, 0, screen.h / 1.5));
        x := floor((screen.w - width) / 2);
        y := floor(clamp(100 * dpi_scale, 0, (screen.h - height) / 2));
        box_rect = make_rect(x, screen.h - height - y, width, height);
        if !is_valid(box_rect) return;
    }
    draw_rounded_rect_with_shadow(box_rect, Colors.BACKGROUND_LIGHT, radius = rounding_radius_large);

    maybe_set_hot_or_active(ui_id, box_rect, .NORMAL);

    // Draw the filter input
    input_rect, entries_rect := cut_top(box_rect, input_rect_height);
    input_rect = shrink(input_rect, margin);
    input_id := get_ui_id_from_loc(parent_id = ui_id);

    label := ifx filtered then " Select project to switch to" else tprint(" No projects found in %", projects_dir);
    draw_text_input(*open_project_dialog.input, input_rect, ui_id = input_id, active = true, label = label);

    _pad: Rect = ---;  // allow some space at the bottom so that we don't cover up the rounded corners with the cursor
    _pad, entries_rect = cut_bottom(entries_rect, padding);

    // Draw project
    {
        // Remember how many fits per page
        per_page = cast(s64) (entries_rect.h / entry_height);
        if per_page <= 0 then per_page = 2;

        push_scissor(entries_rect);
        defer pop_scissor();

        {
            // Scrollbar
            content_height := filtered.count * entry_height;
            max_y_scroll := content_height - entries_rect.h;
            new_scroll_target := get_new_scroll_target_from_scrollbar(entries_rect, scrollbar_size, content_height, scroll_y, scroll_anim.target, xx max_y_scroll, scrollbar_id);
            if new_scroll_target != scroll_anim.target {
                scroll_y = new_scroll_target;
                scroll_anim.target = new_scroll_target;
                redraw_requested = true;
            }

            // Scrolling update
            if scroll_to_cursor != .no {
                // We only want to scroll to cursor when cursor is moved by arrow keys
                target := scroll_anim.target;
                selected_top    := selected * entry_height - target;
                selected_bottom := selected_top + entry_height;
                if selected_top < 0 then target = cast(s32) (selected * entry_height);
                if selected_bottom > entries_rect.h then target = cast(s32) ((selected + 1) * entry_height - entries_rect.h);
                if target != scroll_anim.target {
                    if scroll_to_cursor == .yes {
                        start_animation(*scroll_anim, scroll_y, target);
                    } else {
                        scroll_y = target;
                        scroll_anim.target = target;
                    }
                }
                scroll_to_cursor = .no;
            }

            // Mouse scrolling
            if (ui.hot_last_frame == ui_id || ui.hot_last_frame == scrollbar_id) && mouse_pointer_is_within(entries_rect) {
                if is_hovering_over(ui_id) then set_pointer_image(.PRESSABLE);
                if mouse.scroll_y_delta != 0 && !dont_scroll_this_frame {
                    target := clamp(scroll_anim.target - mouse.scroll_y_delta, 0, xx max_y_scroll);
                    if mouse.smooth_scroll {
                        start_animation(*scroll_anim, scroll_y, target);
                    } else {
                        scroll_anim.target = target;
                        scroll_y = target;
                    }
                }
            }

            if scroll_y != scroll_anim.target {
                redraw_requested = true;
                scroll_y = get_animation_value(scroll_anim);
            }

            // The above operations could've updated scrollbar position, so drawing it here
            draw_scrollbar(entries_rect, scrollbar_size, content_height, scroll_y, scroll_anim.target, xx max_y_scroll, scrollbar_id);
        }

        visible_start := clamp(cast(s64) (scroll_y / entry_height), 0, filtered.count);
        visible_count := cast(s64) (entries_rect.h / entry_height) + 2;
        visible_entries := array_view(filtered, visible_start, visible_count);

        entry_rect := cut_top(entries_rect, entry_height);

        path_align_x := entries_rect.x + entries_rect.w / 2.5;

        project_dir_id := -1;  // to draw project boundary

        for entry, i : visible_entries {
            entry_index := visible_start + i;
            entry_rect.y = entries_rect.y + entries_rect.h - (entry_index + 1) * entry_height + scroll_y;


            if mouse_pointer_is_within(entry_rect) && is_hovering_over(ui_id) {
                if mouse.left.just_pressed then selected_by_mouse = entry_index;
                if selected_by_mouse == -1 then draw_rect(entry_rect, Colors.LIST_CURSOR_LITE);
                draw_rect(entry_rect, Colors.LIST_CURSOR_LITE);

                if selected_by_mouse == entry_index && mouse.left.just_released {
                    selected = entry_index;
                    open_selected_project();
                    redraw_requested = true;
                    break;
                }
            }
            if selected_by_mouse == entry_index then draw_rect(entry_rect, Colors.LIST_CURSOR);
            if entry_index == selected then draw_rect(entry_rect, Colors.LIST_CURSOR);

            pen := make_vector2(
                entry_rect.x + margin + padding,
                entry_rect.y + (entry_rect.h - font_ui.character_height) / 2 + 2 * dpi_scale,
            );

            // Draw name
            Simp.draw_text_with_highlights(font_ui, xx pen.x, xx pen.y, entry.name, entry.highlights, color = Colors.UI_DEFAULT, highlight_color = Colors.LETTER_HIGHLIGHT);

        }

        if mouse.left.just_released || !mouse.left.is_down then selected_by_mouse = -1;

        if scroll_y != 0 then draw_top_down_shadow(cut_top(entries_rect, char_x_advance));
    }
}

draw_unsaved_buffers_dialog :: () {
    ui_id := Ui_Id.unsaved_buffers;

    unsaved_buffers := get_unsaved_buffer_ids();
    if !unsaved_buffers {
        log_error("Unsaved buffers dialog is attempted to be drawn, but no unsaved buffers present. This is a bug. Closing...");
        close_unsaved_buffers_dialog();
        return;
    }

    margin  := floor(12 * dpi_scale);
    padding := floor( 4 * dpi_scale);
    entry_height  := font_ui_line_height + padding * 2;
    button_height := font_ui_medium_line_height + 2 * padding;
    header_height := font_ui_medium_line_height + 2 * margin + 4 * dpi_scale;

    box_rect := Rect.{
        w = floor(clamp(screen.w * 0.3, 600 * dpi_scale, 1500 * dpi_scale)),
        h = header_height + (entry_height + margin / 2) * unsaved_buffers.count + margin + padding + button_height + margin,
    };
    box_rect.x = floor((screen.w - box_rect.w) / 2);
    box_rect.y = screen.h - box_rect.h - floor(clamp(100 * dpi_scale, 0, (screen.h - box_rect.h) / 2));

    maybe_set_hot_or_active(ui_id, box_rect, .NORMAL);

    draw_rounded_rect_with_shadow(box_rect, Colors.BACKGROUND_LIGHT);

    header_rect, buffers_rect := cut_top(box_rect, header_height);
    buffers_rect = shrink(buffers_rect, margin);

    // Header
    {
        push_scissor(header_rect);
        defer pop_scissor();

        draw_rounded_rect_with_corners(header_rect, Colors.BACKGROUND_BRIGHT, tl = .in, tr = .in, br = .none, bl = .none);

        pen_x := cast(s32) (header_rect.x + 2 * margin);
        pen_y := cast(s32) (header_rect.y + (header_rect.h - font_ui_medium.character_height) / 2 + 2);
        header_text := "There are unsaved files. Continue?";
        if unsaved_buffers.count == 1 then header_text = "There is an unsaved file. Continue?";
        Simp.draw_text(font_ui_medium, pen_x, pen_y, header_text, Colors.UI_DEFAULT);

        hr := cut_bottom(header_rect, 1);
        draw_rect(hr, Colors.BACKGROUND_DARK);
    }

    // Unsaved buffers
    {
        push_scissor(buffers_rect);
        defer pop_scissor();

        entry_rect := cut_top(buffers_rect, entry_height);

        for unsaved_buffers {
            buffer := *open_buffers[it];
            {
                push_scissor(entry_rect);
                defer pop_scissor();

                pen := Vector2.{
                    x = entry_rect.x + margin,
                    y = entry_rect.y + (entry_rect.h - font_ui.character_height) / 2 + 2 * dpi_scale,
                };
                width: float;

                width, pen = draw_file_info(buffer, width, padding, pen);
            }

            entry_rect.y -= entry_rect.h + margin / 2;
        }
    }

    // Buttons
    {
        buttons_row_rect := cut_bottom(buffers_rect, button_height);

        cancel_button, dont_save_button, save_all_button: Rect;

        activated, width := draw_button(font_ui, "Cancel", Colors.UI_NEUTRAL, Colors.UI_DEFAULT, ui_id, buttons_row_rect, .right, margin / 2, margin);
        if activated close_unsaved_buffers_dialog();

        buttons_row_rect.w -= width + margin;

        activated, width = draw_button(font_ui, "Don't Save", Colors.UI_WARNING, Colors.UI_DEFAULT, ui_id, buttons_row_rect, .right, margin / 2, margin);
        if activated unsaved_buffers_dialog_proceed();

        buttons_row_rect.w -= width + margin;

        save_label := ifx unsaved_buffers.count == 1 then "    Save    " else "  Save All  ";
        activated, width = draw_button(font_ui, save_label, Colors.UI_WARNING, Colors.UI_DEFAULT, ui_id, buttons_row_rect, .right, margin / 2, margin);
        if activated unsaved_buffers_save_all();
    }

    if ui.active != .none && ui.active != ui_id && !is_child(ui.active, ui_id) {
        // Close the dialog on clicks elsewhere
        close_unsaved_buffers_dialog();
        return;
    }
}

draw_finder :: () {
    using finder;

    ui_id := Ui_Id.finder;
    scrollbar_id := get_ui_id_from_loc(parent_id = ui_id);

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
        width := screen.w * width_percentage;
        if width < 700 * dpi_scale then width = 700 * dpi_scale;

        num_results := max(results.count, 1);
        height := clamp(input_rect_height + entry_height * num_results + padding, 0, screen.h / 1.2);

        x := (screen.w - width) / 2;
        y := 100 * dpi_scale;
        box_rect = make_rect(x, screen.h - height - y, width, height);
        if !is_valid(box_rect) return;
    }
    draw_rounded_rect_with_shadow(box_rect, Colors.BACKGROUND_LIGHT, radius = rounding_radius_large);

    maybe_set_hot_or_active(ui_id, box_rect, .NORMAL);

    // Draw the filter input
    input_rect, files_rect := cut_top(box_rect, input_rect_height);
    input_rect = shrink(input_rect, margin);
    input_id := get_ui_id_from_loc(parent_id = ui_id);
    label := ifx initted then "Type to search in workspace" else "Still scanning the workspace. Please wait...";
    draw_text_input(*finder.input, input_rect, ui_id = input_id, active = true, label = label, margin_right = input_rect.h * 2);

    button_width := input_rect.h;
    pressed, hover_match_case, hover_match_word := false, false, false;

    pressed, hover_match_case = draw_text_input_modifier_button(input_id, input_rect, button_width, case_sensitive, CASE_SENSITIVE_ICON);
    if pressed {
        finder_toggle_case_sensitive();
        redraw_requested = true;
    }

    input_rect.w -= button_width - 4 * dpi_scale;

    pressed, hover_match_word = draw_text_input_modifier_button(input_id, input_rect, button_width, whole_word, WHOLE_WORD_ICON);
    if pressed {
        finder_toggle_whole_word();
        redraw_requested = true;
    }

    // Draw tooltips last
    tooltip := "";
    if hover_match_case {
        tooltip = "Match Case";
        combo := key_sequence_for_action_as_string(Action_Search_Dialog.toggle_case_sensitive);
        if combo then tooltip = tprint("% (%)", tooltip, combo);
    } else if hover_match_word {
        tooltip = "Match Whole Word";
        combo := key_sequence_for_action_as_string(Action_Search_Dialog.toggle_whole_word);
        if combo then tooltip = tprint("% (%)", tooltip, combo);
    }
    if tooltip then draw_tooltip_bottom_left(tooltip, Vector2.{ x = mouse.pointer.x - input_rect.h / 2, y = input_rect.y + input_rect.h / 3 });

    scan_progress := get_workspace_scan_progress();
    if scan_progress < 1.0 {
        progress_bar_rect := shrink(input_rect, 1);
        progress_bar_rect.w *= scan_progress;;
        draw_rect(progress_bar_rect, Colors.LIST_CURSOR_LITE);
    }

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
            new_scroll_target := get_new_scroll_target_from_scrollbar(files_rect, scrollbar_size, content_height, scroll_y, scroll_anim.target, xx max_y_scroll, scrollbar_id);
            if new_scroll_target != scroll_anim.target {
                scroll_y = new_scroll_target;
                scroll_anim.target = new_scroll_target;
                redraw_requested = true;
            }

            // Scrolling update
            if scroll_to_cursor != .no {
                // We only want to scroll to cursor when cursor is moved by arrow keys
                target := scroll_anim.target;
                selected_top    := selected * entry_height - target;
                selected_bottom := selected_top + entry_height;
                if selected_top < 0 then target = cast(s32) (selected * entry_height);
                if selected_bottom > files_rect.h then target = cast(s32) ((selected + 1) * entry_height - files_rect.h);
                if content_height - target < files_rect.h then target = cast(s32) (content_height - files_rect.h);
                if target != scroll_anim.target {
                    if scroll_to_cursor == .yes {
                        start_animation(*scroll_anim, scroll_y, target);
                    } else {
                        scroll_y = target;
                        scroll_anim.target = target;
                    }
                }
                scroll_to_cursor = .no;
            }

            // Mouse scrolling
            if (ui.hot_last_frame == ui_id || ui.hot_last_frame == scrollbar_id) && mouse_pointer_is_within(files_rect) {
                if is_hovering_over(ui_id) then set_pointer_image(.PRESSABLE);
                if mouse.scroll_y_delta != 0 && !dont_scroll_this_frame {
                    target := clamp(scroll_anim.target - mouse.scroll_y_delta, 0, xx max_y_scroll);
                    if mouse.smooth_scroll {
                        start_animation(*scroll_anim, scroll_y, target);
                    } else {
                        scroll_anim.target = target;
                        scroll_y = target;
                    }
                }
            }

            if scroll_y != scroll_anim.target {
                redraw_requested = true;
                scroll_y = get_animation_value(scroll_anim);
            }

            // The above operations could've updated scrollbar position, so drawing it here
            draw_scrollbar(files_rect, scrollbar_size, content_height, scroll_y, scroll_anim.target, xx max_y_scroll, scrollbar_id);
        }

        if !initted {
            redraw_requested = true;
            return;
        }

        visible_start := clamp(cast(s64) (scroll_y / entry_height), 0, results.count);
        visible_count := cast(s64) (files_rect.h / entry_height) + 2;
        visible_entries := array_view(results, visible_start, visible_count);

        line_num_col_width := char_x_advance * 6;
        line_num_x := files_rect.x + files_rect.w / 4;
        text_x     := line_num_x + line_num_col_width + 2 * char_x_advance;

        max_code_chars := cast(s32)((files_rect.x + files_rect.w - text_x) / char_x_advance) - 1;  // NOTE: counts tab as one char

        entry_rect := cut_top(files_rect, entry_height);
        filename_scissor := cut_left(files_rect, line_num_x - entry_rect.x - char_x_advance);
        if !is_valid(filename_scissor) then filename_scissor = entry_rect;

        for entry, i : visible_entries {
            entry_index := visible_start + i;
            entry_rect.y = files_rect.y + files_rect.h - (entry_index + 1) * entry_height + scroll_y;

            if mouse_pointer_is_within(entry_rect) && is_hovering_over(ui_id) {
                if mouse.left.just_pressed then selected_by_mouse = entry_index;
                if selected_by_mouse == -1 then draw_rect(entry_rect, Colors.LIST_CURSOR_LITE);
                placement := ifx ctrl_or_cmd_pressed() then Editor_Placement.on_the_side else .in_place;
                if selected_by_mouse == entry_index && mouse.left.just_released then finder_open_selected_result(entry_index, placement);
            }
            if selected_by_mouse == entry_index then draw_rect(entry_rect, Colors.LIST_CURSOR);
            if entry_index == selected then draw_rect(entry_rect, Colors.LIST_CURSOR);

            pen := make_vector2(
                entry_rect.x + margin + padding,
                entry_rect.y + (entry_rect.h - font_ui.character_height) / 2 + 2 * dpi_scale,
            );
            width: float;

            // Not sure if it's cheaper to do this for the visible results only, but every frame,
            // or do it once when searching, but for every resuls (and bloat the search result size).
            // Chose the first option at least for now.
            buffer := *open_buffers[entry.buffer_id];
            line_num := offset_to_line(buffer, min(entry.match_offset, xx buffer.bytes.count));
            line_range := Offset_Range.{ start = get_line_start_offset(buffer, line_num), end = get_line_end_offset(buffer, line_num) };
            text_start := line_range.start + count_whitespace(buffer.bytes, line_range.start, line_range.end);

            // Draw file info
            {
                push_scissor(filename_scissor);
                defer pop_scissor();

                width, pen = draw_file_info(buffer, width, padding, pen, bold = false);
            }

            // Line number
            width = xx Simp.prepare_text(font_ui_small, tprint("%", line_num + 1));
            Simp.draw_prepared_text(font_ui_small, xx (line_num_x + line_num_col_width - width), xx pen.y, color = Colors.UI_DIM);

            // Draw code line
            {
                match_start := entry.match_offset;
                match_end   := min(entry.match_offset + finder.needle.count, line_range.end);  // if we have a multi-line match, we will still show only the first line
                line_start  := ifx text_start <= match_start then text_start else line_range.start;
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
                    line_str := to_string(array_view(buffer.bytes, line_start, line_range.end));
                    byte_offset = slice_chars(line_str, 0, xx char_offset).count;
                }

                pen.x = text_x;
                if char_offset > 0 {
                    // Line was cut on the left, draw an ellipsis
                    Simp.draw_text(font, xx pen.x, xx pen.y, "…", color = Colors.UI_DIM);
                    pen.x += char_x_advance;
                }
                if buffer.needs_coloring || buffer.colors.count != buffer.bytes.count then recalculate_colors(buffer);  // right before drawing

                // Draw highlight
                highlight_rect := entry_rect;
                highlight_rect.x = pen.x + char_x_advance * (chars_until_match_start - char_offset);
                highlight_rect.w = char_x_advance * (chars_until_match_end - chars_until_match_start);
                draw_rect(shrink_y(highlight_rect, padding), Colors.SEARCH_RESULT_INACTIVE);

                // Draw line
                visible_range := Offset_Range.{
                    start = line_start + xx byte_offset,
                    end   = min(line_range.end, line_start + xx byte_offset + 4 * max_code_chars),  // max 4 bytes per char
                };
                line_str := get_range_as_string(buffer, visible_range);
                if line_str.count > 0 {
                    colors   := array_view(buffer.colors, visible_range.start, line_str.count);
                    code_lines: [1] Simp.Code_Line;
                    code_lines[0] = .{ line = line_str, tab_spaces = 0, colors = colors };
                    Simp.draw_code(font, xx pen.x, xx pen.y, char_x_advance, line_height, code_lines, CODE_COLOR_MAP, TAB_SIZE);
                }
            }
        }

        if finder.input.text && !results {
            label := "Searching...";
            if !finder.request.in_progress {
                label = "No results found.";
                if case_sensitive {
                    combo := key_sequence_for_action_as_string(Action_Search_Dialog.toggle_case_sensitive);
                    label = tprint("%   Match case is active (% to toggle).", label, combo);
                }
                if whole_word {
                    combo := key_sequence_for_action_as_string(Action_Search_Dialog.toggle_whole_word);
                    label = tprint("%   Match whole word is active (% to toggle).", label, combo);
                }
            }
            entry_rect := cut_top(files_rect, entry_height);
            pen := make_vector2(
                entry_rect.x + margin + padding,
                entry_rect.y + (entry_rect.h - font_ui.character_height) / 2 + 2 * dpi_scale,
            );
            Simp.draw_text(font_ui_small, xx pen.x, xx pen.y, label, Colors.UI_DIM);
        }

        // Deselect any previously clicked entry
        if mouse.left.just_released || !mouse.left.is_down then selected_by_mouse = -1;

        if scroll_y != 0 then draw_top_down_shadow(cut_top(files_rect, char_x_advance));
    }

    if ui.active != .none && ui.active != ui_id && !is_child(ui.active, ui_id) && !is_child(ui.active, input_id) {
        finder_close();
        return;
    }
}

draw_go_to_line_dialog :: (active_editor_rect: Rect) {
    input_id := get_ui_id_from_loc();

    margin  := floor(8 * dpi_scale);
    padding := floor(4 * dpi_scale);

    label_width := cast(float) Simp.prepare_text(font_ui, "Go to line");
    width  := max(active_editor_rect.w * 0.5, 6 * char_x_advance + 2 * (margin + padding + 1));
    height := font_ui_line_height + 2 * (margin + padding + 1);

    bar_rect := cut_top(active_editor_rect, height);
    bar_rect = cut_right(bar_rect, width);
    bar_rect.x -= 2 * char_x_advance;

    maybe_set_hot_or_active(input_id, bar_rect, .NORMAL);

    input_rect := shrink(bar_rect, margin);
    input_rect = cut_right(input_rect, input_rect.w - (label_width + margin));

    draw_rounded_rect_with_shadow(bar_rect, Colors.BACKGROUND_LIGHT);

    pen := Vector2.{
        x = bar_rect.x + margin,
        y = bar_rect.y + (bar_rect.h - cast(s32)font_ui.character_height) / 2 + 2,  // sigh
    };
    Simp.draw_prepared_text(font_ui, xx pen.x, xx pen.y, color = Colors.UI_DEFAULT);
    draw_text_input(*go_to_line_dialog.input, input_rect, ui_id = input_id, active = true, label = " line number");
}

get_cursor_screen_pos :: (text_origin: Vector2, coords: Coords) -> Vector2 {
    return make_vector2(
        text_origin.x + coords.col * char_x_advance,
        text_origin.y - coords.line * line_height,
    );
}

draw_range :: (range: Coords_Range, buffer: Buffer, visible_start: s32, visible_end: s32, text_origin: Vector2, color: Color) {
    // Scan the visible range and add the number of chars on each line
    range_chars: [..] s32;
    range_chars.allocator = temp;
    // array_reserve(*range_chars, visible_end - visible_start + 1);

    start := max(range.start.line, visible_start);
    end   := min(range.end.line,   visible_end);

    for start..end {
        s := get_line_as_string(buffer, xx it);
        array_add(*range_chars, num_chars_in_string(s));  // we need to refer to prev/next line, so storing it in an array
    }

    for line_num : start..end {
        i := line_num - start;
        is_first := i == 0;
        is_last  := i == range_chars.count - 1;

        first_char := 0;
        last_char  := range_chars[i];
        if is_first then first_char = range.start.col;
        if is_last  then last_char  = range.end.col;

        if first_char == last_char continue;  // nothing is selected on this line

        rect := make_rect(
            text_origin.x + first_char * char_x_advance,
            text_origin.y - line_num * line_height,
            (last_char - first_char) * char_x_advance,
            line_height,
        );

        tl, tr, bl, br: Corner_Rounding = .none;
        if is_first {
            tl = .in; tr = .in;
        } else {
            prev_start := ifx i == 1 then range.start.col else 0;
            prev_end   := range_chars[i - 1];
            if prev_start < first_char then tl = .out;
            if prev_start > first_char then tl = .in;
            if prev_end > last_char then tr = .out;
            if prev_end < last_char || prev_start > last_char then tr = .in;
        }
        if is_last {
            bl = .in; br = .in;
        } else {
            next_start := 0;
            next_end   := ifx i == range_chars.count - 2 then range.end.col else range_chars[i + 1];
            if next_start < first_char then bl = .out;
            if next_start > first_char || next_end < first_char || next_end == 0 then bl = .in;
            if next_end < last_char then br = .in;
            if next_end > last_char then br = .out;
        }
        draw_rounded_rect_with_corners(rect, color, tl, tr, br, bl);
    }
}

draw_text_input :: (using input: *Text_Input, rect_: Rect, ui_id: Ui_Id, active := false, label: string = "", font: *Simp.Dynamic_Font = null, _color := Colors.NONE, margin_left := 1.0, margin_right := 1.0) {
    if !is_valid(rect_) return;

    color := ifx _color == Colors.NONE then Colors.UI_DEFAULT else _color;

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
    cursor_pos_x     := Simp.get_text_width(font, slice(input_text, 0, cursor.pos));
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
        cursor_sel_x := Simp.get_text_width(font, slice(input_text, 0, cursor.sel));
        left  := min(cursor_pos_x, cursor_sel_x);
        right := max(cursor_pos_x, cursor_sel_x);
        selection_rect := cursor_rect;
        selection_rect.x = x + left;
        selection_rect.w = xx (right - left);
        draw_rect(selection_rect, Colors.SELECTION_ACTIVE);
    }

    y := input_rect.y + (input_rect.h - font.character_height) / 2 + 2 * dpi_scale;  // I don't know why we need this extra + 2, but without it the text doesn't look in the right place

    if !input_text then Simp.draw_text(font, xx x, xx y, label, color = Colors.TEXT_INPUT_LABEL);
    draw_rect(cursor_rect, ifx active then Colors.CURSOR else Colors.CURSOR_INACTIVE);
    Simp.draw_text(font, xx x, xx y, input_text, color = color);
}

draw_text_input_modifier_button :: (input_id: Ui_Id, input_rect: Rect, width: float, enabled: bool, icon: string, loc := #caller_location) -> pressed: bool, hover: bool {
    ui_id := get_ui_id_from_loc(loc, parent_id = input_id);

    btn := cut_right(input_rect, width);
    btn = shrink(btn, 2 * dpi_scale);
    btn = align_to_grid(btn);

    maybe_set_hot_or_active(ui_id, btn, .PRESSABLE);

    hover := is_hovering_over(ui_id);
    bg_color := ifx hover then Colors.BACKGROUND_BRIGHT else Colors.BACKGROUND_LIGHT;

    if hover then draw_rounded_rect(shrink(btn, 1), bg_color);

    if enabled {
        draw_rounded_rect(shrink(btn, 1), Colors.CURSOR_INACTIVE);
        draw_rounded_rect(shrink(btn, 2), bg_color);
    }

    text_w := cast(float) Simp.prepare_text(font_icons_small, icon);
    text_h := font_icons_small.character_height;
    text_x := btn.x + btn.w / 2 - text_w / 2 + 1;
    text_y := btn.y + btn.h / 2 - text_h / 2 + 1;
    text_color := ifx enabled then Colors.UI_DEFAULT else Colors.UI_DIM;

    Simp.draw_prepared_text(font_icons_small, xx text_x, xx text_y, text_color);

    return hover && mouse.left.just_pressed, hover;
}

draw_tooltip_bottom_left :: (text: string, pos: Vector2) {
    padding := 4 * dpi_scale;

    width := cast(float) Simp.prepare_text(font_ui_very_small, text);
    rect := Rect.{ x = pos.x, y = pos.y };
    rect.w = width + 2 * padding;
    rect.x -= rect.w;
    rect.h = 2 * padding + font_ui_very_small.character_height;
    rect.y -= rect.h;

    draw_rounded_rect_with_shadow(rect, Colors.BACKGROUND_LIGHT);
    Simp.draw_prepared_text(font_ui_very_small, xx (rect.x + padding), xx (rect.y + (rect.h - font_ui_very_small.character_height) / 2) + 1, Colors.UI_DEFAULT);
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
    if shadow_size <= 0 then shadow_size = char_x_advance * 2;
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

draw_circle :: (center: Vector2, color: Color, radius: float, softness := 1.0, $set_shader := true) {
    #if set_shader then Simp.set_shader_for_circles();
    if radius <= 0 then radius = rounding_radius;

    rect := Rect.{ x = center.x - radius, y = center.y - radius, w = radius * 2, h = radius * 2 };

    p0 := bottom_left(rect);
    p2 := top_right(rect);

    Simp.immediate_rounded_rect(p0, p2, color, center, .{}, radius, softness);
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

get_new_scroll_target_from_scrollbar :: (main_rect: Rect, width: float, content_height: float, scroll: s32, scroll_target: s32, max_scroll: s32, ui_id: Ui_Id) -> new_scroll_target: s32 {
    return draw_scrollbar(main_rect, width, content_height, scroll, scroll_target, max_scroll, ui_id, draw = false);
}

draw_scrollbar :: (main_rect: Rect, width: float, content_height: float, scroll: s32, scroll_target: s32, max_scroll: s32, ui_id: Ui_Id, $draw := true) -> new_scroll_target: s32 {
    if max_scroll <= 0 return scroll_target;

    area := cut_right(main_rect, width);  // the scrollbar area of the main rect
    scrollbar := area;  // handle
    scrollbar.h = floor(area.h * (area.h / content_height));
    scroll_zone_size := area.h - scrollbar.h;  // the room for y to move

    if scroll_zone_size <= 0 return scroll_target;  // don't draw

    maybe_set_hot_or_active(ui_id, area, .NORMAL);

    // Draw
    color := Colors.SCROLLBAR;

    if is_hovering_over(ui_id) {
        #if draw draw_rounded_rect(area, Colors.SCROLLBAR_BACKGROUND, radius = rounding_radius_small);
        color = Colors.SCROLLBAR_HOVER;
    }
    separator_rect := shrink_y(cut_left(area, 1), rounding_radius_small);
    #if draw draw_rect(separator_rect, Colors.SCROLLBAR_BACKGROUND);
    scrollbar.y += (cast(float) (max_scroll - scroll) / max_scroll) * scroll_zone_size;
    scrollbar.y = floor(scrollbar.y);
    scrollbar = shrink(scrollbar, 1);
    if scrollbar.h < 5 then scrollbar.h = 5;  // don't make it too tiny
    #if draw draw_rounded_rect(scrollbar, color, radius = rounding_radius_small);

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

        scroll_target = clamp(cast(s32) new_scroll_target, 0, max_scroll);
    }

    return scroll_target;
}

draw_button :: (font: *Simp.Dynamic_Font, label: string, color: Color, text_color: Color, parent_id: Ui_Id, row_rect: Rect, align: enum { left; right; } = .right, padding_v: float, padding_h: float, loc := #caller_location) -> pressed: bool, width: float {
    label_width := cast(float) Simp.prepare_text(font, label);

    button := row_rect;
    button.w = label_width + 2 * padding_h;
    button.h = cast(float) font.character_height + 2 * padding_v;
    if align == .right then button.x = row_rect.x + row_rect.w - button.w;

    button_ui_id := get_ui_id_from_loc(loc, parent_id = parent_id);

    maybe_set_hot_or_active(button_ui_id, button, .PRESSABLE);

    rect_color := color;
    if is_hovering_over(button_ui_id) then rect_color.a = 0.7; else rect_color.a = 0.6;
    if ui.active == button_ui_id {
        button.y -= 1;
        rect_color.a = 0.6;
    }
    draw_rounded_rect(button, rect_color);

    pen := Vector2.{ x = button.x + padding_h, y = button.y + (button.h - font.character_height) / 2 + 3 * dpi_scale };
    Simp.draw_prepared_text(font, xx pen.x, xx pen.y, text_color);

    return ui.active_last_frame == button_ui_id && mouse_pointer_is_within(button) && mouse.left.just_released, button.w;
}

#scope_file

push_scissor :: (rect: Rect) {
    set_scissor_rect(rect);
    array_add(*scissor_stack, rect);
}

pop_scissor :: () {
    Simp.immediate_flush();  // if we have any remaining vertices, flush them before removing the scissor

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
    return (ui.hot_last_frame == ui_id && ui.active == .none) || ui.active == ui_id;
}

ui: struct {
    active: Ui_Id = .none;
    hot:    Ui_Id = .none;
    hot_last_frame: Ui_Id = .none;
    active_last_frame: Ui_Id = .none;
}

Ui_Id :: enum s64 {
    none                :: -1;
    unavailable         :: -2;

    editor_single       :: -3;
    editor_left         :: -4;
    editor_right        :: -5;
    editor_splitter     :: -6;
    open_file_dialog    :: -7;
    finder              :: -8;
    splash_screen       :: -9;
    unsaved_buffers     :: -10;
    commands_dialog     :: -11;
    open_project_dialog :: -12;

    // The rest will be derived from loc
}

// NOTE: this is a silly global variable which represents the distance between
// the center of slider and the point where we grabbed it.
// Since we can only drag one slider at a time, this will work, but in a more
// clean way this should probably be stored in widget storage?
// Problem is, we don't have much else to store for scrollbars...
scrollbar_grab_point: float;

// What to select when dragging
selection_mode: Selection_Mode;

scissor_stack: [..] Rect;

// Please keep at the bottom - needed for ui elements parent-child relationships
NUM_LINES_OF_CODE :: #run #location().line_number;

GOLDEN_RATIO :: 1.6180339;
