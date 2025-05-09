draw_frame :: () {
    #if OS == .WINDOWS {
        /*
         * On Windows, drawing to an OpenGL window while the window is minimized seems to be causing
         * DCs to be created continously until the window is restored (at a rate of ~3/second from my
         * observations). I'm not sure *WHY* this happens, I don't see any code in either Focus or
         * any of the modules it uses that would cause this. I suspect "driver magic" to be at play
         * here.
         *
         * We can work-around this by simply not drawing while the window is minimized.
         *
         * - ileonte, 2024.12.28
         */

        if Input.window_minimized return;
    }

    {
        c := map_color_to_vec4(Color.BACKGROUND_1);
        Simp.clear_render_target(c.x, c.y, c.z, c.w);
    }
    if !is_valid(screen) || screen.w < MIN_WINDOW_WIDTH || screen.h < MIN_WINDOW_HEIGHT return;

    maybe_set_hot_or_active(.none, screen, .NORMAL);

    // Check whether we need to deactivate elements before drawing
    if (!mouse.left.is_down || mouse.left.just_released) && (!mouse.middle.is_down || mouse.middle.just_released) then ui.active = .none;

    // Draw editors
    if editors_get_layout() == .None {
        draw_welcome_screen(screen);
    } else {
        root_editor_pane_id := get_ui_id_from_loc();
        draw_editor_pane(editors.root, screen, root_editor_pane_id, 1);
    }

    active_editor_rect: Rect = ---;
    {
        leaf_pane_rects := gather_leaf_pane_rects();
        for leaf_pane_rects {
            if it.pane == editors.active_pane { active_editor_rect = it.rect; break; }
        }
    }

    // !!!!!!!!!!!!! TODO: handle toggle_expand, then delete
    // if #complete editors.layout == {
    //     case .None;
    //         editors_snap_splitter(0.5);
    //         draw_welcome_screen(screen);

    //     case .Single;
    //         editors_snap_splitter(0.5);
    //         draw_editor(editors.left, screen, status_bar_height, .editor_single);
    //         active_editor_rect = screen;

    //     case .Double;
    //         // Drag splitter
    //         if ui.active == .editor_splitter {
    //             editors_snap_splitter((mouse.pointer.x - screen.x) / screen.w);
    //             editors.expanded = false;
    //         }
    //         if !values_are_close(splitter_pos, splitter_anim.target) {
    //             redraw_requested = true;
    //             splitter_pos = get_animation_value(splitter_anim);  // removed the clamp because we want to close smoothly. Will this cause problems? Not sure
    //         } else if editor_closing_id >= 0 {
    //             finish_closing_editor();
    //         }
    //         if editors.expanded {
    //             if active_editor_id == editors.left  && !values_are_close(splitter_anim.target, 0.9) then editors_start_moving_splitter(0.9);
    //             if active_editor_id == editors.right && !values_are_close(splitter_anim.target, 0.1) then editors_start_moving_splitter(0.1);
    //         }

    //         split_x := screen.w * splitter_pos;
    //         left_rect, right_rect := cut_left(screen, split_x, margin = 2);

    //         draw_editor(editors.left,  left_rect,  status_bar_height, .editor_left,  screen);
    //         draw_editor(editors.right, right_rect, status_bar_height, .editor_right, screen);

    //         active_editor_rect = ifx active_editor_id == editors.left then left_rect else right_rect;

    //         splitter_rect := make_rect(left_rect.x + left_rect.w, 0, 2, left_rect.h);
    //         draw_splitter(splitter_rect, split_x, .editor_splitter);

    //     case .Multi;
    //         // @split
    // }

    panel_is_active, panel_editor_rect := maybe_draw_color_preview_panel(active_editor_rect);
    if panel_is_active then active_editor_rect = panel_editor_rect;

    panel_is_active, panel_editor_rect  = maybe_draw_build_panel();
    if panel_is_active then active_editor_rect = panel_editor_rect;

    if #complete active_global_widget == {
        case .editors;                          // already done
        case .build_panel;                      // already done
        case .open_file_dialog;                 draw_open_file_dialog();
        case .delete_file_dialog;               draw_delete_file_dialog();
        case .finder;                           draw_finder();
        case .go_to_line_dialog;                draw_go_to_line_dialog(active_editor_rect);
        case .switch_to_project_dialog;         draw_switch_to_project_dialog();
        case .unsaved_buffers_dialog;           draw_unsaved_buffers_dialog();
        case .confirm_overwrite_dialog;         draw_confirm_overwrite_dialog();
        case .commands_dialog;                  draw_commands_dialog();
        case .theme_dialog;                     draw_theme_dialog();
        case .language_dialog;                  draw_language_dialog();
        case .kill_running_command_dialog;      draw_kill_running_command_dialog();
    }

    draw_user_messages(screen);
    draw_key_sequence_in_progress(active_editor_rect);

    // Reset UI state after drawing
    if (!mouse.left.is_down || mouse.left.just_released) && (!mouse.middle.is_down || mouse.middle.just_released) {
        ui.active = .none;
    } else if ui.active == .none {
        ui.active = .unavailable;  // so that we don't activate anything by dragging on it
    }
    ui.hot_last_frame    = ui.hot;
    ui.active_last_frame = ui.active;

    Simp.swap_buffers(window);
}

draw_editor_pane :: (using pane: *Editor_Pane, rect: Rect, root_pane_id: Ui_Id, unique_pane_id: int) {
    assert(pane != null);
    if !is_valid(rect) return;

    pane_ui_id := get_ui_id_for_pane(root_pane_id, unique_pane_id);

    if layout == .single {
        if editor_index >= 0 {
            draw_editor(editor_ids[editor_index], rect, pane_ui_id, pane);
        } else {
            clicked := maybe_set_hot_or_active(pane_ui_id, rect, .NORMAL);
            if clicked {
                activate_editors();
                editors.active_pane = pane;
                redraw_requested = true;
            }
        }
        if pane == editors.active_pane && active_global_widget == .editors && editors_get_layout() == .Multi {
            size := floor(config.settings.active_pane_border_width * dpi_scale);
            if !pane.editor_ids && size <= 0 then size = floor(1 * dpi_scale);  // draw a border around empty panes because otherwise it's not clear which one is selected
            draw_rect_border(rect, size = size, color = Color.ACTIVE_PANE_BORDER);
        }
        if pane != editors.active_pane {
            if !pane.editor_ids {
                // Draw a border around empty panes because otherwise they might not be visible
                draw_rect_border(rect, size = floor(1 * dpi_scale), color = Color.BACKGROUND_0);
            }
            if config.settings.inactive_pane_dim_overlay_opacity > 0 {
                // Dim inactive panes
                dim_color := map_color_to_vec4(Color.INACTIVE_PANE_DIM_OVERLAY);
                dim_color.w = config.settings.inactive_pane_dim_overlay_opacity;
                draw_rect_with_raw_color(rect, dim_color);
            }
        }
        if just_dropped_files && is_hovering_over(pane_ui_id) {
            for path : just_dropped_files  editors_open_file_in_pane(path, pane);
            just_dropped_files = .[];
            redraw_requested = true;
        }
    } else {
        splitter_ui_id := get_ui_id_from_loc(parent_id = pane_ui_id);
        if ui.active == splitter_ui_id {
            // Dragging splitter
            if layout == .horizontal {
                splitter_pos = (mouse.pointer.x - rect.x) / rect.w;
            } else {
                splitter_pos = (mouse.pointer.y - rect.y) / rect.h;
            }
            splitter_pos = clamp(splitter_pos, 0.1, 0.9);
        }

        // NOTE: this logic is duplicated in gather_leaf_pane_rects
        rect1, rect2, splitter_rect: Rect;
        if layout == .horizontal {
            rect1, rect2 = cut_left(rect, rect.w * splitter_pos, margin = PANE_SPLITTER_WIDTH);
            splitter_rect = make_rect(rect1.x + rect1.w, rect1.y, PANE_SPLITTER_WIDTH, rect1.h);
        } else {
            rect2, rect1 = cut_bottom(rect, rect.h * splitter_pos, margin = PANE_SPLITTER_WIDTH);
            splitter_rect = make_rect(rect2.x, rect2.y + rect2.h, rect2.w, PANE_SPLITTER_WIDTH);
        }

        // We cannot use the normal mechanism for specifying parent-child relationship between panes
        // because we're going to run out of id space very soon, so we have to use a special way
        // of identifying panes:
        left_unique_id  :=  unique_pane_id << 1;
        right_unique_id := (unique_pane_id << 1) | 1;
        draw_editor_pane(child1, rect1, root_pane_id, left_unique_id);
        draw_editor_pane(child2, rect2, root_pane_id, right_unique_id);

        draw_splitter(splitter_rect, splitter_ui_id, layout == .horizontal);
    }
}

draw_rect_border :: (rect: Rect, size: float, color: Color) {
    left, right := cut_left(rect, size), cut_right(rect, size);
    rect_x := shrink_x(rect, size);
    top, bottom := cut_top(rect_x, size), cut_bottom(rect_x, size);

    draw_rect(left,   color);
    draw_rect(right,  color);
    draw_rect(top,    color);
    draw_rect(bottom, color);
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
        draw_rect(left_area, .BACKGROUND_3, extra_draw_info = .{is_background = true});

        Simp.set_shader_for_rects();

        circle := logo_rect;
        draw_rounded_rect(circle, Color.BACKGROUND_1, radius = circle.w / 2, set_shader = false);
        circle = shrink(circle, shrink_step);
        draw_rounded_rect(circle, Color.BACKGROUND_0, radius = circle.w / 2, set_shader = false);
        circle = shrink(circle, shrink_step);
        draw_rounded_rect(circle, Color.BACKGROUND_3, radius = circle.w / 2, set_shader = false);

        font := font_ui_big;
        version_text := tprint("Version %", VERSION);
        version_width := cast(float) Simp.prepare_text(font, version_text);
        if version_width / info_area.w > 0.8 {
            font = font_ui;
            version_width = cast(float) Simp.prepare_text(font, version_text);
        }
        if version_width < info_area.w {
            x := (info_area.w - version_width) / 2;
            y := info_area.y + info_area.h - shrink_step - font_ui_line_height;
            Simp.draw_prepared_text(font, xx x, xx y, color = xx Color.UI_DIM);

            // Copy version when clicking on it
            {
                version_rect := Rect.{ x, y, version_width, font_ui_line_height};
                version_ui_id := get_ui_id_from_loc();
                clicked := maybe_set_hot_or_active(version_ui_id, version_rect, .PRESSABLE);
                if clicked {
                    os_clipboard_set_text(version_text);
                    add_success_message("Version copied to clipboard", dismiss_in_seconds = 3);
                }
                if is_hovering_over(version_ui_id) then draw_tooltip_bottom_left("Click to copy to clipboard", Vector2.{ mouse.pointer.x, y });
            }

            date_width := Simp.prepare_text(font_ui_medium, RELEASE_DATE);
            x = (info_area.w - date_width) / 2;
            y -= 1.5 * font_ui_big_line_height;
            Simp.draw_prepared_text(font_ui_medium, xx x, xx y, color = xx Color.UI_DIM);
        }
    }

    // Draw the right part
    {
        draw_rect(right_area, .BACKGROUND_0, extra_draw_info = .{is_background = true});

        Shortcut :: struct { action: Action_Common; description: string; }

        SHORTCUTS_TO_DISPLAY :: Shortcut.[
            .{ .show_commands,                      "Show All Commands" },
            .{ .open_file_by_name,                  "Open File By Name" },
            .{ .navigate_to_file,                   "Navigate To File" },
            .{ .switch_between_open_files,          "Switch Between Open Files" },
            .{ .search_in_buffer,                   "Search In Open File" },
            .{ .search_in_buffer_dropdown_mode,     "Search In Open File (Dropdown Mode)" },
            .{ .search_in_project,                  "Search In Workspace" },
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
                    draw_rounded_rect(shadow_rect, Color.BACKGROUND_1);
                    draw_rounded_rect(key_rect, Color.SELECTION_ACTIVE);
                    Simp.draw_prepared_text(font_ui, xx (x + padding_h), xx text_y, xx Color.UI_DEFAULT);
                    x += key_rect.w;
                    if it_index < combo_strings.count - 1 {
                        Simp.draw_text(font_ui, xx (x + padding_h), xx text_y, "+", xx Color.UI_DEFAULT);
                        x += plus_width + 2 * padding_h;
                    }
                }

                x += padding_between_parts;
            }

            if !key_sequence_strings {
                Simp.draw_text(font_ui, xx (x - padding_h), xx text_y, "-", xx Color.UI_DEFAULT);
                x += padding_between_parts;
            }

            Simp.draw_text(font_ui, xx (x + padding_h * 10), xx text_y, shortcut.description, xx Color.UI_DEFAULT);

            y -= line_height;
        }
    }

}

draw_user_messages :: (main_area: Rect) {
    user_messages := get_user_messages(frame_time);
    if !user_messages return;

    ui_id := get_ui_id_from_loc();

    margin  := floor(12 * dpi_scale);
    padding := floor( 8 * dpi_scale);

    message_rect_src := shrink(main_area, margin);
    if !is_valid(message_rect_src) return;

    if config.settings.status_bar_position == .bottom then message_rect_src.y += status_bar_height;

    for < * user_messages {
        // Figure out message height
        lines := split(it.message, cast(u8) #char "\n",, allocator = temp);

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
            case .error;    color = Color.UI_ERROR;
            case .warning;  color = Color.UI_WARNING_DIM;
            case .success;  color = Color.UI_SUCCESS;
        }
        draw_rounded_rect_with_shadow(message_rect, color, extra_draw_info = .{is_background = true});

        text_color := Color.UI_DEFAULT;
        pen_x := cast(s64) (message_rect.x + padding);
        pen_y := cast(s64) (message_rect.y + message_rect.h - padding) - font_ui.character_height;

        y := pen_y;
        for line : lines {
            x := pen_x;
            Simp.draw_text(font_ui, x, y, line, xx text_color);
            y -= xx font_ui_line_height;
        }

        message_rect_src.y += message_height + margin;
    }
}

draw_key_sequence_in_progress :: (active_editor_rect: Rect) {
    if !key_sequence_input_in_progress() return;

    margin  := floor(12 * dpi_scale);
    padding_v := floor(4 * dpi_scale);
    padding_h := floor(6 * dpi_scale);

    rect_height := cast(float) font_ui_small.character_height + 2 * padding_v;

    pen := bottom_left(active_editor_rect) + Vector2.{ margin, margin };
    if config.settings.status_bar_position == .bottom && editors_get_layout() != .None then pen.y += status_bar_height;

    text_y := pen.y + padding_v * 1.5;

    for 0 .. key_sequence_input.active_sequence_length - 1 {
        combo_strings := key_combo_strings(key_sequence_input.potential_multipart_matches[0].mapping.key_sequence[it]);
        combo := join(..combo_strings, "-",, temp);
        if it == key_sequence_input.active_sequence_length - 1 then combo = tprint("% ...", combo);

        rect := Rect.{ pen.x, pen.y, 0, rect_height };
        rect.w = xx Simp.prepare_text(font_ui_small, combo) + 2 * padding_h;
        rect = align_to_grid(rect);
        shadow_rect := expand(rect, 1);
        shadow_rect.y -= 2;
        draw_rounded_rect(shadow_rect, Color.BACKGROUND_1);
        draw_rounded_rect(rect, Color.SELECTION_ACTIVE);
        Simp.draw_prepared_text(font_ui_small, xx (pen.x + padding_h), xx text_y, xx Color.UI_DEFAULT);
        pen.x += rect.w + padding_h;
    }
}

should_draw_color_preview_panel :: (active_editor_id: s64) -> bool {
    active_editor, active_buffer := get_visible_editor_and_buffer();
    if !active_editor return false;
    if active_buffer.lang != .Focus_Config && active_buffer.lang != .Focus_Theme && !is_color_preview_panel(active_editor_id) return false;
    if active_buffer.readonly return false;

    if !is_color_preview_panel(active_editor_id) {
        // Only show the panel if the cursor is within the [colors] section of the config
        using config_extra := cast(*Focus_Config_Extra) active_buffer.extra;
        pos := active_editor.cursors[active_editor.main_cursor].pos;
        if !config_extra || (colors_section_start < 0) || (pos < colors_section_start) || (colors_section_end >= 0 && pos > colors_section_end) return false;
    }

    return true;
}

maybe_draw_color_preview_panel :: (active_editor_rect: Rect) -> (drawn: bool = false, editor_rect: Rect = .{}) {
    if config.settings.color_preview_popup == .disabled return;
    if !workspace_scan_complete return;  // don't init the popup until all buffers are ready, otherwise we won't know the usage stats

    active_editor_id := get_visible_editor_id(editors.active_pane);
    if !should_draw_color_preview_panel(active_editor_id) return;

    if !color_preview_is_shown {
        // Draw a "minimised" button instead of the popup
        padding := floor(12 * dpi_scale);
        shrinked_screen  := shrink_x(shrink_y(active_editor_rect, font_ui_line_height + 2 * padding), 2 * padding);
        buttons_row_rect := cut_bottom(shrinked_screen, font_ui_line_height + 2 * padding);
        activated := draw_button(font_ui, "Show Color Preview", Color.BACKGROUND_4, Color.UI_DEFAULT, get_ui_id_from_loc(), buttons_row_rect, .right, padding / 2, padding, shadow_size = char_x_advance);
        if activated then show_color_preview();
        if !color_preview_is_shown return;  // if we just activated it, draw it right this frame. John Carmack would be happy
    }

    // Switch the color map temporarily and then revert
    color_preview_begin_draw(active_editor_id);
    defer color_preview_end_draw();

    // Drag the panel title bar first before drawing
    if ui.active == .color_preview_title_bar {
        color_preview_set_width((active_editor_rect.x + active_editor_rect.w - (mouse.pointer.x - panel_grab_point.x)) / active_editor_rect.w);
        color_preview_set_height((mouse.pointer.y - panel_grab_point.y - active_editor_rect.y) / active_editor_rect.h);
    }

    margin := floor(4 * dpi_scale);

    color_preview_rect := cut_right(active_editor_rect, active_editor_rect.w * color_preview_width, margin = 2);
    color_preview_rect=, color_picker_rect := cut_bottom(color_preview_rect, color_preview_rect.h * color_preview_height);
    if config.settings.status_bar_position == .bottom {
        _, color_preview_rect = cut_bottom(color_preview_rect, status_bar_height);
    }
    if !is_valid(color_preview_rect) return;

    draw_rounded_rect_with_shadow(color_preview_rect, Color.BACKGROUND_0, radius = 0.1, shadow_size = char_size, extra_draw_info = .{is_background = true});

    title_bar_height := font_ui_line_height + 2 * margin + 4 * dpi_scale;
    title_bar_rect, panel_body_rect := cut_top(color_preview_rect, title_bar_height);

    if !is_valid(title_bar_rect) return;

    // Draw title bar
    {
        started_dragging := maybe_set_hot_or_active(.color_preview_title_bar, title_bar_rect, .NORMAL, .left);
        if started_dragging then panel_grab_point = mouse.pointer - top_left(title_bar_rect);
        if ui.active == .color_preview_title_bar then set_pointer_image(.DRAGGING_FREE);
        if ui.hot_last_frame == .color_preview_title_bar && ui.active == .none && mouse.middle.just_pressed then hide_color_preview();

        push_scissor(title_bar_rect);
        defer pop_scissor();

        draw_rect(title_bar_rect, Color.BACKGROUND_4, extra_draw_info = .{is_background = true});

        pen := Vector2.{
            x = title_bar_rect.x + char_x_advance,
            y = title_bar_rect.y + (title_bar_rect.h - font_ui_bold.character_height) / 2 + 2,
        };
        Simp.draw_text(font_ui_bold, xx pen.x, xx pen.y, "Color Preview — hover over text to view color names, click to jump to color definition", xx Color.UI_DEFAULT);

        // Draw the close button
        {
            button_rect := cut_right(title_bar_rect, title_bar_rect.h);
            button_id := get_ui_id_from_loc();
            clicked := maybe_set_hot_or_active(button_id, button_rect, .PRESSABLE);
            if clicked {
                hide_color_preview();
                redraw_requested = true;
            }

            color := Color.UI_DIM;
            if is_hovering_over(button_id) color = Color.UI_DEFAULT;
            icon_char := convert_utf32_to_utf8(xx Icon.xmark);
            icon_width := Simp.prepare_text(font_icons, to_string(*icon_char));
            icon_x := button_rect.x + (button_rect.w - icon_width) / 2 ;
            Simp.draw_prepared_text(font_icons, xx icon_x, xx pen.y, color = xx color);
        }

        hr := cut_bottom(title_bar_rect, 1);
        draw_rect(hr, Color.BACKGROUND_1, extra_draw_info = .{is_background = true});
    }

    if !is_valid(panel_body_rect) return;

    padding := floor(8 * dpi_scale);

    // Draw text
    editor_id := color_preview_get_editor_id();
    color_preview_ui_id := get_ui_id_from_loc();

    editor_rect, warning_rect: Rect;
    warning_text := color_preview_get_warning();
    if warning_text {
        height := font_ui_line_height + 2 * padding;
        warning_rect, editor_rect = cut_top(panel_body_rect, height);

        push_scissor(warning_rect);
        defer pop_scissor();

        draw_rect(warning_rect, Color.UI_WARNING_DIM);
        x := cast(s64) (warning_rect.x + padding);
        y := cast(s64) (warning_rect.y + warning_rect.h - padding) - font_ui.character_height;
        Simp.draw_text(font_ui, x, y, warning_text, xx Color.UI_DEFAULT);
    } else {
        editor_rect = panel_body_rect;
    }

    langs_rect:, editor_rect = cut_right(editor_rect, editor_rect.w * 0.14);

    // Draw the language list
    if is_valid(langs_rect) {
        langs_ui_id := get_ui_id_from_loc();
        pressed := maybe_set_hot_or_active(langs_ui_id, langs_rect, .NORMAL);

        push_scissor(langs_rect);
        defer pop_scissor();

        hr:, langs_rect = cut_left(langs_rect, 1);
        draw_rect(hr, Color.BACKGROUND_1, extra_draw_info = .{is_background = true});
        draw_rect(langs_rect, Color.BACKGROUND_2, extra_draw_info = .{is_background = true});

        languages, selected_lang := color_preview_get_languages();
        entry_height := cast(s64) (font_ui_line_height + padding);
        entry_rect := cut_top(langs_rect, xx entry_height);
        entry_rect.y -= padding;
        x := cast(s64) (entry_rect.x + padding * 1.5);
        y := cast(s64) (entry_rect.y + (entry_rect.h - font_ui.character_height) / 2.0 + 2);
        for lang : languages {
            if mouse_pointer_is_within(entry_rect) && is_hovering_over(langs_ui_id) {
                draw_rect(entry_rect, Color.LIST_CURSOR_LITE);
                set_pointer_image(.PRESSABLE);
                if pressed then color_preview_set_language(it_index);
            }
            if it_index == selected_lang {
                draw_rect(entry_rect, Color.LIST_CURSOR);
            }
            Simp.draw_text(font_ui, x, y, lang, xx Color.UI_DEFAULT);
            y -= entry_height;
            entry_rect.y -= entry_height;
        }
    }

    draw_editor(editor_id, editor_rect, color_preview_ui_id, has_status_bar = false);

    if ui.hot_last_frame == color_preview_ui_id {
        // Draw a tooltip with the correct color name
        editor, buffer := get_editor_and_buffer(editor_id);
        text_rect := get_editor_subrects(editor_id, editor_rect, has_status_bar = false);
        mouse_coords := coords_from_mouse_position(editor, text_rect);
        buffer_pos   := coords_to_offset(editor, buffer, mouse_coords);
        if buffer_pos >= 0 && buffer_pos < buffer.tokens.count {
            color_name := "background0";
            if is_whitespace_char(buffer.bytes[buffer_pos]) {
                for buffer.regions {
                    if it.end   <= buffer_pos continue;
                    if it.start <  buffer_pos then color_name = tprint("region_%", it.kind);
                    if it.start >  buffer_pos break;
                }
            } else {
                color_name = tprint("code_%", buffer.tokens[buffer_pos]);
            }
            draw_tooltip_bottom_left(color_name, mouse.pointer);
            if mouse.left.just_pressed then color_preview_jump_to_color_name(color_name);
        }
    }

    color_picker_rect = shrink_y(color_picker_rect, font_ui_line_height / 2);
    color_preview_draw_color_picker(color_picker_rect);

    return is_color_preview_panel(active_editor_id), editor_rect;
}

draw_color_picker :: (editor_id: s64, editor: *Editor, buffer: *Buffer, picker_rect: Rect, range: Offset_Range) {
    if !is_valid(picker_rect)  return;

    color_change_callback :: (rgba: Vector4, hsl: Vector3, finalize: bool) {
        using buffer_info := cast(*Color_Change_Buffer_Info) color_picker_dialog.color_change_callback_data;
        str := color_to_hex(rgba, exclude_hash = true);
        for i : 0 .. str.count-1  str[i] = to_upper(str[i]);
        old_str := cast(string) to_view(buffer.bytes, range.start, range.end - range.start);
        if old_str != str then add_paste_animation(editor_id, .{ range.start, range.end});
        if finalize {
            new_edit_group(buffer, editor);
            replace_range(buffer, range, str);
        } else {
            range_len := range.end - range.start;
            if str.count > range_len then str = slice(str, 0, range_len);  // don't replace with a bigger string unless we're adding to history too
            replace_range_raw(buffer, range.start, range.end, str);
        }
        rescan_for_lines(buffer);
        if editor.line_wrap == .on then rescan_for_wrapped_lines(editor, buffer);
    }

    color_picker_dialog.color_change_callback = color_change_callback;
    color_change_callback_data := Color_Change_Buffer_Info.{editor_id, editor, buffer, range};
    color_picker_dialog.color_change_callback_data = *color_change_callback_data;

    ui_id    := Ui_Id.color_picker_dialog;
    axis_id  := get_ui_id_from_loc(parent_id = ui_id);
    alpha_id := get_ui_id_from_loc(parent_id = ui_id);
    main_id  := get_ui_id_from_loc(parent_id = ui_id);

    if ui.active != axis_id && ui.active != alpha_id && ui.active != main_id then color_picker_set_color(buffer, range);

    rect := picker_rect;
    if rect.w > rect.h then rect = cut_right(rect, rect.h);
    if rect.h > rect.w then rect = cut_bottom(rect, rect.w);

    Simp.immediate_flush();

    draw_rounded_rect_with_shadow(rect, Color.BACKGROUND_0, radius = 0.1, shadow_size = char_size, extra_draw_info = .{is_background = true});
    widget_size := line_height;
    bottom, top := cut_bottom(rect, widget_size);
    axis_rect, main_rect  := cut_left(top,    widget_size);
    mode_rect, alpha_rect := cut_left(bottom, widget_size);

    maybe_set_hot_or_active(axis_id, axis_rect, .PRESSABLE);
    if ui.active == axis_id || (ui.hot_last_frame == axis_id && mouse.left.just_released) {
        v := clamp(mouse.pointer.y - axis_rect.y, 0, axis_rect.h) / axis_rect.h;
        color_picker_set_value(v, mouse.left.just_pressed || mouse.left.just_released);
    }

    maybe_set_hot_or_active(alpha_id, alpha_rect, .PRESSABLE);
    if ui.active == alpha_id || (ui.hot_last_frame == alpha_id && mouse.left.just_released) {
        v := clamp(mouse.pointer.x - alpha_rect.x, 0, alpha_rect.w) / alpha_rect.w;
        color_picker_set_alpha(v, mouse.left.just_pressed || mouse.left.just_released);
    }

    maybe_set_hot_or_active(main_id, main_rect, .PRESSABLE);
    if ui.active == main_id || (ui.hot_last_frame == main_id && mouse.left.just_released) {
        x := clamp(mouse.pointer.x - main_rect.x, 0, main_rect.w) / main_rect.w;
        y := clamp(mouse.pointer.y - main_rect.y, 0, main_rect.h) / main_rect.h;
        color_picker_set_point(.{x, y}, mouse.left.just_pressed || mouse.left.just_released);
    }

    // Shrink the sliders a little so a gap is drawn between them and the main panel.
    // We do this after the UI interactions above, so the user can't accidentally click
    // in the gap (which would register in the editor window and move the cursor)
    axis_rect.w  -= dpi_scale;
    alpha_rect.h -= dpi_scale;

    draw_gradient_rect(axis_rect, color_picker_dialog.mode | .vertical_1d, color_picker_dialog.hsl.x);
    draw_gradient_rect(alpha_rect, .alpha_horizontal_1d, 1.0);
    draw_gradient_rect(main_rect, color_picker_dialog.mode, color_picker_dialog.value);

    Simp.set_shader_for_color(enable_blend = true);

    inner := axis_rect;
    inner.y += inner.h * color_picker_dialog.value - dpi_scale;
    inner.h = 3 * dpi_scale;
    inner = expand_x(inner, 1 * dpi_scale);
    outer := expand(inner, 1 * dpi_scale);
    draw_rect_with_raw_color(outer, .{0, 0, 0, 1});
    draw_rect_with_raw_color(inner, .{1, 1, 1, 1});

    inner = alpha_rect;
    inner.x += inner.w * color_picker_dialog.rgba.w - dpi_scale;
    inner.w = 3 * dpi_scale;
    inner = expand_y(inner, 1 * dpi_scale);
    outer = expand(inner, 1 * dpi_scale);
    draw_rect_with_raw_color(outer, .{0, 0, 0, 1});
    draw_rect_with_raw_color(inner, .{1, 1, 1, 1});

    inner = main_rect;
    inner.x += inner.w * color_picker_dialog.point.x - dpi_scale;
    inner.y += inner.h * color_picker_dialog.point.y - dpi_scale;
    inner.w = 3 * dpi_scale; inner.h = 3 * dpi_scale;
    outer = expand(inner, 1 * dpi_scale);
    draw_rect_with_raw_color(outer, .{0, 0, 0, 1});
    draw_rect_with_raw_color(inner, .{1, 1, 1, 1});

    mode_id := get_ui_id_from_loc(parent_id = ui_id);
    label   := slice("RGBHSL", xx color_picker_dialog.mode, 1);
    pressed := draw_icon_button(mode_id, mode_rect, label, .square);
    if pressed  color_picker_set_mode(color_picker_dialog.mode + 1);

    Simp.immediate_flush();
}

maybe_draw_build_panel :: () -> (drawn: bool = false, editor_rect: Rect = .{}) {
    if !build_panel_is_shown return;

    position := build_panel_get_position();

    // Drag build panel title bar first before drawing
    if ui.active == .build_panel_title_bar {
        if position == .left {
            build_panel_set_width(((mouse.pointer.x - screen.x) - panel_grab_point.x) / screen.w);
        } else {
            build_panel_set_width((screen.x + screen.w - (mouse.pointer.x - panel_grab_point.x)) / screen.w);
        }
        build_panel_set_height((mouse.pointer.y - panel_grab_point.y - screen.y) / screen.h);
    }

    build_panel_rect: Rect;
    if position == .left {
        build_panel_rect = cut_left(screen, screen.w * build_panel_width, margin = 2);
    } else {
        build_panel_rect = cut_right(screen, screen.w * build_panel_width, margin = 2);
    }
    if !values_are_close(build_panel_height, build_panel_height_anim.target) {
        redraw_requested = true;
        build_panel_height = get_animation_value(build_panel_height_anim);
    }
    build_panel_rect = cut_bottom(build_panel_rect, build_panel_rect.h * build_panel_height);

    if config.settings.status_bar_position == .bottom && editors_get_layout() != .None {
        _, build_panel_rect = cut_bottom(build_panel_rect, status_bar_height);
    }

    if !is_valid(build_panel_rect) return;
    draw_rounded_rect_with_shadow(build_panel_rect, Color.BUILD_PANEL_BACKGROUND, radius = 0.1, shadow_size = char_size, extra_draw_info = .{is_background = true});

    margin := floor(4 * dpi_scale);
    title_bar_height := font_ui_line_height + 2 * margin + 4 * dpi_scale;
    title_bar_rect, build_output_rect := cut_top(build_panel_rect, title_bar_height);

    if !is_valid(title_bar_rect) return;

    // Draw title bar
    {
        started_dragging := maybe_set_hot_or_active(.build_panel_title_bar, title_bar_rect, .NORMAL, .left);
        if started_dragging {
            if position == .left {
                panel_grab_point = mouse.pointer - top_right(title_bar_rect);
            } else {
                panel_grab_point = mouse.pointer - top_left(title_bar_rect);
            }
        }
        if ui.active == .build_panel_title_bar then set_pointer_image(.DRAGGING_FREE);
        if ui.hot_last_frame == .build_panel_title_bar && ui.active == .none && mouse.middle.just_pressed then hide_build_panel();

        push_scissor(title_bar_rect);
        defer pop_scissor();

        draw_rect(title_bar_rect, Color.BUILD_PANEL_TITLE_BAR, extra_draw_info = .{is_background = true});

        pen := Vector2.{
            x = title_bar_rect.x + char_x_advance,
            y = title_bar_rect.y + (title_bar_rect.h - font_ui_bold.character_height) / 2 + 2,
        };
        Simp.draw_text(font_ui_bold, xx pen.x, xx pen.y, "Build Output", xx Color.UI_DEFAULT);

        // Draw the close button
        {
            button_rect := cut_right(title_bar_rect, title_bar_rect.h);
            button_id := get_ui_id_from_loc();
            clicked := maybe_set_hot_or_active(button_id, button_rect, .PRESSABLE);
            if clicked {
                hide_build_panel();
                redraw_requested = true;
            }

            color := Color.UI_DIM;
            if is_hovering_over(button_id) color = Color.UI_DEFAULT;
            icon_char := convert_utf32_to_utf8(xx Icon.xmark);
            icon_width := Simp.prepare_text(font_icons, to_string(*icon_char));
            icon_x := button_rect.x + (button_rect.w - icon_width) / 2 ;
            Simp.draw_prepared_text(font_icons, xx icon_x, xx pen.y, color = xx color);
        }

        hr := cut_bottom(title_bar_rect, 1);
        draw_rect(hr, Color.BACKGROUND_1, extra_draw_info = .{is_background = true});
    }

    if !is_valid(build_output_rect) return;

    // Draw text
    editor_id := build_panel_get_editor_id();
    draw_editor(editor_id, build_output_rect, get_ui_id_from_loc(), has_status_bar = false);

    is_active := build_panel_is_active();
    if is_active && config.settings.active_pane_border_width > 0 {
        draw_rect_border(build_output_rect, size = floor(config.settings.active_pane_border_width * dpi_scale), color = Color.ACTIVE_PANE_BORDER);
    }

    return is_active, build_output_rect;
}

get_editor_subrects :: (editor_id: s64, main_area: Rect, has_status_bar: bool) -> editor_rect: Rect, status_bar_rect: Rect, line_number_panel: Rect {
    status_bar_rect, rect, line_number_panel: Rect;

    editor, buffer := get_editor_and_buffer(editor_id);
    buffer_settings := get_settings(buffer);

    if buffer_settings.status_bar_position == .bottom {
        status_bar_rect, rect = cut_bottom(main_area, ifx has_status_bar then status_bar_height else 0);
    } else {
        status_bar_rect, rect = cut_top(main_area, ifx has_status_bar then status_bar_height else 0);
    }

    max_width := cast(float) buffer_settings.max_editor_width * dpi_scale;
    if max_width > 0 && rect.w > max_width && !is_build_panel(editor_id) {
        rect.x += (rect.w - max_width) / 2;
        rect.w = max_width;
    }

    if buffer_settings.show_line_numbers && !is_build_panel(editor_id) {
        max_lines  := get_max_line_num(editor, buffer) + 1;
        num_digits := tprint("%", max_lines).count;
        panel_width := (num_digits + 2) * char_x_advance;
        if rect.w > panel_width then line_number_panel, rect = cut_left(rect, panel_width);
    }

    return align_to_grid(rect), status_bar_rect, line_number_panel;
}

get_text_offset :: inline () -> Vector2 {
    return Vector2.{char_x_advance, -char_x_advance};
}

coords_from_mouse_position :: (using editor: Editor, rect: Rect) -> Coords {
    pointer := snap_to_rect(mouse.pointer, rect);  // when we drag outside the editor we still want to interact
    mouse_pos := pointer - bottom_left(rect) - get_text_offset();
    mouse_pos.x += viewport.left;
    mouse_pos.y = rect.h - mouse_pos.y + viewport.top - ifx dpi_scale > 1.0 then 1 else 0;
    return .{ line = xx (mouse_pos.y / line_height), col = xx ((mouse_pos.x / char_x_advance) + 0.5) };
}

// TODO: remove total_editor_area
draw_editor :: (editor_id: s64, main_area: Rect, ui_id: Ui_Id, pane: *Editor_Pane = null, has_status_bar := true, total_editor_area := Rect.{}) {
    as_build_panel := is_build_panel(editor_id);

    using editor := *open_editors[editor_id];
    buffer := *open_buffers[buffer_id];

    buffer_settings := get_settings(buffer);

    if buffer_needs_tokenizing(buffer) then retokenize(buffer);  // right before drawing
    tab_size := get_buffer_tab_size(buffer);

    scrollbar_id := get_ui_id_from_loc(parent_id = ui_id);

    rect, status_bar_rect, line_number_panel := get_editor_subrects(editor_id, main_area, has_status_bar);

    if !is_valid(rect) return;

    became_active := maybe_set_hot_or_active(ui_id, rect, .TEXT_SELECT);
    if became_active {
        activate_editors();
        clear_all_lingering_actions();
    }

    active_editor_id := get_active_editor_id();
    editor_is_active := editor_id == active_editor_id && Input.input_application_has_focus;

    // Calculate text origin in screen coordinates
    text_offset := get_text_offset();
    text_origin := top_left(rect) + text_offset - Vector2.{xx viewport.left, line_height - viewport.top};

    width_in_chars := clamp(cast(s32) ((rect.w - 1.5 * text_offset.x) / char_x_advance), 1, S32_MAX);
    if width_in_chars != editor.last_width_in_chars {
        editor.last_width_in_chars = width_in_chars;
        if editor.line_wrap == .on then rescan_for_wrapped_lines(editor, buffer);
        redraw_requested = true;
    }

    if ui.active == ui_id && (mouse.left.just_pressed || mouse.left.is_dragging) {
        mouse_coords := coords_from_mouse_position(editor, rect);

        just_jumped_from_build_panel := false;

        cursors_stop_blinking();

        if ctrl_or_cmd_pressed() && !(mouse.left.is_dragging || mouse.left.just_double_clicked || mouse.left.just_triple_clicked) {
            click_offset := coords_to_offset(editor, buffer, mouse_coords);

            // Maybe delete a cursor if we clicked on an existing one
            deleted_cursor := false;
            if cursors.count > 1 {
                for cursor, i : cursors {
                    if cursor.pos == click_offset {
                        unordered_remove_by_index(*cursors, i);
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
                new_cursor := add(*cursors);
                new_cursor.pos = click_offset;
                new_cursor.sel = new_cursor.pos;

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

            cursor.pos = coords_to_offset(editor, buffer, mouse_coords);
            cursor.col_wanted = -1;

            if selection_mode.type == {
                case .chars;
                    search_whole_words = false;

                case .words;
                    char_type := get_char_type(get_char_at_offset(buffer, cursor.pos));

                    set_newline_is_whitespace(false);
                    if cursor.pos < selection_mode.range.start {
                        cursor.sel = selection_mode.range.end;
                        cursor.pos = scan_through_similar_chars_on_the_left(buffer, cursor.pos, char_type, skip_one_space = false);
                    } else {
                        cursor.sel = selection_mode.range.start;
                        cursor.pos = scan_through_similar_chars_on_the_right(buffer, cursor.pos, char_type, skip_one_space = false);
                    }
                    set_newline_is_whitespace(true);

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
            if !mouse_pointer_is_within(shrink(rect, char_size)) then cursor_moved = true;

            if !shift_pressed() && mouse.left.just_pressed then cursor.sel = cursor.pos;

            if mouse.left.just_double_clicked && as_build_panel && cursor_is_on_build_error(cursor) {
                go_to_build_error_under_cursor(cursor, ifx ctrl_or_cmd_pressed() then Editor_Placement.on_the_side else Editor_Placement.in_place);
                just_jumped_from_build_panel = true;
            } else if mouse.left.just_double_clicked {
                select_word(buffer, cursor);
                editor.search_whole_words = true;
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

        editor.refresh_selection = true;

        if mouse.left.just_pressed && !just_jumped_from_build_panel {
            make_editor_active(editor_id);
            redraw_requested = true;  // so that we don't draw 2 active editors
        }

    } else if ui.active == ui_id && (mouse.middle.just_pressed || mouse.middle.is_dragging) {
        mouse_coords := coords_from_mouse_position(editor, rect);

        cursors_stop_blinking();

        // Remove all cursors except the main one
        main_cursor := leave_only_main_cursor(editor);

        if mouse.middle.just_pressed {
            // Move main cursor to mouse_coords
            main_cursor.pos = coords_to_offset(editor, buffer, mouse_coords);
            main_cursor.sel = main_cursor.pos;

            editor_initial_middle_mouse_coords = mouse_coords;
        } else if mouse.middle.is_dragging {
            // Move main cursor to editor_initial_middle_mouse_coords
            main_cursor.pos = coords_to_offset(editor, buffer, editor_initial_middle_mouse_coords);
            main_cursor.sel = main_cursor.pos;

            // Check if we need to select some lines
            select_some_lines: bool;

            min_line_number := min(mouse_coords.line, editor_initial_middle_mouse_coords.line);
            max_line_number := max(mouse_coords.line, editor_initial_middle_mouse_coords.line);

            for min_line_number..max_line_number {
                if get_char_at_coords(editor, buffer, .{ it, min(mouse_coords.col, editor_initial_middle_mouse_coords.col) }) {
                    select_some_lines = true;
                    break;
                }
            }

            if !select_some_lines {
                // If there is no line to select we add a cursor at the end of each line
                for min_line_number..max_line_number {
                    if it == mouse_coords.line continue;
                    cursor := add(*editor.cursors);
                    cursor.pos = get_line_end_offset(editor, buffer, it);
                    cursor.sel = cursor.pos;
                }
            } else {
                main_cursor_already_moved: bool;
                maybe_create_cursor_or_move_main_cursor_to_this_line :: () #expand {
                    if !get_char_at_coords(editor, buffer, .{ `it, min(mouse_coords.col, editor_initial_middle_mouse_coords.col) }) return;

                    cursor: Cursor;
                    cursor.pos = coords_to_offset(editor, buffer, .{ `it, mouse_coords.col });
                    cursor.sel = coords_to_offset(editor, buffer, .{ `it, editor_initial_middle_mouse_coords.col });

                    if !main_cursor_already_moved {
                        main_cursor_already_moved = true;

                        // This condition only occur one time before we add any other cursor
                        // so the main_cursor pointer will not be invalidated by 'array_add'
                        // and we can use it to set its new position.
                        main_cursor.* = cursor;
                    } else {
                        add(*editor.cursors, cursor);
                    }
                }

                if mouse_coords.line >= editor_initial_middle_mouse_coords.line {
                    for   editor_initial_middle_mouse_coords.line..mouse_coords.line  maybe_create_cursor_or_move_main_cursor_to_this_line();
                } else {
                    for #v2 < mouse_coords.line..editor_initial_middle_mouse_coords.line  maybe_create_cursor_or_move_main_cursor_to_this_line();
                }
            }

            organise_cursors(editor);
        }

        editor.refresh_selection = true;

        // Activate editor
        make_editor_active(editor_id);
        if mouse.middle.just_pressed then redraw_requested = true; // so that we don't draw 2 active editors
    }

    if (!mouse.left.is_down || mouse.left.just_released) {
        selection_mode.type = .chars;
        selection_mode.min_range.start = 0;
        selection_mode.min_range.end   = 0;
        if new_cursor_just_created_using_mouse && to_float64_seconds(frame_time - last_cursor_created_using_mouse_at) >= (2 * DOUBLE_CLICK_SPEED) then new_cursor_just_created_using_mouse = false;
    }

    // Get the coordinates of all cursors
    // @Speed: instead of doing it every frame we could do it when cursors change only - but probably it's ok
    cursor_coords := NewArray(cursors.count, Cursor_Coords, initialized = false,, allocator = temp);
    for cursors cursor_coords[it_index] = get_cursor_coords(editor, buffer, it);

    visible_lines_start: s32;
    visible_lines_end:   s32;
    visible_offset_range: Offset_Range;
    cursors_off_screen := 0;

    // Draw editor
    {
        min_visible_chars :: 5;

        push_scissor(rect);
        defer pop_scissor();

        // Handle editor scrolling here because we only know the layout at this point.
        num_editor_lines := get_max_line_num(editor, buffer);
        content_height := (num_editor_lines + 2) * line_height;
        scroll_behind_height := 0.0;
        scroll_behind_lines: s32 = 12;
        if buffer_settings.scroll_beyond_last_line && !as_build_panel && !is_color_preview_panel(editor_id) then content_height += (rect.h - 3 * line_height);
        if buffer_settings.scroll_behind_first_line && !as_build_panel && !is_color_preview_panel(editor_id) then scroll_behind_height = (scroll_behind_lines * line_height);

        min_y_scroll := cast(s32) -scroll_behind_height;
        max_y_scroll := max(cast(s32)(content_height - rect.h), 0);

        if (ui.hot_last_frame == ui_id || ui.hot_last_frame == scrollbar_id) && mouse_pointer_is_within(rect) && mouse.scroll_y_delta != 0 {
            // Mousewheel scrolling - vertical
            // We only handle vertical scrolling here because horizontal scrolling depends on the
            // length of the longest visible line, which we can only determine once we determine
            // the first visible line. Thus we need to "resolve" vertical scrolling before we can
            // properly handle horizontal scrolling.
            using editor.viewport;
            new_target := clamp(scroll_y.target - mouse.scroll_y_delta, min_y_scroll, max_y_scroll);
            if mouse.smooth_scroll {
                start_animation(*scroll_y, top, new_target);
            } else {
                scroll_y.target = new_target;
                top = new_target;
                viewport_remember_glue_point(editor, buffer);
            }
        } else if cursor_moved {
            // Detect if cursor is off screen and start scrolling to it
            bounds := shrink_x(rect, text_offset.x + char_x_advance * min_visible_chars);
            bounds  = shrink_y(bounds, -text_offset.y + line_height * min_visible_chars);
            bounds.h += 2;
            bounds.y -= line_height + 2;
            if bounds.w < 0 || bounds.h < 0 then bounds = rect;  // fall back
            // draw_background_rect(bounds, Color.BACKGROUND_1);

            screen_pos := get_cursor_screen_pos(text_origin, cursor_coords[main_cursor].pos);
            if !point_within(screen_pos, bounds) {
                left, top, right, bottom := get_rect_sides(bounds);
                offset: Vector2;
                if screen_pos.x < left   then offset.x = screen_pos.x - left;
                if screen_pos.y < bottom then offset.y = screen_pos.y - bottom;
                if right < screen_pos.x  then offset.x = screen_pos.x - right;
                if top   < screen_pos.y  then offset.y = screen_pos.y - top;

                left_target := max(viewport.left  + cast(s32) offset.x, 0);
                top_target  := clamp(viewport.top - cast(s32) offset.y, min_y_scroll, max_y_scroll);

                if left_target != viewport.scroll_x.target {
                    if buffer_settings.disable_viewport_chasing_cursor_near_the_edge && abs(left_target - viewport.scroll_x.target) < cast(s32) (2 * char_x_advance) {
                        snap_viewport_left_to_target(editor, left_target);
                    } else {
                        start_animation(*viewport.scroll_x, viewport.left, left_target);
                    }
                }
                if top_target != viewport.scroll_y.target {
                    if buffer_settings.disable_viewport_chasing_cursor_near_the_edge && abs(top_target - viewport.scroll_y.target) < cast(s32) (2 * line_height) {
                        snap_viewport_top_to_target(editor, buffer, top_target);
                    } else {
                        start_animation(*viewport.scroll_y, viewport.top, top_target);
                    }
                }
            }
        } else if scroll_to_cursor != .no {
            using editor.viewport;

            cursor_pos_from_left := cursor_coords[main_cursor].pos.col  * char_x_advance + text_offset.x;
            cursor_pos_from_top  := cursor_coords[main_cursor].pos.line * line_height;
            left_target          := cast(s32) max(cursor_pos_from_left - rect.w + char_x_advance * 3, 0);
            top_target           := cast(s32) max(cursor_pos_from_top  - rect.h / 2,  -scroll_behind_height);
            if left_target != scroll_x.target then start_animation(*viewport.scroll_x, viewport.left, left_target);
            if top_target  != scroll_y.target then start_animation(*viewport.scroll_y, viewport.top,  top_target);

            scroll_to_cursor = .no;

            cursors_start_blinking();
        }

        // With line wrap enabled we never want to scroll horizontally, so just snap to left always
        if line_wrap_is_active(editor) {
            viewport.scroll_x.target = 0;
            viewport.left   = 0;
        }

        if editor.refresh_selection && buffer.bytes.count <= MAX_BUFFER_SIZE_FOR_HIGHLIGHTS {
            reset_keeping_memory(*editor.highlights);

            // Maybe update selection highlights
            if buffer_settings.highlight_selection_occurrences {
                selected_text := get_selected_text_all_cursors(editor, buffer);
                if selected_text.count > 2 && !is_all_whitespace(selected_text) {
                    search_func: (s: string, substring: string, start_index := 0) -> s64;
                    search_func = ifx editor.search_whole_words then find_index_from_left_whole_word else find_index_from_left;
                    buffer_str := to_string(buffer.bytes);

                    cursor_offsets: [..] s32;
                    cursor_offsets.allocator = temp;
                    for editor.cursors  array_add(*cursor_offsets, min(it.pos, it.sel));

                    offset := 0;
                    while true {
                        offset = search_func(buffer_str, selected_text, start_index = offset);
                        if offset < 0 break;

                        if !array_find(cursor_offsets, cast(s32) offset) {  // @Speed: slow when many cursors
                            highlight := add(*editor.highlights);
                            highlight.offset = cast(s32) offset;
                            highlight.count  = cast(s32) selected_text.count;
                            highlight.line   = offset_to_real_line(buffer, offset);
                        }

                        offset += selected_text.count;
                    }
                }
            }

            // Maybe find matching brackets
            if buffer_settings.highlight_matching_brackets {
                for cursor : cursors {
                    pos: s32 = -1;
                    if is_bracket(buffer, cursor.pos - 1) {
                        pos = cursor.pos - 1;
                    } else if is_bracket(buffer, cursor.pos) {
                        pos = cursor.pos;
                    }
                    if pos < 0 continue;

                    offset := find_matching_bracket(buffer, pos);
                    if offset < 0 continue;

                    // Highlight matching bracket
                    add(*editor.highlights, .{
                        offset = offset,
                        count  = 1,
                        line   = offset_to_real_line(buffer, offset),
                        type   = .bracket,
                    });

                    // Highlight the bracket we're standing on
                    add(*editor.highlights, .{
                        offset = pos,
                        count  = 1,
                        line   = offset_to_real_line(buffer, pos),
                        type   = .bracket,
                    });
                }
            }

            quick_sort(to_view(editor.highlights), (a, b) => (a.offset - b.offset));
        }

        if buffer_settings.status_bar_show_selected_text_length && editor.refresh_selection then calculate_selected_text_length(editor, buffer);

        editor.refresh_selection = false;  // should probably move this to some central place where we reset stuff

        // Keyboard smooth scrolling - vertical
        // As mentioned above, we can properly perform horizontal scrolling only once vertical
        // scrolling is done, allowing us to determine the longest visible line.
        if (editor_smooth_scroll.direction == .up || editor_smooth_scroll.direction == .down) && editor_id == active_editor_id {
            speed := 60 * line_height;  // pixels per second
            if editor_smooth_scroll.fast then speed *= 2;
            time_elapsed := cast(float) to_float64_seconds(frame_time - editor_smooth_scroll.started_at);
            new_scroll_y := cast(float) editor_smooth_scroll.start_y;
            if editor_smooth_scroll.direction == {
                case .up;    new_scroll_y -= time_elapsed * speed;
                case .down;  new_scroll_y += time_elapsed * speed;
            }
            scroll_y_target := clamp(cast(s32) new_scroll_y, min_y_scroll, max_y_scroll);
            snap_viewport_top_to_target(editor, buffer, scroll_y_target);
        }

        if viewport.top == viewport.scroll_y.target {
            viewport_glue_to_point(editor, buffer);
        } else {
            redraw_requested = true;
            viewport.top = get_animation_value(viewport.scroll_y);
            viewport_remember_glue_point(editor, buffer);
        }

        // If we're past the max scrolling point for any reason (e.g. just deleted some text),
        // snap back into the allowed range immediately.
        // Do it after we've handled cursor_moved AND after calculating the next scroll_y animation value, because it uses viewport.top
        if viewport.top > max_y_scroll || viewport.scroll_y.target > max_y_scroll {
            snap_viewport_top_to_target(editor, buffer, max_y_scroll);
        }

        // Update scrollbar without drawing to get the new scrolling position (scrollbar will be drawn later)
        // Do it after we've handled cursor_moved AND after calculating the next scroll_y animation value, because it uses viewport.top
        new_scroll_target := get_new_scroll_target_from_scrollbar(rect, content_height, viewport.top, viewport.scroll_y.target, min_y_scroll, max_y_scroll, scrollbar_id);
        if new_scroll_target != viewport.scroll_y.target {
            // Jump immediately to the scroll point when dragging or clicking scrollbar
            snap_viewport_top_to_target(editor, buffer, new_scroll_target);
        }

        // Horizontal scrolling
        if viewport.left != viewport.scroll_x.target {
            redraw_requested = true;
            viewport.left = get_animation_value(viewport.scroll_x);
        }

        // Need to update after updating scrolling to reduce latency
        text_origin = top_left(rect) + text_offset - Vector2.{xx viewport.left, line_height - viewport.top};

        max_lines := get_max_line_num(editor, buffer);
        visible_lines_start = clamp(cast(s32) (viewport.top / line_height) - 1, 0, max_lines);
        visible_lines_end   = clamp(visible_lines_start + cast(s32) (rect.h / line_height) + 2, 0, max_lines);
        num_visible_lines   := visible_lines_end - visible_lines_start + 1;

        visible_offset_range = Offset_Range.{
            start = get_line_start_offset(editor, buffer, visible_lines_start),
            end   = get_line_start_offset(editor, buffer, visible_lines_end + 1),
        };

        max_line_pixel_width: s32 = 0;    // max horizontal scroll in pixels - for horizontal scrolling
        for line_num : visible_lines_start .. visible_lines_end {
            line_start := get_line_start_offset(editor, buffer, line_num);
            length     := get_line_start_offset(editor, buffer, line_num+1) - line_start;
            line       := to_view(buffer.bytes, line_start, length);

            line_pixel_width := cast(s32) ((num_cols_in_string(cast(string) line, tab_size) + min_visible_chars) * char_x_advance);
            max_line_pixel_width = max(max_line_pixel_width, line_pixel_width);
        }

        viewport_width := cast(s32) rect.w;
        max_x_scroll: s32 = 0;
        if max_line_pixel_width > viewport_width then max_x_scroll = max_line_pixel_width - viewport_width;

        // Now that we can compute max_x_scroll we can handle horizontal scrolling.
        // We handle both scrollwheel and keyboard smooth scrolling below.
        // Mousewheel scrolling - horizontal
        if (ui.hot_last_frame == ui_id || ui.hot_last_frame == scrollbar_id) && mouse_pointer_is_within(rect) && mouse.scroll_x_delta != 0 {
            using editor.viewport;
            new_target := clamp(scroll_x.target - mouse.scroll_x_delta, 0, max_x_scroll);
            if mouse.smooth_scroll {
                start_animation(*scroll_x, left, new_target);
            } else {
                scroll_x.target = new_target;
                left = new_target;
                viewport_remember_glue_point(editor, buffer);
            }
            redraw_requested = true;
        }
        // Keyboard smooth scrolling - horizontal
        if (editor_smooth_scroll.direction == .left || editor_smooth_scroll.direction == .right) && editor_id == active_editor_id {
            speed := 60 * char_x_advance;
            if editor_smooth_scroll.fast then speed *= 2;
            time_elapsed := cast(float) to_float64_seconds(frame_time - editor_smooth_scroll.started_at);
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
            viewport_remember_glue_point(editor, buffer);
            redraw_requested = true;
        }

        // Finished working out scroll position, so can now draw background
        if !as_build_panel then draw_rect(rect, Color.BACKGROUND_0, extra_draw_info = .{is_background = true});

        // Draw buffer regions
        for region : buffer.regions {
            if region.end   < visible_offset_range.start continue;
            if region.start > visible_offset_range.end   break;
            range := Coords_Range.{
                start = offset_to_coords(editor, buffer, region.start),
                end   = offset_to_coords(editor, buffer, region.end),
            };
            draw_range_full_width_lines(range, rect, visible_lines_start, visible_lines_end, text_origin, get_region_color(region.kind));
        }

        cursors_active := editor_is_active && active_global_widget == .editors;

        if !search_bar_is_open(editor) {
            Simp.set_shader_for_rects();
            for cursor : cursors {
                if has_selection(cursor) {
                    // Draw selections
                    range := get_selection(cursor);
                    if range.end   < visible_offset_range.start continue;
                    if range.start > visible_offset_range.end   break;

                    coords := cursor_coords[it_index];
                    selection := ifx cursor.pos < cursor.sel then Coords_Range.{ start = coords.pos, end = coords.sel } else .{ start = coords.sel, end = coords.pos };
                    color := ifx cursors_active then Color.SELECTION_ACTIVE else Color.SELECTION_INACTIVE;
                    draw_range(selection, editor, buffer, visible_lines_start, visible_lines_end, text_origin, color);
                }
                else if cursors_active && buffer_settings.highlight_line_with_cursor && !as_build_panel {
                    // Draw current line highlight
                    coords := cursor_coords[it_index];

                    // @Note: modified from hidden_chars_on_the_left below, get the x offset if we are scrolled horizontally
                    x_offset := max((viewport.left / char_x_advance) - 1, 0);

                    line_rect := Rect.{
                        x = text_origin.x + (x_offset * char_x_advance),
                        y = text_origin.y - coords.pos.line * line_height,
                        w = rect.w - ifx x_offset == 0 then char_x_advance,   // @Note: text_origin.x is 1 char_x_advance in, so if we can see the beginning of the line, shorten the rect
                        h = line_height,
                    };
                    draw_rect(line_rect, Color.BACKGROUND_4, extra_draw_info = .{is_background = true});
                }
            }
        }

        // Draw text highlights
        if !search_bar_is_open(editor) {
            for highlights {
                start, end := it.offset, it.offset + it.count;
                if end   < visible_offset_range.start continue;
                if start > visible_offset_range.end   break;

                range: Coords_Range = ---;
                range.start = offset_to_coords(editor, buffer, start);
                range.end   = offset_to_coords(editor, buffer, end);
                color := ifx it.type == .text then Color.SELECTION_HIGHLIGHT else Color.BRACKET_HIGHLIGHT;
                draw_range(range, editor, buffer, visible_lines_start, visible_lines_end, text_origin, color);
            }
        }

        // Draw indent guides
        if buffer_settings.draw_indent_guides && !as_build_panel {
            indent_levels: [..] int;
            indent_levels.allocator = temp;

            current_level := -1;
            for line_num : visible_lines_start .. visible_lines_end {
                line   := get_line_as_string(editor, buffer, line_num);
                indent := get_visual_indent_in_spaces(line, tab_size);

                indent_level := -1;
                if indent > 0 then indent_level = (indent - 1) / tab_size;
                if !trim_right(line) then indent_level = current_level; else current_level = indent_level;

                array_add(*indent_levels, indent_level);
            }

            guide := Rect.{ text_origin.x, text_origin.y - visible_lines_start * line_height, 1, line_height };
            Simp.set_shader_for_color(enable_blend = true);
            for level : indent_levels {
                for 0..level {
                    guide.x = text_origin.x + it * char_x_advance * tab_size;
                    draw_rect_raw(guide, Color.INDENT_GUIDE);
                }
                guide.y -= line_height;
            }
        }

        // Draw ruler
        if buffer_settings.show_ruler_at_column > 0 {
            x := text_origin.x + (buffer_settings.show_ruler_at_column - 1) * char_x_advance;
            r := Rect.{x, rect.y, dpi_scale, rect.h};
            draw_rect(r, Color.RULER);
        }

        // Draw search results
        if !is_empty(search_bar.results) {
            for search_bar.results {
                start, end := it.offset, it.offset + it.count;
                if end   < visible_offset_range.start continue;
                if start > visible_offset_range.end   break;

                range: Coords_Range = ---;
                range.start = offset_to_coords(editor, buffer, it.offset);
                range.end   = offset_to_coords(editor, buffer, it.offset + it.count);
                color := ifx search_bar.selected_result == it_index then Color.SEARCH_RESULT_ACTIVE else Color.SEARCH_RESULT_INACTIVE;
                draw_range(range, editor, buffer, visible_lines_start, visible_lines_end, text_origin, color);
            }
        }

        // Draw paste animations
        for * anim : editor_paste_animations {
            t := to_float64_seconds(frame_time - anim.started_at) / Paste_Animation.DURATION;
            if t >= 1 { remove anim; continue; }
            if anim.editor_id != editor_id continue;

            if !anim.initted {
                // We can't calculate coords when we're adding the animation, so have to defer to right before drawing
                anim.initted = true;
                anim.coords_range.start = offset_to_coords(editor, buffer, anim.range.start);
                anim.coords_range.end   = offset_to_coords(editor, buffer, anim.range.end);
            }

            draw_range(anim.coords_range, editor, buffer, visible_lines_start, visible_lines_end, text_origin, Color.PASTE_ANIMATION, alpha = xx (1 - t));
        }
        if editor_paste_animations.count > 0 then redraw_requested = true;

        // Draw inactive cursors before text
        if !cursors_active && !search_bar_is_open(editor) && buffer_settings.cursor_as_block && !as_build_panel {
            Simp.set_shader_for_rects();
            for cursor : cursors {
                if cursor.pos < visible_offset_range.start || cursor.pos > visible_offset_range.end continue;
                screen_pos := get_cursor_screen_pos(text_origin, cursor_coords[it_index].pos);

                rect := make_rect(screen_pos.x, screen_pos.y, char_x_advance, line_height);
                draw_rounded_rect(rect, Color.CURSOR, radius = rounding_radius_small, set_shader = true);
                draw_rounded_rect(shrink(rect, 1), Color.BACKGROUND_0, radius = rounding_radius_small, set_shader = false);
            }
        }

        // Draw text
        max_chars_horizontally   := cast(s32) (rect.w / char_x_advance) + 2;
        hidden_chars_on_the_left := cast(s32) max((viewport.left / char_x_advance) - 2, 0);

        pen := text_origin;
        pen.y += (line_height - char_x_advance) / 2 - visible_lines_start * line_height;
        pen.x += hidden_chars_on_the_left * char_x_advance;

        code_lines := NewArray(num_visible_lines, Simp.Code_Line, initialized = false,, allocator = temp);
        for line_num : visible_lines_start .. visible_lines_end {
            line_start := get_line_start_offset(editor, buffer, line_num);
            length     := get_line_start_offset(editor, buffer, line_num+1) - line_start;
            line       := cast(string) to_view(buffer.bytes, line_start, length);
            tab_spaces := 0;
            line, tab_spaces = advance_by_chars(line, hidden_chars_on_the_left, tab_size);
            line = take_first_n_chars(line, max_chars_horizontally, tab_size);
            line = trim_right(line, " \r\n");
            tokens := ifx line then to_view(buffer.tokens, line.data - buffer.bytes.data, line.count) else .[];
            code_lines[line_num-visible_lines_start] = .{ line = line, start_offset = line_start, tab_spaces = xx tab_spaces, tokens = xx,force tokens };
        }

        selections: [..] Offset_Range;
        selections.allocator = temp;
        for cursor : cursors {
            selection := get_selection(cursor);
            if selection.end   < visible_offset_range.start continue;
            if selection.start > visible_offset_range.end   break;
            array_add(*selections, selection);
        }

        draw_code(font_main, pen, code_lines, tab_size, selections, start_col = hidden_chars_on_the_left, is_colored = buffer.tokens.count > 0);

        // Draw continuation markers for wrapped lines
        if line_wrap_is_active(editor) && !buffer_settings.show_line_numbers && !as_build_panel {
            Simp.set_shader_for_rects();

            radius   := char_x_advance / 4;
            y_offset := (font_main.character_height - char_x_advance / 2) / 2;

            for line_num : visible_lines_start .. visible_lines_end {
                end_offset := get_line_end_offset(editor, buffer, line_num);
                if end_offset < buffer.bytes.count && buffer.bytes[end_offset] != #char "\n" && !is_last_line(editor, buffer, line_num) {
                    y := pen.y - line_height * (line_num - visible_lines_start) + y_offset;
                    right_mark := align_to_grid(expand(Rect.{ rect.x + rect.w + 1, y, 0, 0 }, radius));
                    draw_rounded_rect(right_mark, Color.CODE_DEFAULT, radius, set_shader = false);
                    left_mark := align_to_grid(expand(Rect.{ rect.x + 1, y - line_height, 0, 0 }, radius));
                    draw_rounded_rect(left_mark, Color.CODE_DEFAULT, radius, set_shader = false);
                }
            }
        }

        // Draw cursors when they are active
        cursor_as_block := buffer_settings.cursor_as_block && !as_build_panel;
        cursor_width := ifx cursor_as_block then char_x_advance else 2 * dpi_scale;
        cursors_are_visible := should_draw_cursors() && !search_bar_is_open(editor);

        if cursors_active {
            Simp.set_shader_for_rects();
            for cursor : cursors {
                if cursor.pos < visible_offset_range.start || cursor.pos > visible_offset_range.end {
                    cursors_off_screen += 1;
                    continue;
                }

                screen_pos := get_cursor_screen_pos(text_origin, cursor_coords[it_index].pos);
                if screen_pos.x >= rect.x + rect.w || screen_pos.x + char_x_advance <= rect.x || screen_pos.y >= rect.y + rect.h || screen_pos.y + line_height < rect.y {
                    cursors_off_screen += 1;  // additional check for visibility (offset is not reliable)
                }

                if !cursors_are_visible continue;  // check it within the loop so that we always calculate how many cursors are off screen

                cursor_rect := make_rect(screen_pos.x, screen_pos.y, cursor_width, line_height);
                cursor_rect = align_to_grid(cursor_rect);
                draw_rounded_rect(cursor_rect, Color.CURSOR, radius = rounding_radius_small, set_shader = true);

                // Draw the letter on top for better visibility
                if cursor_as_block {
                    letter := get_char_at_offset_as_string(buffer, cursor.pos);
                    if letter != "\n" {
                        Simp.draw_text(font_main, xx cursor_rect.x, xx (cursor_rect.y + (line_height - char_x_advance) / 2), letter, xx Color.CHAR_UNDER_CURSOR);
                    }
                }
            }
        }


        // Draw scrollbar and scrollbar marks
        draw_scrollbar(rect, content_height, viewport.top, viewport.scroll_y.target, min_y_scroll, max_y_scroll, scrollbar_id, as_build_panel);

        if !line_wrap_is_active(editor) && buffer_settings.show_scrollbar_marks {
            Simp.set_shader_for_color(enable_blend = true);

            marks_rect := cut_right(rect, scrollbar_width);
            marks_rect =  cut_top(marks_rect, rect.h * max_y_scroll / content_height);
            marks_rect_top := marks_rect.y + marks_rect.h;
            assert(buffer.line_starts.count > 0);

            highlight_mark_rect := shrink_x(marks_rect, marks_rect.w / 3);
            highlight_mark_rect.h = floor(4 * dpi_scale);

            total_scrollable_lines := content_height / line_height;

            if !is_empty(search_bar.results) {
                // Search results
                for search_bar.results {
                    pos_from_top := rect.h * cast(float) it.line / total_scrollable_lines;
                    highlight_mark_rect.y = marks_rect_top - pos_from_top - highlight_mark_rect.h;
                    draw_rect_raw(highlight_mark_rect, ifx it_index == search_bar.selected_result then Color.SEARCH_RESULT_ACTIVE else Color.SEARCH_RESULT_INACTIVE);
                }
            }

            if !search_bar_is_open(editor) {
                // Selection highlights
                for highlights {
                    pos_from_top := rect.h * cast(float) it.line / total_scrollable_lines;
                    highlight_mark_rect.y = marks_rect_top - pos_from_top - highlight_mark_rect.h;
                    draw_rect_raw(highlight_mark_rect, Color.SELECTION_HIGHLIGHT);
                }
            }

            // Cursor and selection marks
            cursor_mark_rect := marks_rect;
            cursor_mark_rect.h = 2 * dpi_scale;
            selection_mark_rect := cut_left(marks_rect, marks_rect.w / 3);

            for cursor : cursors {
                coords := cursor_coords[it_index];
                pos_from_top := rect.h * cast(float) coords.pos.line / total_scrollable_lines;
                cursor_mark_rect.y = marks_rect_top - pos_from_top - cursor_mark_rect.h;
                if has_selection(cursor) {
                    sel_from_top := rect.h * cast(float) coords.sel.line / total_scrollable_lines;
                    min_pos := min(pos_from_top, sel_from_top);
                    max_pos := max(pos_from_top, sel_from_top);
                    selection_mark_rect.y = marks_rect_top - max_pos - cursor_mark_rect.h;
                    selection_mark_rect.h = max_pos - min_pos + cursor_mark_rect.h;
                    draw_rect_raw(selection_mark_rect, Color.SELECTION_INACTIVE);
                }
                draw_rect_raw(cursor_mark_rect, Color.CURSOR);
            }
        }
    }

    // Draw line numbers
    if line_number_panel.w > 0 {
        push_scissor(line_number_panel);
        defer pop_scissor();

        draw_rect(line_number_panel, Color.BACKGROUND_0, extra_draw_info = .{is_background = true});

        // Get the visible lines which have cursors on them (for highlighting)
        active_lines: [..] s32;
        active_lines.allocator = temp;
        for cursor : editor.cursors {
            if cursor.pos < visible_offset_range.start continue;
            if cursor.pos > visible_offset_range.end   break;  // assuming the cursors are sorted

            line_num := offset_to_real_line(buffer, cursor.pos);
            array_add(*active_lines, line_num);
        }

        y := text_origin.y + (line_height - char_x_advance) / 2 - visible_lines_start * line_height;
        x := line_number_panel.x + line_number_panel.w - char_x_advance;

        if line_wrap_is_active(editor) {
            last_line_num := -1;

            for line_num : visible_lines_start .. visible_lines_end {
                line_start := get_line_start_offset(editor, buffer, line_num);
                real_line_num := offset_to_real_line(buffer, line_start);

                if real_line_num != last_line_num {
                    active := array_find(active_lines, real_line_num);
                    width := Simp.prepare_text(font_main, tprint("%", real_line_num + 1));
                    Simp.draw_prepared_text(font_main, xx (x - width), xx y, color = ifx active then cast(u8) Color.UI_DEFAULT else cast(u8) Color.UI_DIM);
                    last_line_num = real_line_num;
                }

                y -= line_height;
            }
        } else {
            for line_num : visible_lines_start .. visible_lines_end {
                active := array_find(active_lines, line_num);
                width := Simp.prepare_text(font_main, tprint("%", line_num + 1));
                Simp.draw_prepared_text(font_main, xx (x - width), xx y, color = ifx active then cast(u8) Color.UI_DEFAULT else cast(u8) Color.UI_DIM);
                y -= line_height;
            }
        }
    }

    // Draw search bar
    if active_global_widget != .editors && !(active_global_widget == .build_panel && as_build_panel) {
        search_bar.active = false;
    }

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

        max_search_results := cast(s32) (rect.h * 0.3 / entry_height);
        num_search_results := min(results.count, max_search_results);

        if mode == .classic then num_search_results = 0;

        top_rect_height := font_ui_line_height + 2 * padding + 2 * margin + 2;
        bar_rect_height := top_rect_height + entry_height * num_search_results;

        bar_rect := cut_top(main_area, bar_rect_height);
        bar_rect = cut_right(bar_rect, bar_rect.w * width_percentage);
        bar_rect.x -= 2 * char_x_advance;
        if buffer_settings.status_bar_position == .top bar_rect.y -= status_bar_height;

        top_rect, results_rect := cut_top(bar_rect, top_rect_height);

        draw_rounded_rect_with_shadow(bar_rect, Color.BACKGROUND_3, extra_draw_info = .{is_background = true});

        maybe_set_hot_or_active(input_id,   bar_rect, .NORMAL);
        maybe_set_hot_or_active(results_id, bar_rect, .NORMAL);

        numbers_width := cast(float) Simp.prepare_text(font_ui_small, " No results ");
        if !is_empty(results) {
            width := cast(float) Simp.prepare_text(font_ui_small, tprint(" % of % ", selected_result + 1, results.count));
            if width > numbers_width then numbers_width = width;
        }

        top_rect = shrink(top_rect, margin);
        numbers_rect, input_rect := cut_right(top_rect, numbers_width + padding);

        Simp.draw_prepared_text(font_ui_small, xx (numbers_rect.x + padding), xx (numbers_rect.y + (numbers_rect.h - font_ui_small.character_height) / 2.0), color = xx Color.UI_DEFAULT);
        input_active := editor_is_active && search_bar.active && active_global_widget == .editors;
        color := ifx !regex_search || (regex_search && regex_is_valid) then Color.UI_DEFAULT else Color.UI_ERROR_BRIGHT;
        draw_text_input(*search_bar.input, input_rect, active = input_active, ui_id = input_id, label = " Find in buffer", margin_right = input_rect.h * 2, color = color);

        button_width := input_rect.h;
        pressed, hover_match_case, hover_match_word, hover_regex_search := false, false, false, false;

        pressed, hover_match_case = draw_text_input_modifier_button(input_id, input_rect, button_width, case_sensitive, CASE_SENSITIVE_ICON);
        if pressed then search_bar_toggle_case_sensitive(editor, buffer);

        input_rect.w -= button_width - 4 * dpi_scale;

        pressed, hover_match_word = draw_text_input_modifier_button(input_id, input_rect, button_width, whole_word, WHOLE_WORD_ICON);
        if pressed then search_bar_toggle_whole_word(editor, buffer);

        input_rect.w -= button_width - 4 * dpi_scale;

        pressed, hover_regex_search = draw_text_input_modifier_button(input_id, input_rect, button_width, regex_search, REGEX_SEARCH_ICON);
        if pressed then search_bar_toggle_regex_search(editor, buffer);

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
        } else if hover_regex_search {
            tooltip = "Regex Search";
            combo := key_sequence_for_action_as_string(Action_Search_Dialog.toggle_regex_search);
            if combo then tooltip = tprint("% (%)", tooltip, combo);
        }
        if tooltip then draw_tooltip_bottom_left(tooltip, Vector2.{ x = mouse.pointer.x - input_rect.h / 2, y = input_rect.y + input_rect.h / 3 });

        // Draw search results
        if !is_empty(results) && mode == .dropdown {
            // Remember how many fits per page
            per_page = cast(s16) (results_rect.h / entry_height);
            if per_page <= 0 then per_page = 2;

            push_scissor(results_rect);
            defer pop_scissor();

            draw_rect(results_rect, Color.BACKGROUND_0, extra_draw_info = .{is_background = true});  // to make contrasting scopes more visible

            {
                // Scrollbar
                content_height := results.count * entry_height;
                max_y_scroll := max(cast(s32)(content_height - results_rect.h), 0);
                new_scroll_target := get_new_scroll_target_from_scrollbar(results_rect, content_height, scroll_y, scroll_anim.target, 0, max_y_scroll, search_scrollbar_id);
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
                    if mouse.scroll_y_delta != 0 {
                        target := clamp(scroll_anim.target - mouse.scroll_y_delta, 0, max_y_scroll);
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
                draw_scrollbar(results_rect, content_height, scroll_y, scroll_anim.target, 0, max_y_scroll, search_scrollbar_id);
            }

            visible_start := clamp(cast(s32) (scroll_y / entry_height), 0, results.count);
            visible_count := cast(s32) (results_rect.h / entry_height) + 2;
            visible_entries := to_view(results, visible_start, visible_count);

            // Pre-filter scope regions for easier checks later
            visible_scopes: [..] Buffer_Region;
            if !is_empty(buffer.regions) && visible_entries {
                start_offset := get_real_line_start_offset(buffer, visible_entries[0].line);
                end_offset   := get_real_line_end_offset  (buffer, visible_entries[visible_entries.count-1].line);
                for buffer.regions {
                    if it.end   <= start_offset continue;
                    if it.start >  end_offset   break;
                    if it.kind == .scope_export || it.kind == .scope_file || it.kind == .scope_module {
                        array_add(*visible_scopes, it);
                    }
                }
            }

            last_line_num := ifx !is_empty(results) then results[results.count-1].line + 1 else 1;
            line_num_col_width := char_x_advance * tprint("%", last_line_num).count;
            line_num_x := results_rect.x + margin;
            text_x     := line_num_x + line_num_col_width + 2 * char_x_advance;

            max_code_chars := cast(s32)((results_rect.x + results_rect.w - text_x) / char_x_advance) - 1;  // NOTE: counts tab as one char

            entry_rect := cut_top(results_rect, entry_height);
            filename_scissor := cut_left(results_rect, line_num_x - entry_rect.x - char_x_advance);
            if !is_valid(filename_scissor) then filename_scissor = entry_rect;

            for entry, i : visible_entries {
                entry_index := cast(s32) (visible_start + i);
                entry_rect.y = results_rect.y + results_rect.h - (entry_index + 1) * entry_height + scroll_y;

                // Highlight the entry into the scope color the match is in
                for visible_scopes {
                    if entry.offset >= it.start && entry.offset <= it.end {
                        scope_rect := cut_right(entry_rect, entry_rect.x + entry_rect.w - text_x + char_x_advance);
                        draw_rect(scope_rect, get_region_color(it.kind), extra_draw_info = .{is_background = true});
                        break;
                    }
                }

                if mouse_pointer_is_within(entry_rect) && is_hovering_over(results_id) {
                    if mouse.left.just_pressed {
                        selected_result = entry_index;
                        jump_to_search_result(editor, buffer);
                        close_search_bar(editor);
                        redraw_requested = true;
                        break;  // don't finish drawing entries because they are reset
                    }
                    draw_rect(entry_rect, Color.LIST_CURSOR_LITE, extra_draw_info = .{is_background = true});
                }
                if entry_index == selected_result then draw_rect(entry_rect, Color.LIST_CURSOR);

                pen := Vector2.{
                    entry_rect.x + margin + padding,
                    entry_rect.y + (entry_rect.h - font_ui.character_height) / 2 + 2 * dpi_scale,
                };
                width: float;

                line_range := get_real_line_range(buffer, entry.line);
                text_start := line_range.start + count_whitespace(buffer.bytes, line_range.start, line_range.end);

                // Line number
                width = xx Simp.prepare_text(font_ui_small, tprint("%", entry.line + 1));
                Simp.draw_prepared_text(font_ui_small, xx (line_num_x + line_num_col_width - width), xx pen.y, color = xx Color.UI_DIM);

                // Draw code line
                {
                    match_start := entry.offset;
                    match_end   := min(entry.offset + entry.count, line_range.end);  // if we have a multi-line match, we will still show only the first line
                    line_start  := ifx text_start <= match_start then text_start else line_range.start;
                    line_indent := get_visual_indent_in_spaces(cast(string) to_view(buffer.bytes, line_range.start, line_start), tab_size);
                    cols_until_match_start := num_cols_in_string(cast(string) to_view(buffer.bytes, line_start, match_start - line_start), tab_size);
                    cols_until_match_end   := num_cols_in_string(cast(string) to_view(buffer.bytes, line_start, match_end   - line_start), tab_size);

                    // Figure out whether we need to cut the line so that the match is visible
                    col_offset  := 0;
                    byte_offset := 0;
                    pad_cols := 2;
                    if cols_until_match_end > max_code_chars {
                        if (cols_until_match_end - cols_until_match_start) >= max_code_chars {
                            // The match won't fit on the screen anyway - stick it to the left
                            col_offset = xx max(0, cols_until_match_start - pad_cols);
                        } else {
                            // Stick the match to the right
                            col_offset = cols_until_match_end - xx (max_code_chars - pad_cols);
                        }
                    }
                    if col_offset > 0 {
                        line_str := cast(string) to_view(buffer.bytes, line_start, line_range.end);
                        byte_offset, col_offset = visual_col_to_byte_offset(line_str, col_offset, line_indent, tab_size);
                    }

                    pen.x = text_x;
                    if col_offset > 0 {
                        // Line was cut on the left, draw an ellipsis
                        Simp.draw_text(font_main, xx pen.x, xx pen.y, "…", color = xx Color.UI_DIM);
                        pen.x += char_x_advance;
                    }

                    // Draw highlight
                    highlight_rect := entry_rect;
                    highlight_rect.x = pen.x + char_x_advance * (cols_until_match_start - col_offset);
                    highlight_rect.w = char_x_advance * (cols_until_match_end - cols_until_match_start);
                    draw_rect(shrink_y(highlight_rect, padding), Color.SEARCH_RESULT_INACTIVE, extra_draw_info = .{is_background = true});

                    // Draw line
                    visible_offset_range = Offset_Range.{
                        start = line_start + xx byte_offset,
                        end   = min(line_range.end, line_start + xx byte_offset + 4 * max_code_chars),  // max 4 bytes per char
                    };
                    line_str := get_range_as_string(buffer, visible_offset_range);
                    if line_str.count > 0 {
                        tokens := to_view(buffer.tokens, visible_offset_range.start, line_str.count);
                        code_lines: [1] Simp.Code_Line;
                        code_lines[0] = .{ line = line_str, tab_spaces = 0, tokens = xx,force tokens };
                        draw_code(font_main, pen, code_lines, tab_size, is_colored = buffer.tokens.count > 0, start_col = line_indent + col_offset);
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

    // Draw status bar
    if has_status_bar {
        status_bar_bg_color := Color.BACKGROUND_4;
        draw_rect(status_bar_rect, status_bar_bg_color, extra_draw_info = .{is_background = true});
        if #complete buffer_settings.status_bar_position == {
            case .bottom; draw_top_shadow(status_bar_rect);
            case .top; draw_bottom_shadow(status_bar_rect);
        }
        draw_status_bar(editor, buffer, status_bar_rect, status_bar_bg_color, buffer_settings, text_offset, cursors_off_screen);
    }

    if should_show_pane_editors(pane) {
        draw_pane_editors(pane, main_area, status_bar_rect, text_offset);
    }
}

draw_pane_editors :: (pane: *Editor_Pane, main_area: Rect, status_bar_rect: Rect, text_offset: Vector2) {
    margin  := floor(8 * dpi_scale);
    padding := floor(4 * dpi_scale);

    using pane.editor_draw_info;

    // Calculate initial width when we draw for the first time
    if max_file_name_width < 0 || max_folder_name_width < 0 {
        max_file_name_width   = -1;
        max_folder_name_width = -1;

        for pane.editor_ids {
            editor, buffer := get_editor_and_buffer(it);

            _, pen := draw_file_info(buffer, 0, padding, Vector2.{}, flags = .file_name | .modified, dry_run = true);
            if max_file_name_width < pen.x then max_file_name_width = pen.x;

            _, pen = draw_file_info(buffer, 0, padding, Vector2.{}, flags = .folder, dry_run = true);
            if max_folder_name_width < pen.x then max_folder_name_width = pen.x;
        }
    }

    // Figure out the position and dimensions of the rect
    max_width  := 1.0 * main_area.w;
    max_height := 0.5 * main_area.h;
    real_width := max_file_name_width + max_folder_name_width + text_offset.x * 2 + margin * 2;
    real_width = min(real_width, max_width);
    entry_height := font_ui_line_height + padding * 2;
    max_entries := cast(int) (max_height / entry_height);
    num_visible_entries := min(pane.editor_ids.count, max_entries);

    // Align the first entry with the status bar file name
    entry_rect := cut_left(main_area, real_width);
    entry_rect  = cut_bottom(entry_rect, entry_height);
    pen := Vector2.{
        entry_rect.x + text_offset.x,
        status_bar_rect.y + (status_bar_rect.h - font_ui.character_height) / 2 + 2 * dpi_scale,
    };
    entry_rect.y = status_bar_rect.y + (status_bar_rect.h - entry_rect.h) / 2;
    if config.settings.status_bar_position == .bottom {
        entry_rect.y += (num_visible_entries - 1) * entry_height;
        pen.y        += (num_visible_entries - 1) * entry_height;
    }

    rect := entry_rect;
    rect.y -= entry_height * (num_visible_entries - 1);
    rect.h *= num_visible_entries;

    draw_rounded_rect_with_shadow(rect, Color.BACKGROUND_3, extra_draw_info = .{ is_background = true });

    push_scissor(rect);
    defer pop_scissor();

    // Recalculate averages as we draw
    new_max_file_name_width   := -1.0;
    new_max_folder_name_width := -1.0;

    // Scrolling
    // TODO: extract common scrolling code somewhere and reuse if possible
    {
        content_height := pane.editor_ids.count * entry_height;
        max_y_scroll   := max(cast(s32)(content_height - rect.h), 0);
        target := scroll_anim.target;
        selected_top    := pane.editor_index * entry_height - target;
        selected_bottom := selected_top + entry_height;
        bounds_top, bounds_bottom := 0.0, rect.h;
        if rect.h >= 2 * entry_height then bounds_top, bounds_bottom = floor(rect.h * 0.2), floor(rect.h * 0.8);
        if selected_top    < bounds_top    then target = cast(s32) (pane.editor_index * entry_height - bounds_top);
        if selected_bottom > bounds_bottom then target = cast(s32) ((pane.editor_index + 1) * entry_height - bounds_bottom);
        target = clamp(target, 0, max_y_scroll);
        if target != scroll_anim.target {
            start_animation(*scroll_anim, target);
            redraw_requested = true;
        }
    }

    scroll_y, anim_finished := get_animation_value(scroll_anim);
    if !anim_finished then redraw_requested = true;
    entry_rect.y += scroll_y;
    pen.y        += scroll_y;

    for pane.editor_ids {
        editor, buffer := get_editor_and_buffer(it);

        if it_index == pane.editor_index {
            // Draw list cursor
            top_corners    := Corner_Rounding.none;
            bottom_corners := Corner_Rounding.none;
            if it_index == 0 then top_corners = .in;
            if it_index == pane.editor_ids.count - 1 then bottom_corners = .in;
            draw_rounded_rect_with_corners(entry_rect, Color.LIST_CURSOR, tl = top_corners, tr = top_corners, br = bottom_corners, bl = bottom_corners);
        }

        _, pen_after := draw_file_info(buffer, 0, padding, pen, flags = .file_name | .modified);
        file_name_width := pen_after.x - pen.x;
        if new_max_file_name_width < file_name_width then new_max_file_name_width = file_name_width;

        folder_pen := pen;
        folder_pen.x += max_file_name_width + margin * 2;
        _, pen_after = draw_file_info(buffer, 0, padding, folder_pen, flags = .folder);
        new_folder_name_width := pen_after.x - folder_pen.x;
        if new_max_folder_name_width < new_folder_name_width then new_max_folder_name_width = new_folder_name_width;

        entry_rect.y -= entry_height;
        pen.y        -= entry_height;
    }

    if max_file_name_width   != new_max_file_name_width {
        max_file_name_width = new_max_file_name_width;
        redraw_requested = true;
    }
    if max_folder_name_width != new_max_folder_name_width {
        max_folder_name_width = new_max_folder_name_width;
        redraw_requested = true;
    }

}

draw_status_bar :: (using editor: Editor, buffer: Buffer, rect: Rect, status_bar_bg_color: Color, buffer_settings: *Settings, text_offset: Vector2, cursors_off_screen: int) {
    push_scissor(rect);
    defer pop_scissor();

    status_bar_rect := shrink_x(rect, text_offset.x);

    width   := 0.0;
    padding := floor(4 * dpi_scale);

    pen := Vector2.{
        status_bar_rect.x,
        status_bar_rect.y + (status_bar_rect.h - font_ui.character_height) / 2 + 2 * dpi_scale,
    };

    // Draw file name and path
    width, pen = draw_file_info(buffer, width, padding, pen, flags = .default | .crlf_warning | .config_warning);

    // Draw line, column numbers, and selection length
    {
        cut_rect := status_bar_rect;
        cut_rect.x = pen.x + padding;
        cut_rect.w = status_bar_rect.x + status_bar_rect.w - cut_rect.x;
        push_scissor(cut_rect);
        defer pop_scissor();

        pen_x := status_bar_rect.x + status_bar_rect.w;
        should_draw_separator := false;

        _maybe_draw_separator :: () #expand {
            if !should_draw_separator {
                should_draw_separator = true;
                return;
            }

            `pen_x -= 3 * padding;
            rect := cut_right(status_bar_rect, 1);
            rect.x = `pen_x;
            draw_rect(rect, Color.BACKGROUND_0);
            `pen_x -= 3 * padding;
        }

        // Draw line col
        if buffer_settings.status_bar_show_line_col {
            _maybe_draw_separator();

            line := offset_to_real_line(buffer, editor.cursors[main_cursor].pos);
            col  := 0;
            {
                // Do not count indented tabs here, only count each tab as one character.
                start, end := buffer.line_starts[line], editor.cursors[main_cursor].pos;
                s := cast(string) to_view(buffer.bytes, start, end - start);
                while s {
                    byte := s[0];
                    advance(*s, 1 + trailingBytesForUTF8[byte]);
                    col += 1;
                }
            }

            #if DEBUG {
                width = xx Simp.prepare_text(font_ui_bold, tprint("Offset: %  Line: %  Col: %", editor.cursors[main_cursor].pos, line + 1, col + 1));
            } else {
                width = xx Simp.prepare_text(font_ui_bold, tprint("Line: %  Col: %", line + 1, col + 1));
            }
            pen_x -= width;
            Simp.draw_prepared_text(font_ui_bold, xx pen_x, xx pen.y, color = xx Color.UI_DIM);
        }

        // Draw indentation type
        if buffer_settings.status_bar_show_indentation {
            _maybe_draw_separator();
            indentation_type, tab_size := get_buffer_indentation_and_tab_size(buffer);
            label := tprint("%: %", ifx indentation_type == .spaces then "Spaces" else "Tabs", tab_size);
            width = xx Simp.prepare_text(font_ui_bold, label);
            pen_x -= width;
            Simp.draw_prepared_text(font_ui_bold, xx pen_x, xx pen.y, color = xx Color.UI_DIM);
        }

        // Draw length of selected text if any text is currently selected
        if buffer_settings.status_bar_show_selected_text_length && num_selected_bytes > 0 {
            _maybe_draw_separator();
            label := tprint("Selected: % chars", num_selected_chars);
            if num_selected_bytes != num_selected_chars then label = tprint("Selected: % chars, % bytes", num_selected_chars, num_selected_bytes);
            width = xx Simp.prepare_text(font_ui_bold, label);
            pen_x -= width;
            Simp.draw_prepared_text(font_ui_bold, xx pen_x, xx pen.y, color = xx Color.UI_DIM);
        }

        _maybe_draw_separator();

        // Maybe draw the number of cursors off screen
        if editor.cursors.count > 1 && cursors_off_screen && buffer_settings.status_bar_show_cursors_off_screen {
            width = xx Simp.prepare_text(font_ui_bold, tprint("%", cursors_off_screen));
            cursor_indicator_x := pen_x - width - char_x_advance;
            Simp.draw_prepared_text(font_ui_bold, xx cursor_indicator_x, xx pen.y, color = xx Color.CURSOR);

            cursor_width := ifx buffer_settings.cursor_as_block then char_x_advance else 2 * dpi_scale;
            cursor_y := status_bar_rect.y + (status_bar_rect.h - line_height) / 2;
            cursor_rect := align_to_grid(make_rect(cursor_indicator_x - cursor_width - padding, cursor_y, cursor_width, line_height));

            if should_draw_cursors() then draw_rounded_rect(cursor_rect, Color.CURSOR, radius = rounding_radius_small, set_shader = true);

            hover_rect := Rect.{ cursor_rect.x - padding, status_bar_rect.y, cursor_rect.w + padding + width + 2 * padding, status_bar_rect.h };
            cursor_number_id := get_ui_id_from_loc();
            maybe_set_hot_or_active(cursor_number_id, hover_rect, .NORMAL);
            if is_hovering_over(cursor_number_id) {
                draw_tooltip_bottom_left(tprint("Cursors off screen: %", cursors_off_screen), top_right(cursor_rect));
            }
        }

        // Make sure the text is cut nicely (only if footer color is not translucent, otherwise it won't work)
        if map_color_to_vec4(status_bar_bg_color).w >= 1.0 {
            fadeout_rect := cut_rect;
            fadeout_rect.x -= 1; // Sliver sometimes visible on left if we don't do this
            fadeout_rect.w = 4 * padding;
            draw_rect(fadeout_rect, status_bar_bg_color, extra_draw_info = .{is_background = true, is_translucent_on_the_right = true});
        }
    }
}

File_Info_Draw_Flags :: enum_flags {
    none;
    file_name;
    modified;
    deleted_on_disk;
    modified_on_disk;
    read_only;
    error_when_saving;
    crlf_warning;
    config_warning;
    folder_separator;
    folder;
    default :: file_name | modified | deleted_on_disk | modified_on_disk | read_only | folder | folder_separator;
}

draw_file_info :: (buffer: Buffer, width: float, padding: float, _pen: Vector2, bold := true, dry_run := false, flags := File_Info_Draw_Flags.default) -> new_width: float, new_pen: Vector2 {
    file_name_color := Color.UI_DEFAULT;
    if buffer.modified then file_name_color = Color.UI_WARNING;

    pen := _pen;

    // Icon + file name
    if flags & .file_name {
        icon_char := convert_utf32_to_utf8(xx ifx buffer.has_file then buffer.file.icon else Icon.text);
        icon_width := Simp.prepare_text(font_icons, to_string(*icon_char));
        icon_x := pen.x - (icon_width - font_icons.em_width) / 2.0;
        if !dry_run then Simp.draw_prepared_text(font_icons, xx icon_x, xx pen.y, color = xx file_name_color);
        width += font_icons.em_width * 1.2;

        pen.x += width + padding;
        file_name_font := ifx bold then font_ui_bold else font_ui;
        width = xx Simp.prepare_text(file_name_font, get_buffer_name(buffer));
        if !dry_run then Simp.draw_prepared_text(file_name_font, xx pen.x, xx pen.y, color = xx file_name_color);
    }

    if buffer.modified && (flags & .modified) {
        pen.x += width + padding;
        width = xx Simp.prepare_text(font_icons_very_small, PEN_ICON);
        y_padding := (font_icons.character_height - font_icons_very_small.character_height) / 4.0;
        if !dry_run then Simp.draw_prepared_text(font_icons_very_small, xx pen.x, xx (pen.y + y_padding), color = xx file_name_color);
    }

    // Maybe warnings
    if buffer.deleted && !buffer.readonly && (flags & .deleted_on_disk) {
        pen.x += width + padding;
        width = xx Simp.prepare_text(font_ui_bold, "[deleted on disk]");
        if !dry_run then Simp.draw_prepared_text(font_ui_bold, xx pen.x, xx pen.y, color = xx Color.UI_ERROR_BRIGHT);
    } else if buffer.modified_on_disk  && (flags & .modified_on_disk) {
        pen.x += width + padding;
        width = xx Simp.prepare_text(font_ui_bold, "[modified on disk]");
        if !dry_run then Simp.draw_prepared_text(font_ui_bold, xx pen.x, xx pen.y, color = xx Color.UI_ERROR_BRIGHT);
    }
    if buffer.readonly && (flags & .read_only) {
        pen.x += width + padding;
        width = xx Simp.prepare_text(font_ui_bold, "[readonly]");
        if !dry_run then Simp.draw_prepared_text(font_ui_bold, xx pen.x, xx pen.y, color = xx Color.UI_WARNING);
    }
    if buffer.error_when_saving && (flags & .error_when_saving) {
        pen.x += width + padding;
        width = xx Simp.prepare_text(font_ui_bold, "[couldn't save file]");
        if !dry_run then Simp.draw_prepared_text(font_ui_bold, xx pen.x, xx pen.y, color = xx Color.UI_ERROR_BRIGHT);
    }

    if buffer.crlf && (flags & .crlf_warning) {
        pen.x += width + padding;
        width = xx Simp.prepare_text(font_ui, "[CRLF will be replaced with LF on save]");
        if !dry_run then Simp.draw_prepared_text(font_ui, xx pen.x, xx pen.y, color = xx Color.UI_WARNING);
    }

    if buffer.has_file && (flags & .config_warning) {
        label: string;
        if is_current_global_config(buffer.file.full_path) {
            label = "[current global config]";
        } else if is_current_project_config(buffer.file.full_path) {
            label = "[current project config]";
        } else if is_current_theme(buffer.file.full_path) {
            label = "[currently active theme]";
        }
        if label {
            pen.x += width + padding;
            width = xx Simp.prepare_text(font_ui, label);
            if !dry_run then Simp.draw_prepared_text(font_ui, xx pen.x, xx pen.y, color = xx Color.UI_WARNING);
        }
    }

    if buffer.has_file && (flags & .folder_separator) {
        // Draw separator
        pen.x += width + padding;
        width = xx Simp.prepare_text(font_ui_small, BULLET_ICON);
        if !dry_run then Simp.draw_prepared_text(font_ui_small, xx pen.x, xx pen.y, color = xx Color.UI_DIM);
    }

    if buffer.has_file && (flags & .folder) {
        // Draw file path
        pen.x += width + padding;
        width = xx Simp.prepare_text(font_ui_small, buffer.file.path);
        if !dry_run then Simp.draw_prepared_text(font_ui_small, xx pen.x, xx pen.y, color = xx Color.UI_DIM);
    }

    pen.x += width;

    return width, pen;
}

draw_splitter :: (splitter_rect: Rect, ui_id: Ui_Id, horizontal := true) {
    color := Color.SPLITTER;

    rect := splitter_rect;

    if horizontal {
        rect_fat := expand_x(rect, 2 * dpi_scale);
        maybe_set_hot_or_active(ui_id, rect_fat, .DRAGGING_HORIZONTAL);
    } else {
        rect_fat := expand_y(rect, 2 * dpi_scale);
        maybe_set_hot_or_active(ui_id, rect_fat, .DRAGGING_VERTICAL);
    }

    if is_hovering_over(ui_id) {
        color = Color.SPLITTER_HOVER;
        rect = ifx horizontal then expand_x(rect, 1) else expand_y(rect, 1);
    }

    // Don't draw splitters for vertical layouts unless hovering or dragging (because there's already a status bar)
    draw_rect(rect, color);
}

draw_open_file_dialog :: () {
    using open_file_dialog;

    ui_id := Ui_Id.open_file_dialog;
    scrollbar_id := get_ui_id_from_loc(parent_id = ui_id);

    if ui.active != .none && ui.active != ui_id && !is_child(ui.active, ui_id) {
        // Close the dialog on clicks elsewhere
        close_open_file_dialog(.CANCEL);
        return;
    }

    open_file_dialog_maybe_refresh_entries();

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
    draw_rounded_rect_with_shadow(box_rect, Color.BACKGROUND_3, radius = rounding_radius_large, extra_draw_info = .{is_background = true});

    maybe_set_hot_or_active(ui_id, box_rect, .NORMAL);

    // Draw the filter input
    input_rect, files_rect := cut_top(box_rect, input_rect_height);
    input_rect = shrink(input_rect, margin);
    input_id := get_ui_id_from_loc(parent_id = ui_id);

    if #complete mode == {
        case .search;
            label := ifx finder.initted then " Search files by name" else " Scanning the workspace. Please wait...";
            draw_text_input(*open_file_dialog.input, input_rect, ui_id = input_id, active = true, label = label);
            if !finder.initted then redraw_requested = true;  // draw the progress bar and update as soon as we're done

            scan_progress := get_workspace_scan_progress();
            if scan_progress < 1.0 {
                progress_bar_rect := shrink(input_rect, 1);
                progress_bar_rect.w *= scan_progress;
                draw_rect(progress_bar_rect, Color.LIST_CURSOR_LITE);
            }

        case .open_editors;
            label := " Switch to open file";
            draw_text_input(*open_file_dialog.input, input_rect, ui_id = input_id, active = true, label = label);

        case .navigate;     #through;
        case .move;         #through;
        case .save;
            label: string;
            if mode == {
                case .navigate;
                    label = ifx !path_chunks then " Navigate to file" else "";
                case .save;
                    label = tprint(" Choose where to save '%'", get_buffer_name(*open_buffers[buffer_id_to_save]));
                case .move;
                    label = " Move to";
            }

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
                color := Color.SELECTION_ACTIVE;
                if ui.hot_last_frame == input_id && mouse_pointer_is_within(dir_rect) {
                    color = Color.LIST_CURSOR;
                    set_pointer_image(.PRESSABLE);
                    if mouse.left.just_pressed {
                        if shift_pressed() {
                            // Shift + Click = Open dir in explorer
                            path_chunks_trimmed := array_view(path_chunks, 1, it_index);
                            dir_path: string = ---;
                            if path_chunks_trimmed.count == 0 dir_path = root_dir;
                            else dir_path = tprint("%/%", root_dir, join(..path_chunks_trimmed, separator = "/",, temp));
                            platform_open_in_explorer(dir_path);
                        } else {
                            // Regular Click = Trim chunks past this dir
                            open_file_dialog_truncate_path_chunks(it_index);
                            redraw_requested = true;
                        }
                    }
                }
                draw_rounded_rect(dir_rect, color);
                Simp.draw_prepared_text(font_ui, xx (dir_rect.x + padding + half_padding), xx text_y, color = xx Color.UI_DEFAULT);
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
            max_y_scroll := max(cast(s32)(content_height - files_rect.h), 0);
            new_scroll_target := get_new_scroll_target_from_scrollbar(files_rect, content_height, scroll_y, scroll_anim.target, 0, max_y_scroll, scrollbar_id);
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
                if mouse.scroll_y_delta != 0 {
                    target := clamp(scroll_anim.target - mouse.scroll_y_delta, 0, max_y_scroll);
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
            draw_scrollbar(files_rect, content_height, scroll_y, scroll_anim.target, 0, max_y_scroll, scrollbar_id);
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
                    if entries.selected_by_mouse == -1 then draw_rect(entry_rect, Color.LIST_CURSOR_LITE);
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
                if entries.selected_by_mouse == entry_index then draw_rect(entry_rect, Color.LIST_CURSOR);
                if entry_index == selected then draw_rect(entry_rect, Color.LIST_CURSOR);
            }

            // Maybe draw project boundary
            if mode == .search {
                if project_dir_id < 0 then project_dir_id = entry.project_dir_id;
                if entry.project_dir_id != project_dir_id {
                    project_dir_id = entry.project_dir_id;
                    separator := cut_top(entry_rect, 2 * dpi_scale);
                    separator.y += 1;
                    draw_rect(separator, Color.LIST_CURSOR_LITE);
                }
            }

            pen := Vector2.{
                entry_rect.x + margin + padding,
                entry_rect.y + (entry_rect.h - font_ui.character_height) / 2 + 2 * dpi_scale,
            };
            width: float;

            name_color := ifx entry.flags & .MODIFIED then Color.UI_WARNING else Color.UI_DEFAULT;

            // Draw file icon
            icon_char := convert_utf32_to_utf8(xx entry.icon);
            icon_width := Simp.prepare_text(font_icons, to_string(*icon_char));
            icon_x := pen.x - (icon_width - font_icons.em_width) / 2.0;
            Simp.draw_prepared_text(font_icons, xx icon_x, xx pen.y, color = xx name_color);

            // Draw name
            pen.x += xx font_icons.em_width + padding * 1.5;
            if entry.type != .save {
                width = xx Simp.draw_text_with_highlights(font_ui, xx pen.x, xx pen.y, entry.entry_name, entry.name_highlights, color = xx name_color, highlight_color = xx Color.LETTER_HIGHLIGHT);
            } else {
                width = xx Simp.draw_text(font_ui, xx pen.x, xx pen.y, entry.entry_name, color = xx name_color);
            }

            if entry.flags & .MODIFIED {
                pen.x += width + padding;
                width = xx Simp.prepare_text(font_icons_very_small, PEN_ICON);
                y_padding := (font_icons.character_height - font_icons_very_small.character_height) / 4.0;
                Simp.draw_prepared_text(font_icons_very_small, xx pen.x, xx (pen.y + y_padding), color = xx name_color);
            }

            if entry.flags & .MODIFIED_ON_DISK {
                pen.x += width + padding;
                width = xx Simp.draw_text(font_ui_bold, xx pen.x, xx pen.y, "[modified on disk]", color = xx Color.UI_ERROR_BRIGHT);
            }

            // // Draw score
            // pen.x += width + padding;
            // width = xx Simp.prepare_text(font_ui_small, tprint("%", formatInt(entry.sort_key, base=16)));
            // Simp.draw_prepared_text(font_ui_small, xx pen.x, xx pen.y, color = xx Color.UI_DIM);

            // Draw file path
            pen.x += width + padding;
            if pen.x < path_align_x then pen.x = path_align_x;
            width = xx Simp.draw_text_with_highlights(font_ui, xx pen.x, xx pen.y, entry.path, entry.path_highlights, color = xx Color.UI_DIM, highlight_color = xx Color.LETTER_HIGHLIGHT);
        }

        // Deselect any previously clicked entry
        if mouse.left.just_released || !mouse.left.is_down then entries.selected_by_mouse = -1;

        if scroll_y != 0 then draw_top_down_shadow(cut_top(files_rect, char_x_advance));
    }
}

draw_language_dialog :: () {
    draw_extra_entry_stuff :: (entry_ptr: *void, entry_rect: Rect, name_width: float, pen: Vector2, margin: float, padding: float) {
        entry := cast(*Language_Dialog.Entry) entry_ptr;

        if entry.active {
            active_text :: "Current selected language";
            active_rect := shrink_x(entry_rect, margin);

            active_rect.x += name_width;
            active_rect.w -= name_width + padding;

            active_text_width := cast(float) Simp.prepare_text(font_ui_small, active_text);

            if is_valid(active_rect) && active_text_width < active_rect.w {
                x := active_rect.x + active_rect.w - active_text_width;
                Simp.draw_prepared_text(font_ui_small, xx x, xx pen.y, color = xx Color.UI_DIM);
            }
        }
    }

    draw_generic_choice_dialog(*language_dialog, Ui_Id.language_dialog, " Choose language syntax", draw_extra_entry_stuff);
}

draw_commands_dialog :: () {

    draw_extra_entry_stuff :: (entry_ptr: *void, entry_rect: Rect, name_width: float, pen: Vector2, margin: float, padding: float) {
        entry := cast(*Commands_Dialog.Entry) entry_ptr;
        key_sequence: string;
        if entry.is_build_command {
            key_sequence = key_sequence_for_action_as_string(cast(Action_Build) entry.action);
        } else {
            key_sequence = key_sequence_for_action_as_string(cast(Action_Editors) entry.action);
        }
        if key_sequence {
            key_sequence_rect := shrink_x(entry_rect, margin);

            key_sequence_rect.x += name_width;
            key_sequence_rect.w -= name_width + padding;

            key_sequence_width := cast(float) Simp.prepare_text(font_ui_small, key_sequence);

            if is_valid(key_sequence_rect) && key_sequence_width < key_sequence_rect.w {
                x := key_sequence_rect.x + key_sequence_rect.w - key_sequence_width;
                Simp.draw_prepared_text(font_ui_small, xx x, xx pen.y, color = xx Color.UI_DIM);
            }
        }
    }

    draw_generic_choice_dialog(*commands_dialog, Ui_Id.commands_dialog, " Execute command", draw_extra_entry_stuff);
}

Draw_Entry_Extra_Fn :: #type (entry: *void, entry_rect: Rect, name_width: float, pen: Vector2, margin: float, padding: float);

draw_generic_choice_dialog :: (using dialog: *Generic_Choice_Dialog, ui_id: Ui_Id, input_label: string, draw_entry_extra: Draw_Entry_Extra_Fn = null) {
    scrollbar_id := get_ui_id_from_loc(parent_id = ui_id);

    if ui.active != .none && ui.active != ui_id && !is_child(ui.active, ui_id) {
        // Close the dialog on clicks elsewhere
        hide_dialog(dialog);
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
    draw_rounded_rect_with_shadow(box_rect, Color.BACKGROUND_3, radius = rounding_radius_large, extra_draw_info = .{is_background = true});

    maybe_set_hot_or_active(ui_id, box_rect, .NORMAL);

    // Draw the filter input
    input_rect, entries_rect := cut_top(box_rect, input_rect_height);
    input_rect = shrink(input_rect, margin);
    input_id := get_ui_id_from_loc(parent_id = ui_id);

    draw_text_input(*dialog.input, input_rect, ui_id = input_id, active = true, label = input_label);

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
            max_y_scroll := max(cast(s32)(content_height - entries_rect.h), 0);
            new_scroll_target := get_new_scroll_target_from_scrollbar(entries_rect, content_height, scroll_y, scroll_anim.target, 0, max_y_scroll, scrollbar_id);
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
                if mouse.scroll_y_delta != 0 {
                    target := clamp(scroll_anim.target - mouse.scroll_y_delta, 0, max_y_scroll);
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
            draw_scrollbar(entries_rect, content_height, scroll_y, scroll_anim.target, 0, max_y_scroll, scrollbar_id);
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
                if selected_by_mouse == -1 then draw_rect(entry_rect, Color.LIST_CURSOR_LITE);
                draw_rect(entry_rect, Color.LIST_CURSOR_LITE);

                if selected_by_mouse == entry_index && mouse.left.just_released {
                    selected = entry_index;
                    if ctrl_or_cmd_pressed() {
                        dialog.open_entry(.on_the_side);
                    } else {
                        dialog.open_entry(.in_place);
                    }
                    redraw_requested = true;
                    break;
                }
            }
            if selected_by_mouse == entry_index then draw_rect(entry_rect, Color.LIST_CURSOR);
            if entry_index == selected then draw_rect(entry_rect, Color.LIST_CURSOR);

            pen := Vector2.{
                entry_rect.x + margin + padding,
                entry_rect.y + (entry_rect.h - font_ui.character_height) / 2 + 2 * dpi_scale,
            };

            // Draw name
            width := Simp.draw_text_with_highlights(font_ui, xx pen.x, xx pen.y, entry.name, entry.highlights, color = xx Color.UI_DEFAULT, highlight_color = xx Color.LETTER_HIGHLIGHT);

            if draw_entry_extra then draw_entry_extra(*entry, entry_rect, xx width, pen, margin, padding);
        }

        if mouse.left.just_released || !mouse.left.is_down then selected_by_mouse = -1;

        if scroll_y != 0 then draw_top_down_shadow(cut_top(entries_rect, char_x_advance));
    }
}

draw_delete_file_dialog :: () {
    draw_extra_file_info :: (extra_rect: Rect, margin: float, padding: float) {
        buffer := *open_buffers[delete_file_dialog.buffer_id];

        push_scissor(extra_rect);
        defer pop_scissor();

        pen := Vector2.{
            x = extra_rect.x + margin,
            y = extra_rect.y + margin / 2 + (extra_rect.h - font_ui.character_height) / 2 + 2 * dpi_scale,
        };

        draw_file_info(buffer, 0, padding, pen);
    }

    draw_generic_confirm_dialog(
        *delete_file_dialog,
        get_ui_id_from_loc(),
        "Delete file?",
        "Please confirm you want to delete the following file:",
        draw_extra_file_info,
        extra_height = font_ui_medium_line_height,
    );
}

draw_switch_to_project_dialog :: () {
    draw_extra_entry_stuff :: (entry_ptr: *void, entry_rect: Rect, name_width: float, pen: Vector2, margin: float, padding: float) {
        entry := cast(*Switch_To_Project_Dialog.Entry) entry_ptr;
        if !entry.config_parent_dir return;

        width := Simp.prepare_text(font_ui_small, entry.config_parent_dir);
        x := entry_rect.x + entry_rect.w - width - margin;
        Simp.draw_text(font_ui_small, xx x, xx pen.y, entry.config_parent_dir, color = xx Color.UI_DIM);
    }

    label := ifx switch_to_project_dialog.filtered then " Select project to switch to" else tprint(" No projects found in %", projects_dir);
    draw_generic_choice_dialog(*switch_to_project_dialog, Ui_Id.switch_to_project_dialog, label, draw_extra_entry_stuff);
}

draw_theme_dialog :: () {
    label := ifx theme_dialog.filtered then " Choose theme" else tprint(" No themes found in %", themes_dir);
    draw_generic_choice_dialog(*theme_dialog, Ui_Id.theme_dialog, label);
}

draw_unsaved_buffers_dialog :: () {
    draw_extra_buffer_names :: (extra_rect: Rect, margin: float, padding: float) {
        push_scissor(extra_rect);
        defer pop_scissor();

        entry_height  := font_ui_line_height + padding * 2;
        entry_rect := cut_top(extra_rect, entry_height);

        for unsaved_buffers_dialog.buffer_ids {
            buffer := *open_buffers[it];
            {
                push_scissor(entry_rect);
                defer pop_scissor();

                pen := Vector2.{
                    x = entry_rect.x + margin,
                    y = entry_rect.y + (entry_rect.h - font_ui.character_height) / 2 + 2 * dpi_scale,
                };
                width: float;

                width, _ = draw_file_info(buffer, width, padding, pen);
            }
            entry_rect.y -= entry_rect.h + margin / 2;
        }
    }

    num_unsaved_buffers := unsaved_buffers_dialog.buffer_ids.count;
    header  := "Unsaved files. Continue?";
    message := "Please decide what to do with the following files:";
    if num_unsaved_buffers == 1 {
        header  = "Unsaved file. Continue?";
        message = "Please decide what to do with the following file:";
    }

    margin  := floor(12 * dpi_scale);

    draw_generic_confirm_dialog(
        *unsaved_buffers_dialog,
        get_ui_id_from_loc(),
        header,
        message,
        draw_extra_buffer_names,
        extra_height = font_ui_medium_line_height * num_unsaved_buffers + margin,
    );
}

Draw_Confirm_Dialog_Extra_Fn :: #type (extra_rect: Rect, margin: float, padding: float);

draw_generic_confirm_dialog :: (dialog: *Generic_Confirm_Dialog, ui_id: Ui_Id, header: string, message: string, draw_extra: Draw_Confirm_Dialog_Extra_Fn = null, extra_height := 0.0) {
    if ui.active != .none && ui.active != ui_id && !is_child(ui.active, ui_id) {
        // Close the dialog on clicks elsewhere
        close_dialog(dialog, .CANCEL);
        return;
    }

    margin  := floor(12 * dpi_scale);
    padding := floor( 4 * dpi_scale);
    entry_height  := font_ui_line_height + padding * 2;
    button_height := font_ui_medium_line_height + 2 * padding;
    header_height := font_ui_medium_line_height + 2 * margin + 4 * dpi_scale;

    box_rect := Rect.{
        w = floor(clamp(screen.w * 0.3, 600 * dpi_scale, 1500 * dpi_scale)),
        h = header_height + margin + padding + button_height + margin + (extra_height + margin),
    };
    if message then box_rect.h += entry_height + margin;
    box_rect.x = floor((screen.w - box_rect.w) / 2);
    box_rect.y = screen.h - box_rect.h - floor(clamp(100 * dpi_scale, 0, (screen.h - box_rect.h) / 2));

    maybe_set_hot_or_active(ui_id, box_rect, .NORMAL);

    draw_rounded_rect_with_shadow(box_rect, Color.BACKGROUND_3, extra_draw_info = .{is_background = true});

    header_rect, buffers_rect := cut_top(box_rect, header_height);
    buffers_rect = shrink(buffers_rect, margin);

    // Header
    {
        push_scissor(header_rect);
        defer pop_scissor();

        draw_rounded_rect_with_corners(header_rect, Color.BACKGROUND_4, tl = .in, tr = .in, br = .none, bl = .none, extra_draw_info = .{is_background = true});

        pen_x := cast(s32) (header_rect.x + 2 * margin);
        pen_y := cast(s32) (header_rect.y + (header_rect.h - font_ui_medium.character_height) / 2 + 2);
        Simp.draw_text(font_ui_medium, pen_x, pen_y, header, xx Color.UI_DEFAULT);

        hr := cut_bottom(header_rect, 1);
        draw_rect(hr, Color.BACKGROUND_1, extra_draw_info = .{is_background = true});
    }

    // Message + extra
    {
        push_scissor(buffers_rect);
        defer pop_scissor();

        entry_rect := cut_top(buffers_rect, entry_height);

        if message {
            Simp.draw_text(
                font_ui,
                xx (entry_rect.x + margin),
                xx (entry_rect.y + (entry_rect.h - font_ui.character_height) / 2 + 2 * dpi_scale),
                message,
                xx Color.UI_DEFAULT,
            );
            entry_rect.y -= entry_rect.h + margin;
        }

        if draw_extra != null then draw_extra(entry_rect, margin, padding);
    }

    // Buttons
    {
        buttons_row_rect := cut_bottom(buffers_rect, button_height);

        for < button : dialog.get_buttons() {
            button_id := cast(s64) get_ui_id_from_loc(parent_id = ui_id) + it_index;  // could theoretically clash with something right below so don't get any ui ids close to here!
            focused := dialog.focused_button_index == it_index;
            activated, width := draw_button(font_ui, button.label, button.color, button.text_color, ui_id, buttons_row_rect, .right, margin / 2, margin, button_id = cast(Ui_Id) button_id, outline = focused, outline_background_color = Color.BACKGROUND_3);
            if activated close_dialog(dialog, button.result);
            buttons_row_rect.w -= width + margin;
        }
    }
}

draw_confirm_overwrite_dialog :: () {
    draw_extra_file_info :: (extra_rect: Rect, margin: float, padding: float) {
        width := xx Simp.prepare_text(font_ui_bold, confirm_overwrite_dialog.path);
        Simp.draw_prepared_text(
            font_ui_bold,
            xx (extra_rect.x + margin),
            xx (extra_rect.y + (extra_rect.h + font_ui_bold.character_height) / 2 + 2 * dpi_scale),
            color = xx Color.UI_WARNING,
        );
    }

    draw_generic_confirm_dialog(
        *confirm_overwrite_dialog,
        get_ui_id_from_loc(),
        "Overwrite file?",
        "Please confirm that you want to overwrite the following file:",
        draw_extra_file_info,
        extra_height = font_ui_medium_line_height,
    );
}

draw_kill_running_command_dialog :: () {
    draw_extra_command_info :: (extra_rect: Rect, margin: float, padding: float) {
        width := xx Simp.prepare_text(font_ui_bold, build_get_running_command_name());
        Simp.draw_prepared_text(
            font_ui_bold,
            xx (extra_rect.x + margin),
            xx (extra_rect.y + (extra_rect.h + font_ui_bold.character_height) / 2 + 2 * dpi_scale),
            color = xx Color.UI_WARNING,
        );
    }

    draw_generic_confirm_dialog(
        *kill_running_command_dialog,
        get_ui_id_from_loc(),
        "Kill running command?",
        "The following command is currently running:",
        draw_extra_command_info,
        extra_height = font_ui_medium_line_height,
    );
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
    draw_rounded_rect_with_shadow(box_rect, Color.BACKGROUND_3, radius = rounding_radius_large, extra_draw_info = .{is_background = true});

    if results {
        template := "% results found";
        if result_limit_reached then template = "%+ results found";
        label := tprint(template, results.count);
        if results.count == 1 then label = "1 result found";
        draw_tooltip_top_left(label, top_right(box_rect));
    }

    maybe_set_hot_or_active(ui_id, box_rect, .NORMAL);

    // Draw the search inputs
    splitter1_rect, splitter2_rect, include_rect, exclude_rect: Rect;
    input_rect, files_rect := cut_top(box_rect, input_rect_height);
    input_rect = shrink(input_rect, margin);

    // Drag the search input splitters before drawing them
    splitter1_id := get_ui_id_from_loc(parent_id = ui_id);
    if ui.active == splitter1_id {
        splitter_pos := (mouse.pointer.x - input_rect.x) / input_rect.w;
        search_input_width = clamp(splitter_pos, 0.1, 0.99);
    }
    input_rect=, filters_rect := cut_left(input_rect, input_rect.w * search_input_width);

    splitter1_rect, filters_rect = cut_left(filters_rect, padding);
    maybe_set_hot_or_active(splitter1_id, splitter1_rect, .DRAGGING_HORIZONTAL);

    splitter2_id := get_ui_id_from_loc(parent_id = ui_id);
    if ui.active == splitter2_id {
        splitter_pos := (mouse.pointer.x - filters_rect.x) / filters_rect.w;
        include_input_width = clamp(splitter_pos, 0.1, 0.9);
    }

    include_rect, filters_rect = cut_left(filters_rect, (filters_rect.w - padding) * include_input_width);

    splitter2_rect, exclude_rect = cut_left(filters_rect, padding);
    maybe_set_hot_or_active(splitter2_id, splitter2_rect, .DRAGGING_HORIZONTAL);

    // Main search input
    input_id := get_ui_id_from_loc(parent_id = ui_id);
    {
        label := ifx initted then "Type to search in workspace" else "Scanning the workspace. Please wait...";
        color := ifx !regex_search || (regex_search && regex_is_valid) then Color.UI_DEFAULT else Color.UI_ERROR_BRIGHT;
        became_active := draw_text_input(*finder.input, input_rect, ui_id = input_id, active = (finder.active_input == .input), label = label, margin_right = input_rect.h * 3, color = color);
        if became_active then finder_activate_input(.input);

        button_width := input_rect.h;
        pressed, hover_match_case, hover_match_word, hover_regex_search := false, false, false, false;

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

        input_rect.w -= button_width - 4 * dpi_scale;

        pressed, hover_regex_search = draw_text_input_modifier_button(input_id, input_rect, button_width, regex_search, REGEX_SEARCH_ICON);
        if pressed {
            finder_toggle_regex_search();
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
        } else if hover_regex_search {
            tooltip = "Regex Search";
            combo := key_sequence_for_action_as_string(Action_Search_Dialog.toggle_regex_search);
            if combo then tooltip = tprint("% (%)", tooltip, combo);
        }
        if tooltip then draw_tooltip_bottom_left(tooltip, Vector2.{ x = mouse.pointer.x - input_rect.h / 2, y = input_rect.y + input_rect.h / 3 });

        scan_progress := get_workspace_scan_progress();
        if scan_progress < 1.0 {
            progress_bar_rect := shrink(input_rect, 1);
            progress_bar_rect.w *= scan_progress;;
            draw_rect(progress_bar_rect, Color.LIST_CURSOR_LITE);
        }
    }

    // Include files input
    {
        include_input_id := get_ui_id_from_loc(parent_id = ui_id);
        became_active := draw_text_input(*finder.include, include_rect, ui_id = include_input_id, active = (finder.active_input == .include), label = " Include files, e.g. *.cpp, *.txt");
        if became_active then finder_activate_input(.include);
    }

    // Exclude files input
    {
        exclude_input_id := get_ui_id_from_loc(parent_id = ui_id);
        became_active := draw_text_input(*finder.exclude, exclude_rect, ui_id = exclude_input_id, active = (finder.active_input == .exclude), label = " Exclude files, e.g. **/node_modules/**/*.js");
        if became_active then finder_activate_input(.exclude);
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

        if results then draw_rect(files_rect, Color.BACKGROUND_0);  // to make contrasting scopes more visible

        // Scrollbar
        content_height := results.count * entry_height;
        max_y_scroll := max(cast(s32)(content_height - files_rect.h), 0);
        new_scroll_target := get_new_scroll_target_from_scrollbar(files_rect, content_height, scroll_y, scroll_anim.target, 0, max_y_scroll, scrollbar_id);
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
            if mouse.scroll_y_delta != 0 {
                target := clamp(scroll_anim.target - mouse.scroll_y_delta, 0, max_y_scroll);
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

            buffer := *open_buffers[entry.buffer_id];
            tab_size := get_buffer_tab_size(buffer);

            // Highlight the entry into the scope color the match is in
            for buffer.regions {
                if entry.match_offset >= it.start && entry.match_offset <= it.end && (it.kind == .scope_export || it.kind == .scope_file || it.kind == .scope_module) {
                    scope_rect := cut_right(entry_rect, entry_rect.x + entry_rect.w - text_x + char_x_advance);
                    draw_rect(scope_rect, get_region_color(it.kind));
                    break;
                }
            }

            if mouse_pointer_is_within(entry_rect) && is_hovering_over(ui_id) {
                if mouse.left.just_pressed then selected_by_mouse = entry_index;
                if selected_by_mouse == -1 then draw_rect(entry_rect, Color.LIST_CURSOR_LITE);
                placement := ifx ctrl_or_cmd_pressed() then Editor_Placement.on_the_side else .in_place;
                if selected_by_mouse == entry_index && mouse.left.just_released {
                    finder_open_selected_result(placement, entry_index);
                    redraw_requested = true;
                    break;  // don't finish drawing entries because we're opening selected result
                }
            }
            if selected_by_mouse == entry_index then draw_rect(entry_rect, Color.LIST_CURSOR);
            if entry_index == selected then draw_rect(entry_rect, Color.LIST_CURSOR);

            pen := Vector2.{
                entry_rect.x + margin + padding,
                entry_rect.y + (entry_rect.h - font_ui.character_height) / 2 + 2 * dpi_scale,
            };
            width: float;

            // Not sure if it's cheaper to do this for the visible results only, but every frame,
            // or do it once when searching, but for every resuls (and bloat the search result size).
            // Chose the first option at least for now.
            line_num := offset_to_real_line(buffer, min(entry.match_offset, xx buffer.bytes.count));
            line_range := get_real_line_range(buffer, line_num);
            text_start := line_range.start + count_whitespace(buffer.bytes, line_range.start, line_range.end);

            // Draw file info
            {
                push_scissor(filename_scissor);
                defer pop_scissor();

                width, pen = draw_file_info(buffer, width, padding, pen, bold = false);
            }

            // Line number
            width = xx Simp.prepare_text(font_ui_small, tprint("%", line_num + 1));
            Simp.draw_prepared_text(font_ui_small, xx (line_num_x + line_num_col_width - width), xx pen.y, color = xx Color.UI_DIM);

            // Draw code line
            {
                match_start := entry.match_offset;
                match_end   := min(entry.match_offset + entry.match_count, line_range.end);  // if we have a multi-line match, we will still show only the first line
                line_start  := ifx text_start <= match_start then text_start else line_range.start;
                line_indent := get_visual_indent_in_spaces(cast(string) to_view(buffer.bytes, line_range.start, line_start), tab_size);
                cols_until_match_start := num_cols_in_string(cast(string) to_view(buffer.bytes, line_start, match_start - line_start), tab_size);
                cols_until_match_end   := num_cols_in_string(cast(string) to_view(buffer.bytes, line_start, match_end   - line_start), tab_size);

                // Figure out whether we need to cut the line so that the match is visible
                col_offset  := 0;
                byte_offset := 0;
                pad_cols := 2;
                if cols_until_match_end > max_code_chars {
                    if (cols_until_match_end - cols_until_match_start) >= max_code_chars {
                        // The match won't fit on the screen anyway - stick it to the left
                        col_offset = xx max(0, cols_until_match_start - pad_cols);
                    } else {
                        // Stick the match to the right
                        col_offset = cols_until_match_end - xx (max_code_chars - pad_cols);
                    }
                }
                if col_offset > 0 {
                    line_str := cast(string) to_view(buffer.bytes, line_start, line_range.end);
                    byte_offset, col_offset = visual_col_to_byte_offset(line_str, col_offset, line_indent, tab_size);
                }

                pen.x = text_x;
                if col_offset > 0 {
                    // Line was cut on the left, draw an ellipsis
                    Simp.draw_text(font_main, xx pen.x, xx pen.y, "…", color = xx Color.UI_DIM);
                    pen.x += char_x_advance;
                }
                if buffer_needs_tokenizing(buffer) then retokenize(buffer);  // right before drawing

                // Draw highlight
                highlight_rect := entry_rect;
                highlight_rect.x = pen.x + char_x_advance * (cols_until_match_start - col_offset);
                highlight_rect.w = char_x_advance * (cols_until_match_end - cols_until_match_start);
                draw_rect(shrink_y(highlight_rect, padding), Color.SEARCH_RESULT_INACTIVE);

                // Draw line
                visible_range := Offset_Range.{
                    start = line_start + xx byte_offset,
                    end   = min(line_range.end, line_start + xx byte_offset + 4 * max_code_chars),  // max 4 bytes per char
                };
                line_str := get_range_as_string(buffer, visible_range);
                if line_str.count > 0 {
                    tokens := to_view(buffer.tokens, visible_range.start, line_str.count);
                    code_lines: [1] Simp.Code_Line;
                    code_lines[0] = .{ line = line_str, tab_spaces = 0, tokens = xx,force tokens };
                    draw_code(font_main, pen, code_lines, tab_size, is_colored = buffer.tokens.count > 0, start_col = line_indent + col_offset);
                }
            }
        }

        // Drawing the scrollbar here so that scopes don't cover it
        draw_scrollbar(files_rect, content_height, scroll_y, scroll_anim.target, 0, max_y_scroll, scrollbar_id);

        if !is_empty(finder.input.text) && !results {
            label := "Searching…";
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
                if regex_search {
                    combo := key_sequence_for_action_as_string(Action_Search_Dialog.toggle_regex_search);
                    label = tprint("%   Regex search is active (% to toggle).", label, combo);
                }
                if !is_empty(finder.include.text) {
                    wildcards := take_first_n_chars(to_string(finder.include.text), 20, tab_size = 4);
                    if wildcards.count != finder.include.text.count then wildcards = tprint("%…", wildcards);
                    label = tprint("%  Only files matching \"%\" were searched.", label, wildcards);
                }
                if !is_empty(finder.exclude.text) {
                    wildcards := take_first_n_chars(to_string(finder.exclude.text), 20, tab_size = 4);
                    if wildcards.count != finder.exclude.text.count then wildcards = tprint("%…", wildcards);
                    label = tprint("%  Files matching \"%\" were excluded.", label, wildcards);
                }
            }
            entry_rect := cut_top(files_rect, entry_height);
            pen := Vector2.{
                entry_rect.x + margin + padding,
                entry_rect.y + (entry_rect.h - font_ui.character_height) / 2 + 2 * dpi_scale,
            };
            Simp.draw_text(font_ui_small, xx pen.x, xx pen.y, label, xx Color.UI_DIM);
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

    _, buffer := get_active_editor_and_buffer();
    if buffer && get_settings(buffer).status_bar_position == .top then bar_rect.y -= status_bar_height;

    maybe_set_hot_or_active(input_id, bar_rect, .NORMAL);

    input_rect := shrink(bar_rect, margin);
    input_rect = cut_right(input_rect, input_rect.w - (label_width + margin));

    draw_rounded_rect_with_shadow(bar_rect, Color.BACKGROUND_3, extra_draw_info = .{is_background = true});

    pen := Vector2.{
        x = bar_rect.x + margin,
        y = bar_rect.y + (bar_rect.h - cast(s32)font_ui.character_height) / 2 + 2,  // sigh
    };
    Simp.draw_prepared_text(font_ui, xx pen.x, xx pen.y, color = xx Color.UI_DEFAULT);

    color := ifx go_to_line_dialog.input_is_valid then Color.UI_DEFAULT else Color.UI_ERROR;
    draw_text_input(*go_to_line_dialog.input, input_rect, ui_id = input_id, active = true, label = " line number", color = color);
}

get_cursor_screen_pos :: (text_origin: Vector2, coords: Coords) -> Vector2 {
    return .{
        text_origin.x + coords.col * char_x_advance,
        text_origin.y - coords.line * line_height,
    };
}

draw_range :: (range: Coords_Range, editor: Editor, buffer: Buffer, visible_start: s32, visible_end: s32, text_origin: Vector2, color: Color, alpha := 1.0) {
    tab_size := get_buffer_tab_size(buffer);

    // Scan the visible range and add the number of chars on each line
    range_chars: [..] s32;
    range_chars.allocator = temp;
    // array_reserve(*range_chars, visible_end - visible_start + 1);

    start := max(range.start.line, visible_start);
    end   := min(range.end.line,   visible_end);

    for start..end {
        s := get_line_as_string(editor, buffer, xx it);
        array_add(*range_chars, num_cols_in_string(s, tab_size));  // we need to refer to prev/next line, so storing it in an array
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
        draw_rounded_rect_with_corners(rect, color, tl, tr, br, bl, alpha = alpha, extra_draw_info = .{is_background = true});
    }
}

draw_range_full_width_lines :: (range: Coords_Range, editor_rect: Rect, visible_start: s32, visible_end: s32, text_origin: Vector2, color: Color) {
    start := max(range.start.line, visible_start);
    end   := min(range.end.line,   visible_end);

    full_width_rect := Rect.{ editor_rect.x, text_origin.y - start * line_height, editor_rect.w, line_height };
    text_gap_x := text_origin.x - editor_rect.x;

    if start == end {
        if range.start.col == range.end.col  return;
        rect := Rect.{
            editor_rect.x,
            text_origin.y - start * line_height,
            text_gap_x + range.end.col * char_x_advance,
            line_height,
        };
        if range.start.col != 0  rect = cut_right(rect, (range.end.col - range.start.col) * char_x_advance);
        draw_rounded_rect_with_corners(rect, color, .in, .in, .in, .in, extra_draw_info = .{is_background = true});
        return;
    }

    for line_num : start..end {
        rect := Rect.{
            editor_rect.x,
            text_origin.y - line_num * line_height,
            editor_rect.w,
            line_height,
        };

        tl, tr, bl, br: Corner_Rounding = .none;

        if line_num == start {
            if range.start.col > 0 {
                tl = .in;
                rect = cut_right(rect, rect.w - (text_gap_x + range.start.col * char_x_advance));
            }
        }
        if line_num == end {
            if range.end.col > 0 {
                br = .in;
                rect = cut_left(rect, text_gap_x + range.end.col * char_x_advance);
            } else {
                rect.w = 0;
            }
        }
        draw_rounded_rect_with_corners(rect, color, tl, tr, br, bl, extra_draw_info = .{is_background = true});
    }
}

draw_text_input :: (using input: *Text_Input, rect_: Rect, ui_id: Ui_Id, active := false, label: string = "", font: *Simp.Dynamic_Font = null, color := Color.UI_DEFAULT, margin_left := 1.0, margin_right := 1.0) -> became_active := false {
    if !is_valid(rect_) return;

    rect := align_to_grid(rect_);  // to get a consistent outline

    became_active := maybe_set_hot_or_active(ui_id, rect, .TEXT_SELECT);
    if became_active { active = true; redraw_requested = true; }  // draw as activated right away and schedule a redraw to deactivate other things

    if font == null then font = font_ui;
    padding := (rect.h - cast(float) font.default_line_spacing) / 2;

    draw_rect(rect, ifx active then Color.CURSOR_INACTIVE else Color.BACKGROUND_1);
    input_rect := shrink(rect, 1);
    draw_rect(input_rect, Color.BACKGROUND_0);

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
            if !shift_pressed() && text_input_selection_by_mouse != ui_id then cursor.sel = cursor.pos;
        }
        if mouse.left.just_pressed then text_input_selection_by_mouse = ui_id;
        if mouse.left.just_double_clicked then select_word(input);
        if mouse.left.just_triple_clicked then select_all(input);
    }
    if mouse.left.just_released || !mouse.left.is_down then text_input_selection_by_mouse = .none;

    // @Speed: we currently don't limit the text size, so if it's too big we'll do a lot of work here every frame
    cursor_pos_x     := Simp.get_text_width(font, slice(input_text, 0, cursor.pos));
    total_text_width := Simp.get_text_width(font, input_text);

    scroll_x_target := scroll_anim.target;
    if cursor_pos_x - scroll_x_target >= cast(s32) input_rect.w then scroll_x_target = cast(s32) cursor_pos_x - cast(s32) input_rect.w;
    if cursor_pos_x < scroll_x_target then scroll_x_target = xx cursor_pos_x;
    if total_text_width - scroll_x_target < cast(s32) input_rect.w then {
        scroll_x_target = max(cast(s32) total_text_width - cast(s32) input_rect.w, 0);  // always show as much text as possible
    }
    if scroll_x_target != scroll_anim.target then start_animation(*scroll_anim, scroll_x, scroll_x_target);

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
        draw_rect(selection_rect, ifx active then Color.SELECTION_ACTIVE else Color.SELECTION_INACTIVE);
    }

    y := input_rect.y + (input_rect.h - font.character_height) / 2 + 2 * dpi_scale;  // I don't know why we need this extra + 2, but without it the text doesn't look in the right place

    if !input_text then Simp.draw_text(font, xx x, xx y, label, color = xx Color.TEXT_INPUT_LABEL);
    if active then draw_rect(cursor_rect, ifx active then Color.CURSOR else Color.CURSOR_INACTIVE);
    Simp.draw_text(font, xx x, xx y, input_text, color = xx color);

    return became_active;
}

draw_text_input_modifier_button :: (input_id: Ui_Id, input_rect: Rect, width: float, enabled: bool, icon: string, loc := #caller_location) -> pressed: bool, hover: bool {
    ui_id := get_ui_id_from_loc(loc, parent_id = input_id);

    btn := cut_right(input_rect, width);
    btn = shrink(btn, 2 * dpi_scale);
    btn = align_to_grid(btn);

    maybe_set_hot_or_active(ui_id, btn, .PRESSABLE);

    hover := is_hovering_over(ui_id);
    bg_color := ifx hover then Color.BACKGROUND_4 else Color.BACKGROUND_3;

    if hover then draw_rounded_rect(shrink(btn, 1), bg_color);

    if enabled {
        draw_rounded_rect(shrink(btn, 1), Color.CURSOR_INACTIVE);
        draw_rounded_rect(shrink(btn, 2), bg_color);
    }

    text_w := cast(float) Simp.prepare_text(font_icons_small, icon);
    text_h := font_icons_small.character_height;
    text_x := btn.x + btn.w / 2 - text_w / 2 + 1;
    text_y := btn.y + btn.h / 2 - text_h / 2 + 1;
    text_color := ifx enabled then Color.UI_DEFAULT else Color.UI_DIM;

    Simp.draw_prepared_text(font_icons_small, xx text_x, xx text_y, xx text_color);

    return hover && mouse.left.just_pressed, hover;
}


draw_icon_button :: (ui_id: Ui_Id, rect: Rect, icon: string, style : enum { none; rounded; square; } = .rounded, loc := #caller_location) -> pressed: bool, hover: bool {
    btn := align_to_grid(rect);

    maybe_set_hot_or_active(ui_id, btn, .PRESSABLE);

    hover := is_hovering_over(ui_id);
    bg_color := ifx hover then Color.BACKGROUND_4 else Color.BACKGROUND_3;

    if style == {
        case .rounded;
            if hover then draw_rounded_rect(shrink(btn, 1), bg_color);
            draw_rounded_rect(shrink(btn, 1), Color.CURSOR_INACTIVE);
            draw_rounded_rect(shrink(btn, 2), bg_color);

        case .square;
            if hover then draw_rect(shrink(btn, 1), bg_color);
            draw_rect(shrink(btn, 1), Color.CURSOR_INACTIVE);
            draw_rect(shrink(btn, 2), bg_color);
    }

    text_w := cast(float) Simp.prepare_text(font_icons_small, icon);
    text_h := font_icons_small.character_height;
    text_x := btn.x + btn.w / 2 - text_w / 2 + 1;
    text_y := btn.y + btn.h / 2 - text_h / 2 + 1;
    text_color := ifx hover then Color.UI_DEFAULT else Color.UI_DIM;

    Simp.draw_prepared_text(font_icons_small, xx text_x, xx text_y, xx text_color);

    return hover && mouse.left.just_pressed, hover;
}

draw_tooltip_top_left :: (text: string, pos: Vector2) {
    padding := 4 * dpi_scale;

    width := cast(float) Simp.prepare_text(font_ui_very_small, text);
    rect := Rect.{ x = pos.x, y = pos.y };
    rect.w = width + 2 * padding;
    rect.x -= rect.w;
    rect.h = 2 * padding + font_ui_very_small.character_height;

    draw_rounded_rect_with_shadow(rect, Color.BACKGROUND_3, extra_draw_info = .{is_background = true});
    Simp.draw_prepared_text(font_ui_very_small, xx (rect.x + padding), xx (rect.y + (rect.h - font_ui_very_small.character_height) / 2) + 1, xx Color.UI_DEFAULT);
}

draw_tooltip_bottom_left :: (text: string, pos: Vector2) {
    padding := 4 * dpi_scale;

    width := cast(float) Simp.prepare_text(font_ui_very_small, text);
    rect := Rect.{ x = pos.x, y = pos.y };
    rect.w = width + 2 * padding;
    rect.x -= rect.w;
    rect.h = 2 * padding + font_ui_very_small.character_height;
    rect.y -= rect.h;

    draw_rounded_rect_with_shadow(rect, Color.BACKGROUND_3, extra_draw_info = .{is_background = true});
    Simp.draw_prepared_text(font_ui_very_small, xx (rect.x + padding), xx (rect.y + (rect.h - font_ui_very_small.character_height) / 2) + 1, xx Color.UI_DEFAULT);
}

draw_code :: (font: *Simp.Dynamic_Font, pen: Vector2, code_lines: [] Simp.Code_Line, tab_size: s32, selections: [] Offset_Range = .[], start_col := 0, is_colored := true) {
    // Use different code paths for colored and uncolored texts to avoid checking if color is present for each letter
    if is_colored {
        Simp.draw_code(font, xx pen.x, xx pen.y, char_x_advance, line_height, code_lines, xx,force selections, tab_size, start_col, is_colored = true);
    } else {
        Simp.draw_code(font, xx pen.x, xx pen.y, char_x_advance, line_height, code_lines, xx,force selections, tab_size, start_col, is_colored = false);
    }
}


Corner_Rounding :: enum { none; in; out; }

draw_rounded_rect :: (rect: Rect, color: Color, radius := 0.0, softness := 1.0, opacity := 1.0, $set_shader := true, $extra_draw_info := Simp.Extra_Draw_Info.{}) {
    if !is_valid(rect) return;
    #if set_shader then Simp.set_shader_for_rects(extra_draw_info);
    if radius <= 0 then radius = rounding_radius;

    center := Vector2.{ x = rect.x + rect.w / 2, y = rect.y + rect.h / 2 };
    size   := Vector2.{ x = rect.w / 2, y = rect.h / 2 };
    p0 := bottom_left(rect);
    p2 := top_right(rect);

    color_vec4 := map_color_to_vec4(color);
    color_vec4.w *= opacity;

    Simp.immediate_rounded_rect(p0, p2, color_vec4, center, size, radius, softness);
}

draw_rounded_rect_with_raw_color :: (rect: Rect, color_vec4: Vector4, radius := 0.0, softness := 1.0, $set_shader := true) {
    if !is_valid(rect) return;
    #if set_shader then Simp.set_shader_for_rects();
    if radius <= 0 then radius = rounding_radius;

    center := Vector2.{ x = rect.x + rect.w / 2, y = rect.y + rect.h / 2 };
    size   := Vector2.{ x = rect.w / 2, y = rect.h / 2 };
    p0 := bottom_left(rect);
    p2 := top_right(rect);

    Simp.immediate_rounded_rect(p0, p2, color_vec4, center, size, radius, softness);
}

draw_rounded_rect_with_corners :: (rect: Rect, color: Color,
                                   tl: Corner_Rounding = .in, tr: Corner_Rounding = .in,
                                   br: Corner_Rounding = .in, bl: Corner_Rounding = .in,
                                   radius := 0.0, softness := 1.0, alpha := 1.0,
                                   $extra_draw_info := Simp.Extra_Draw_Info.{}) {
    if radius <= 0 then radius = rounding_radius;

    center := Vector2.{ x = rect.x + rect.w / 2, y = rect.y + rect.h / 2 };
    size   := Vector2.{ x = rect.w / 2, y = rect.h / 2 };

    top, bottom, base, corner: Rect = ---;
    top,    base = cut_top(rect, radius);
    bottom, base = cut_bottom(base, radius);

    color_vec4 := map_color_to_vec4(color);
    color_vec4.w *= alpha;

    Simp.set_shader_for_rects(extra_draw_info);

    // Draw top corners
    if tl == {
        case .in;
            corner, top = cut_left(top, radius);
            if is_valid(corner) Simp.immediate_rounded_rect(bottom_left(corner), top_right(corner), color_vec4, center, size, radius, softness);
        case .out;
            corner = top; corner.w = radius; corner.x -= radius;
            fake_center := center - Vector2.{ x = rect.w - 1, y = -1 };
            if is_valid(corner) Simp.immediate_rounded_rect(bottom_left(corner), top_right(corner), color_vec4, fake_center, size, radius, -softness);
    }
    if tr == {
        case .in;
            corner, top = cut_right(top, radius);
            if is_valid(corner) Simp.immediate_rounded_rect(bottom_left(corner), top_right(corner), color_vec4, center, size, radius, softness);
        case .out;
            corner = top; corner.w = radius; corner.x += top.w;
            fake_center := center + Vector2.{ x = rect.w - 1, y = 1 };
            if is_valid(corner) Simp.immediate_rounded_rect(bottom_left(corner), top_right(corner), color_vec4, fake_center, size, radius, -softness);
    }

    // Draw bottom corners
    if bl == {
        case .in;
            corner, bottom = cut_left(bottom, radius);
            if is_valid(corner) Simp.immediate_rounded_rect(bottom_left(corner), top_right(corner), color_vec4, center, size, radius, softness);
        case .out;
            corner = bottom; corner.w = radius; corner.x -= radius;
            fake_center := center - Vector2.{ x = rect.w - 1, y = 1 };
            if is_valid(corner) Simp.immediate_rounded_rect(bottom_left(corner), top_right(corner), color_vec4, fake_center, size, radius, -softness);
    }
    if br == {
        case .in;
            corner, bottom = cut_right(bottom, radius);
            if is_valid(corner) Simp.immediate_rounded_rect(bottom_left(corner), top_right(corner), color_vec4, center, size, radius, softness);
        case .out;
            corner = bottom; corner.w = radius; corner.x += bottom.w;
            fake_center := center + Vector2.{ x = rect.w - 1, y = -1 };
            if is_valid(corner) Simp.immediate_rounded_rect(bottom_left(corner), top_right(corner), color_vec4, fake_center, size, radius, -softness);
    }

    Simp.set_shader_for_color(enable_blend = true, extra_draw_info = extra_draw_info);
    draw_rect_with_raw_color(base, color_vec4);
    draw_rect_with_raw_color(top, color_vec4);
    draw_rect_with_raw_color(bottom, color_vec4);
}

draw_rounded_rect_with_shadow :: (rect: Rect, color: Color, radius := 0.0, shadow_size := 0.0, $extra_draw_info := Simp.Extra_Draw_Info.{}) {
    if radius <= 0 then radius = rounding_radius;
    if shadow_size <= 0 then shadow_size = char_x_advance * 2;
    shadow_rect := expand(rect, shadow_size);
    shadow_radius := radius + shadow_size;

    top, bottom, left, right, base: Rect = ---;
    top,    base = cut_top(shadow_rect, shadow_radius);
    bottom, base = cut_bottom(base, shadow_radius);
    left,   base = cut_left(base, shadow_radius);
    right,  base = cut_right(base, shadow_radius);

    shadow_color  := map_color_to_vec4(Color.SHADOW_DARK);
    center := Vector2.{ x = rect.x + rect.w / 2, y = rect.y + rect.h / 2 };
    size   := Vector2.{ x = rect.w / 2, y = rect.h / 2 };

    Simp.set_shader_for_rects(extra_draw_info);

    Simp.immediate_rounded_rect(bottom_left(top),    top_right(top),    shadow_color, center, size, radius, softness = shadow_size);
    Simp.immediate_rounded_rect(bottom_left(bottom), top_right(bottom), shadow_color, center, size, radius, softness = shadow_size);
    Simp.immediate_rounded_rect(bottom_left(left),   top_right(left),   shadow_color, center, size, radius, softness = shadow_size);
    Simp.immediate_rounded_rect(bottom_left(right),  top_right(right),  shadow_color, center, size, radius, softness = shadow_size);

    draw_rounded_rect(rect, color, radius = radius, set_shader = false, extra_draw_info = .{is_background = true});
}

draw_circle :: (center: Vector2, color: Color, radius: float, softness := 1.0) {
    if radius <= 0 then radius = rounding_radius;

    rect := Rect.{ x = center.x - radius, y = center.y - radius, w = radius * 2, h = radius * 2 };

    p0 := bottom_left(rect);
    p2 := top_right(rect);

    Simp.immediate_rounded_rect(p0, p2, map_color_to_vec4(color), center, .{}, radius, softness);
}

draw_top_down_shadow :: (rect: Rect) {
    t := Color.SHADOW_TRANSPARENT;
    s := Color.SHADOW_DARK;
    Simp.set_shader_for_color(enable_blend = true);
    draw_rect_raw(rect, c00 = t, c10 = t, c01 = s, c11 = s);
}

draw_rect :: (rect: Rect, color: Color, opacity := 1.0, $extra_draw_info := Simp.Extra_Draw_Info.{}) {
    Simp.set_shader_for_color(enable_blend = true);

    color_vec4 := map_color_to_vec4(color);
    color_vec4.w *= opacity;

    if extra_draw_info.is_translucent_on_the_right {
        trans := color_vec4;
        trans.w = 0;
        using rect;
        Simp.immediate_quad(x, y, x + w, y + h, color_vec4, color_vec4, trans, trans);
    } else {
        draw_rect_with_raw_color(rect, color_vec4);
    }
}

draw_rect_raw :: inline (using rect: Rect, color: Color) {
    Simp.immediate_quad(x, y, x + w, y + h, map_color_to_vec4(color));
}

draw_rect_with_raw_color :: inline (using rect: Rect, color_vec4: Vector4) {
    Simp.immediate_quad(x, y, x + w, y + h, color_vec4);
}

draw_rect_raw :: inline (using rect: Rect, c00: Color, c01: Color, c10: Color, c11: Color) {
    Simp.immediate_quad(x, y, x + w, y + h, map_color_to_vec4(c00), map_color_to_vec4(c01), map_color_to_vec4(c10), map_color_to_vec4(c11));
}

draw_gradient_rect :: (rect: Rect, mode: Gradient_Mode, value: float, color_vec4 := Vector4.{1, 1, 1, 1}) {
    Simp.set_shader_for_gradient(cast,force(Vector4) rect, xx mode, value);
    draw_rect_with_raw_color(rect, color_vec4);
    Simp.immediate_flush();
}

draw_top_shadow :: (using rect: Rect, size: float = 10.0) {
    Simp.set_shader_for_color(enable_blend = true);
    s := map_color_to_vec4(Color.SHADOW_DARK);
    t := map_color_to_vec4(Color.SHADOW_TRANSPARENT);
    Simp.immediate_quad(x, y + h, x + w, y + h + size * dpi_scale, c00 = s, c01 = t, c10 = s, c11 = t);
}

draw_bottom_shadow :: (using rect: Rect, size: float = 10.0) {
    Simp.set_shader_for_color(enable_blend = true);
    s := map_color_to_vec4(Color.SHADOW_DARK);
    t := map_color_to_vec4(Color.SHADOW_TRANSPARENT);
    Simp.immediate_quad(x, y, x + w, y - size * dpi_scale, c00 = s, c01 = t, c10 = s, c11 = t);
}

get_new_scroll_target_from_scrollbar :: (main_rect: Rect, content_height: float, scroll: s32, scroll_target: s32, min_scroll: s32, max_scroll: s32, ui_id: Ui_Id) -> new_scroll_target: s32 {
    return draw_scrollbar(main_rect, content_height, scroll, scroll_target, min_scroll, max_scroll, ui_id, draw = false);
}

draw_scrollbar :: (main_rect: Rect, content_height: float, scroll: s32, scroll_target: s32, min_scroll: s32, max_scroll: s32, ui_id: Ui_Id, for_build_panel := false, $draw := true) -> new_scroll_target: s32 {
    scroll_target = clamp(scroll_target, min_scroll, max_scroll);

    if scroll != scroll_target then start_scrollbar_fade_out_animation(ui_id);

    if max_scroll <= min_scroll return scroll_target;

    area := cut_right(main_rect, scrollbar_width);  // the scrollbar area of the main rect
    scrollbar := area;  // handle
    scrollbar.h = floor(area.h * (area.h / content_height));
    scroll_zone_size := area.h - scrollbar.h;  // the room for y to move

    if scroll_zone_size <= 0 return scroll_target;  // don't draw

    // Get the opacity from the fadeout animations
    fadeout_opacity := 0.0;
    for * scrollbar_fade_out_animations {
        if it.ui_id != ui_id continue;
        delayed := maybe_wait_for_delay(*it.anim);
        value, finished := get_animation_value(it.anim);
        if finished remove it;
        fadeout_opacity = value;
        if fadeout_opacity > 0 && !delayed then redraw_requested = true;  // only redraw when not delayed to avoid spinning while waiting
        fadeout_opacity = clamp(fadeout_opacity, config.settings.scrollbar_min_opacity, config.settings.scrollbar_max_opacity);
    }

    // Get another opacity value based on distance to mouse pointer
    distance_to_mouse_x := max(abs(mouse.pointer.x - (area.x + area.w / 2)) - area.w / 2, 0.0);
    distance_to_mouse_y := max(abs(mouse.pointer.y - (area.y + area.h / 2)) - area.h / 2, 0.0);
    distance_to_mouse := max(distance_to_mouse_x, distance_to_mouse_y);
    fade_in_threshold := char_size * config.settings.scrollbar_fade_in_sensitivity;
    t := clamp((fade_in_threshold - distance_to_mouse) / fade_in_threshold, 0.0, 1.0);
    opacity := lerp(config.settings.scrollbar_min_opacity, config.settings.scrollbar_max_opacity, t);
    opacity = max(opacity, fadeout_opacity);

    maybe_set_hot_or_active(ui_id, area, .NORMAL);

    if ui.active == ui_id then opacity = config.settings.scrollbar_max_opacity;  // we're actively dragging

    color       := Color.SCROLLBAR;
    color_bg    := Color.SCROLLBAR_BACKGROUND;
    color_hover := Color.SCROLLBAR_HOVER;

    // This is not very nice, but we're just going to do it like this for now and move on
    if for_build_panel {
        color       = Color.BUILD_PANEL_SCROLLBAR;
        color_bg    = Color.BUILD_PANEL_SCROLLBAR_BACKGROUND;
        color_hover = Color.BUILD_PANEL_SCROLLBAR_HOVER;
    }

    // Draw
    #if draw draw_rounded_rect(area, color_bg, radius = rounding_radius_small, opacity = opacity);
    color = color_hover;
    separator_rect := shrink_y(cut_left(area, 1), rounding_radius_small);
    #if draw draw_rect(separator_rect, color_bg, opacity = opacity);
    scrollbar.y += (cast(float) (max_scroll - scroll) / (max_scroll - min_scroll)) * scroll_zone_size;
    scrollbar.y = floor(scrollbar.y);
    scrollbar = shrink(scrollbar, 1);
    if scrollbar.h < 5 then scrollbar.h = 5;  // don't make it too tiny
    #if draw draw_rounded_rect(scrollbar, color, radius = rounding_radius_small, opacity = opacity);

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
        scroll_target = cast(s32) ((max_scroll - min_scroll) * new_scroll_percentage);
        start_scrollbar_fade_out_animation(ui_id, initial_value = opacity);
    }

    return clamp(scroll_target, min_scroll, max_scroll);
}

draw_button :: (font: *Simp.Dynamic_Font, label: string, color: Color, text_color: Color, parent_id: Ui_Id, row_rect: Rect, align: Button_Alignment = .right, padding_v: float, padding_h: float, shadow_size := 0.0, button_id := Ui_Id.none, outline := false, outline_color := Color.UI_DEFAULT, outline_background_color := Color.BACKGROUND_0, loc := #caller_location) -> pressed: bool, width: float {
    label_width := cast(float) Simp.prepare_text(font, label);

    button := row_rect;
    button.w = label_width + 2 * padding_h;
    button.h = cast(float) font.character_height + 2 * padding_v;
    if align == .right then button.x = row_rect.x + row_rect.w - button.w;

    button_ui_id := ifx button_id != Ui_Id.none then button_id else get_ui_id_from_loc(loc, parent_id = parent_id);

    maybe_set_hot_or_active(button_ui_id, button, .PRESSABLE);

    rect_color := map_color_to_vec4(color);
    if is_hovering_over(button_ui_id) then rect_color.w = 0.7; else rect_color.w = 0.6;  // yes it's bad and we know that. We'll fix it at some point
    if ui.active == button_ui_id {
        button.y -= 1;
        rect_color.w = 0.6;
    }

    if shadow_size > 0.0 then draw_rounded_rect_with_shadow(button, Color.BACKGROUND_0, shadow_size = shadow_size);
    if outline {
        outline_rect := expand(button, 4);
        draw_rounded_rect(outline_rect, outline_color);
        inside_outline_rect := expand(button, 3);
        draw_rounded_rect(inside_outline_rect, outline_background_color);
    }
    draw_rounded_rect_with_raw_color(button, rect_color);

    pen := Vector2.{ x = button.x + padding_h, y = button.y + (button.h - font.character_height) / 2 + 3 * dpi_scale };
    Simp.draw_prepared_text(font, xx pen.x, xx pen.y, xx text_color);

    return ui.active_last_frame == button_ui_id && mouse_pointer_is_within(button) && mouse.left.just_released, button.w;
}

Button_Alignment :: enum {
    left;
    right;
}

#scope_file

get_region_color :: (kind: Buffer_Region.Kind) -> Color {
    color := Color.BACKGROUND_0;
    if #complete kind == {
        case .none;             // nothing
        case .heredoc;          color = Color.REGION_HEREDOC;
        case .scope_export;     color = Color.REGION_SCOPE_EXPORT;
        case .scope_file;       color = Color.REGION_SCOPE_FILE;
        case .scope_module;     color = Color.REGION_SCOPE_MODULE;
        case .header;           color = Color.REGION_HEADER;
        case .success;          color = Color.REGION_SUCCESS;
        case .warning;          color = Color.REGION_WARNING;
        case .error;            color = Color.REGION_ERROR;
    }
    return color;
}

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

get_ui_id_for_pane :: inline (root_pane_id: Ui_Id, unique_pane_id: int) -> Ui_Id {
    assert(unique_pane_id < NUM_LINES_OF_CODE);
    return cast(Ui_Id) (unique_pane_id + NUM_LINES_OF_CODE * cast(s64) root_pane_id);
}

is_child :: (ui_id: Ui_Id, parent_id: Ui_Id) -> bool {
    // A ui id is considered a child if it was obtained by the get_ui_id_from_loc function above
    num := cast(s64) ui_id;
    parent_min := cast(s64) parent_id * NUM_LINES_OF_CODE;
    parent_max := parent_min + NUM_LINES_OF_CODE - 1;
    return parent_min <= num && num <= parent_max;
}

maybe_set_hot_or_active :: (ui_id: Ui_Id, rect: Rect, pointer_image: Pointer_Image, mouse_buttons: enum_flags { left; middle; right; } = .left|.middle|.right) -> became_active: bool {
    if !is_valid(rect) || !mouse_pointer_is_within(rect) return false;

    just_clicked := (mouse_buttons & .left   && mouse.left.just_pressed)  ||
                    (mouse_buttons & .right  && mouse.right.just_pressed) ||
                    (mouse_buttons & .middle && mouse.middle.just_pressed);

    ui.hot = ui_id;
    if ui.hot_last_frame == ui_id && ui.active == .none || ui.active == ui_id then set_pointer_image(pointer_image);
    if ui.hot_last_frame == ui_id && ui.active == .none && just_clicked {
        ui.active = ui_id;
        return true;
    }

    return false;
}

is_hovering_over :: (ui_id: Ui_Id) -> bool {
    return (ui.hot_last_frame == ui_id && ui.active == .none) || ui.active == ui_id;
}

start_scrollbar_fade_out_animation :: (ui_id: Ui_Id, initial_value := -1.0) {
    if initial_value < 0 then initial_value = config.settings.scrollbar_max_opacity;

    animation: *Scrollbar_Fade_Out_Animation;
    for * scrollbar_fade_out_animations {
        if it.ui_id == ui_id { animation = it; break; }
    }
    if !animation {
        animation = array_add(*scrollbar_fade_out_animations);
        animation.ui_id = ui_id;
    }
    start_animation(*animation.anim, initial_value, 0.0, delay = config.settings.scrollbar_fade_out_delay_seconds);
}


#scope_export

Icon :: enum u16 {
    // File types
    file_unknown :: 0xf15b;
    text         :: 0xf15c;
    jai          :: 0xf574;
    cpp          :: 0xf1c9;
    cs           :: 0xf1c9;
    todo         :: 0xf46d;
    git          :: 0xf387;
    image        :: 0xf1c5;
    audio        :: 0xf1c7;
    font         :: 0xf031;
    key          :: 0xf084;
    gear         :: 0xf013;
    folder       :: 0xe185;
    drive        :: 0xf0a0;
    js           :: 0xf15c;
    shell        :: 0xf2d0;

    save         :: 0xf019;
    dots         :: 0xf141;
    xmark        :: 0xf00d;

    debug        :: 0xf7d9;
}

PANE_SPLITTER_WIDTH :: 2;


#scope_file

ui: struct {
    active: Ui_Id = .none;
    hot:    Ui_Id = .none;
    hot_last_frame: Ui_Id = .none;
    active_last_frame: Ui_Id = .none;
}

Ui_Id :: enum s64 {
    none                        :: -1;
    unavailable                 :: -2;

    editor_single               :: -3;
    editor_left                 :: -4;
    editor_right                :: -5;
    editor_splitter             :: -6;
    open_file_dialog            :: -7;
    finder                      :: -8;
    splash_screen               :: -9;
    unsaved_buffers             :: -10;
    commands_dialog             :: -11;
    switch_to_project_dialog    :: -12;
    build_panel_title_bar       :: -15;
    color_preview_title_bar     :: -16;
    theme_dialog                :: -17;
    language_dialog             :: -18;
    color_picker_dialog         :: -19;

    // The rest will be derived from loc
}

// NOTE: this is a silly global variable which represents the distance between
// the center of slider and the point where we grabbed it.
// Since we can only drag one slider at a time, this will work, but in a more
// clean way this should probably be stored in widget storage?
// Problem is, we don't have much else to store for scrollbars...
scrollbar_grab_point: float;

// Super simple, we don't expect there to be more than a couple elements at any one time
scrollbar_fade_out_animations: [..] Scrollbar_Fade_Out_Animation;

Scrollbar_Fade_Out_Animation :: struct {
    ui_id: Ui_Id;
    anim := #run Tween_Animation(float).{ duration = 0.5, func = .smoothstep };
}

// Same as the scrollbar grab point above
panel_grab_point: Vector2;

// What to select when dragging
selection_mode: Selection_Mode;

// To indicate that we're dragging the mouse to select text in a text input
// A global variable because we can only do that to one text input at a time
text_input_selection_by_mouse: Ui_Id = .none;

// Used for creating cursors while dragging middle mouse button
editor_initial_middle_mouse_coords: Coords;

// Useful to know in order to handle select-by-drag and select-word with the new cursor
new_cursor_just_created_using_mouse := false;
last_cursor_created_using_mouse_at: Apollo_Time;

scissor_stack: [..] Rect;

GOLDEN_RATIO :: 1.6180339;

// Please keep at the bottom - needed for the parent-child relationships of ui elements
NUM_LINES_OF_CODE :: #run #location().line_number;
