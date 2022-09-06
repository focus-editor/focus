editors_handle_keypress :: (key_code: Input.Key_Code, mods: Mods) {
    editor, buffer := get_active_editor_and_buffer();
    if !editor return;

    cursors := editor.cursors;
    single_cursor := ifx has_single_cursor(editor) then *cursors[0] else null;

    cursor_moved   := true;
    keep_selection := false;

    if key_code == {
        case .ARROW_LEFT;
            if only_alt_pressed(mods) {
                move_viewport(editor, .left);
                cursor_moved = false;
            } else if only_ctrl_alt_pressed(mods) {
                switch_to_pane(.left);
                cursor_moved = false;
            } else {
                for *cursor : cursors { move_cursor_left(cursor, buffer, mods); }
            }
        case .ARROW_RIGHT;
            if only_alt_pressed(mods) {
                move_viewport(editor, .right);
                cursor_moved = false;
            } else if only_ctrl_alt_pressed(mods) {
                switch_to_pane(.right);
                cursor_moved = false;
            } else {
                for *cursor : cursors { move_cursor_right(cursor, buffer, mods); }
            }
        case .ARROW_UP;
            if only_alt_pressed(mods) {
                move_viewport(editor, .up);
                cursor_moved = false;
            } else if only_alt_shift_pressed(mods) {
                if single_cursor then move_lines_up(single_cursor, buffer);
                keep_selection = true;
            } else {
                for *cursor : cursors { move_cursor_up(cursor, buffer, mods); }
            }
        case .ARROW_DOWN;
            if only_alt_pressed(mods) {
                move_viewport(editor, .down);
                cursor_moved = false;
            } else if only_alt_shift_pressed(mods) {
                if single_cursor then move_lines_down(single_cursor, buffer);
                keep_selection = true;
            } else {
                for *cursor : cursors { move_cursor_down(cursor, buffer, mods); }
            }
        case .HOME;       for *cursor : cursors { move_cursor_home(cursor, buffer, mods); }
        case .END;        for *cursor : cursors { move_cursor_end (cursor, buffer, mods); }
        case .ENTER;      for *cursor : cursors { handle_enter(cursor, buffer, mods); }
        case .BACKSPACE;  for *cursor : cursors { handle_backspace(cursor, buffer, mods); }
        case .DELETE;     for *cursor : cursors { handle_delete(cursor, buffer, mods); }
        case .PAGE_UP;    for *cursor : cursors { move_cursor_page(cursor, buffer, mods, .up); }
        case .PAGE_DOWN;  for *cursor : cursors { move_cursor_page(cursor, buffer, mods, .down); }
        case .ESCAPE;
            cursor := leave_only_main_cursor(editor);
            remove_selection(cursor);
            cursor_moved = false;
        case .TAB;
            assert(false, "tab not implemented for multiple cursors yet");
            // keep_selection = handle_tab(cursor, buffer, mods);

        case #char "D";
            if only_ctrl_shift_pressed(mods) {
                assert(single_cursor != null);
                duplicate_lines(single_cursor, buffer);
                keep_selection = true;
            } else if only_ctrl_pressed(mods) {
                if single_cursor && !has_selection(single_cursor) {
                    select_word(single_cursor, buffer);
                } else {
                    maybe_create_additional_cursor(editor, buffer);
                }
                cursor_moved = true;
                keep_selection = true;
            }

        case #char "C";
            if only_alt_pressed(mods) {
                center_cursor_on_viewport(editor, buffer);
            } else if only_ctrl_pressed(mods) {
                assert(single_cursor != null);
                if has_selection(single_cursor) {
                    copy_selection_to_clipboard(single_cursor, buffer);
                }
                cursor_moved = false;
            }

        case #char "X";
            if only_ctrl_pressed(mods) {
                assert(single_cursor != null);
                copy_selection_to_clipboard(single_cursor, buffer, cut = true);
            }

        case #char "V";
            if only_ctrl_pressed(mods) && single_cursor {
                range := paste_from_clipboard(single_cursor, buffer);
                add_paste_animation(editor, range);
            }

        case #char "A";
            if only_ctrl_pressed(mods) {
                cursor := leave_only_main_cursor(editor);
                select_all(cursor, buffer);
                keep_selection = true;
                cursor_moved   = false;  // we don't want to move viewport
            }

        case #char "L";
            if only_ctrl_pressed(mods) {
                for *cursor : cursors { select_lines(cursor, buffer); }
                keep_selection = true;
            }

        case #char "/";
            if only_ctrl_pressed(mods) {
                if buffer.lang == .Jai {
                    for *cursor : cursors { comment_block(cursor, buffer); }
                }
                keep_selection = true;
            }

        case; cursor_moved = false;
    }

    if !mods.shift_pressed && cursor_moved && !keep_selection {
        for *cursor : cursors { remove_selection(cursor); }
    }

    if buffer.dirty {
        recalculate_lines(buffer);
        for *cursor : cursors { put_cursor_in_valid_spot(cursor, buffer); }
    }
    if !has_single_cursor(editor) then organise_cursors(editor);  // sort and maybe merge overlapping cursors

    editor.cursor_moved = cursor_moved;
}

editors_handle_text_input :: (char: u32) {
    if char == 127 return;  // there seems to be a bug in the Input module
                            // which generates a TEXT_INPUT event for DEL
                            // when Ctrl+Backspace is pressed

    editor, buffer := get_active_editor_and_buffer();
    if !editor return;
    if buffer.dirty then recalculate_lines(buffer);
    using editor;
    assert(cursors.count == 1, "Multiple cursors in editors_handle_text_input");
    cursor := *cursors[0];

    utf8_char := convert_utf32_to_utf8(char);
    str := to_string(*utf8_char);
    if has_selection(cursor) {
        selection := get_selection(cursor);
        buffer_replace_range(buffer, selection, str);
        cursor.pos = selection.start;
    } else {
        buffer_insert_string_at_pos(buffer, cursor.pos, str);
    }
    cursor.pos.col += 1;  // we know it's just one symbol
    cursor.col_wanted = cursor.pos.col;
    remove_selection(cursor);
    cursor_moved = true;
}

get_active_editor_and_buffer :: () -> *Editor, *Buffer {
    if editors_layout == .None return null, null;
    editor := *open_editors[editor_active];
    buffer := *open_buffers[editor.buffer_id];
    return editor, buffer;
}

editors_open_file :: (path: string, where: enum { in_place; left; right; } = .in_place) {
    buffer_id := find_or_create_buffer(path);
    if #complete editors_layout == {
        case .None;
            editor_active = find_or_create_editor(buffer_id);
            editors_layout = .Single;
        case .Single;
            if #complete where == {
                case .in_place;
                    editor_active  = find_or_create_editor(buffer_id);
                    editors_layout = .Single;
                case .left;
                    editor_left    = find_or_create_editor(buffer_id, editor_active);
                    editor_right   = editor_active;
                    editor_active  = editor_left;
                    editors_layout = .Double;
                case .right;
                    editor_right   = find_or_create_editor(buffer_id, editor_active);
                    editor_left    = editor_active;
                    editor_active  = editor_right;
                    editors_layout = .Double;
            }
        case .Double;
            unimplemented();
    }
}

move_viewport :: (editor: *Editor, dir: enum { left; up; right; down; }) {
    using editor.viewport;
    if dir == {
        case .left; #through;
        case .right;
            horiz_delta := cast(s32) (10 * char_size);
            new_target := ifx dir == .left then scroll_x.target - horiz_delta else scroll_x.target + horiz_delta;
            set_scroll_target(*scroll_x, left, new_target, xx (1000 * char_size)); // TODO

        case .up; #through;
        case .down;
            vert_delta := cast(s32) (10 * line_height);
            new_target := ifx dir == .up then scroll_y.target - vert_delta else scroll_y.target + vert_delta;
            buffer := open_buffers[editor.buffer_id];
            max_y_scroll := get_max_y_scroll(buffer);
            set_scroll_target(*scroll_y, top, new_target, max_y_scroll);
    }
}

center_cursor_on_viewport :: (editor: *Editor, buffer: Buffer) {
    cursor := leave_only_main_cursor(editor);
    // We assume that editors always take up most of the screen vertically.
    // If that ever changes we'll need to change this code (and do it when we know the layout)
    cursor_px_pos := editor.viewport.top +  window_height / 2;
    cursor.pos.line = xx (cursor_px_pos / line_height);
    cursor.pos.col = 0;
    cursor.pos = make_valid_pos(buffer, cursor.pos);
    remove_selection(cursor);
}

leave_only_main_cursor :: (using editor: *Editor) -> *Cursor {
    // Remove all cursors except the main one
    cursor := cursors[main_cursor];
    cursors.count = 1;
    main_cursor = 0;
    cursors[main_cursor] = cursor;
    return *cursors[main_cursor];
}

has_single_cursor :: inline (editor: *Editor) -> bool {
    return editor.cursors.count == 1;
}

organise_cursors :: (using editor: *Editor) {
    compare_cursors :: (c1: Cursor, c2: Cursor) -> s64 {
        s1 := get_selection(c1);
        s2 := get_selection(c2);
        if s1.start < s2.start return -1;
        if s2.start < s1.start return  1;
        return 0;
    }

    maybe_subsume :: (c1: *Cursor, c2: Cursor) -> bool {
        s1 := get_selection(c1);
        s2 := get_selection(c2);
        if s1.end < s2.start || s2.end < s1.start return false;  // cursors are disjoint

        new_start := ifx s1.start < s2.start then s1.start else s2.start;  // for some reason min() didn't work
        new_end   := ifx s1.end   < s2.end   then s2.end   else s1.end;    // max()

        if c1.pos == s1.end || c2.pos == s2.end {
            c1.sel = new_start;
            c1.pos = new_end;
        } else {
            c1.pos = new_start;
            c1.sel = new_end;
        }

        return true;
    }

    main_cursor_pos := cursors[main_cursor].pos;

    quick_sort(cursors, compare_cursors);

    // Adjust main cursor index because it could've moved
    for cursor, i : cursors {
        if cursor.pos == main_cursor_pos {
            main_cursor = i;
            break;
        }
    }

    // Merge overlapping cursors
    i := 0;
    while (i < cursors.count - 1) {
        cursor := *cursors[i];
        if maybe_subsume(cursor, cursors[i+1]) {
            array_ordered_remove_by_index(*cursors, i+1);
            if main_cursor > i then main_cursor -= 1;
        } else {
            i += 1;
        }
    }
}

editor_mouse_scroll :: (editor: *Editor, delta_z: int, max_y_scroll: s32) {
    if delta_z == 0 return;

    // Vertical scroll
    // Y-up, so a positive value of viewport.top means we've scrolled down
    WHEEL_SENSITIVITY :: 1.0;
    scroll_delta := cast(s32) (cast(float) delta_z * WHEEL_SENSITIVITY);
    using editor.viewport;
    set_scroll_target(*scroll_y, top, scroll_y.target - scroll_delta, max_y_scroll);
}

animate_scrolling :: (editor: *Editor) -> scrolling: bool {
    using editor.viewport;
    scrolling := false;

    // Vertical scroll
    if top != scroll_y.target {
        scrolling = true;
        using scroll_y;
        t := (frame_time - started_at) / Scroll_Animation.SPEED;
        if t >= 1 || t < 0 {
            top = target;
        } else {
            top = start + xx (cast(float)(target - start) * t);
        }
    }

    // Horizontal scroll
    if left != scroll_x.target {
        scrolling = true;
        using scroll_x;
        t := (frame_time - started_at) / Scroll_Animation.SPEED;
        if t >= 1 || t < 0 {
            left = target;
        } else {
            left = start + xx (cast(float)(target - start) * t);
        }
    }

    return scrolling;
}

get_max_y_scroll :: (buffer: Buffer) -> s32 {
    assert(!buffer.dirty);
    return max(cast(s32) ((buffer.lines.count - 2)  * line_height), 0);
}

set_scroll_target :: (using scroll: *Scroll_Animation, current: s32, target_: s32, max_scroll: s32) {
    start = current;
    target = clamp(target_, 0, max_scroll);
    started_at = frame_time;
}

add_paste_animation :: (using editor: *Editor, range: Range) {
    anim := array_add(*paste_animations);
    anim.range = range;
    anim.started_at = frame_time;
}

#scope_file

maybe_create_additional_cursor :: (using editor: *Editor, buffer: Buffer) {
    selected_text := get_selected_text_all_cursors(editor, buffer);
    if selected_text.count == 0 return;
    buffer_str := to_string(buffer.bytes);

    // Search from the main cursor downwards, possibly with a wraparound
    start_offset := pos_to_offset(buffer, get_selection(cursors[main_cursor]).end);
    found_offset := -1;
    if main_cursor == cursors.count - 1 {
        // Main cursor is last - search with a wraparound
        end_offset  := pos_to_offset(buffer, get_selection(cursors[0]).start);
        before_wrap := slice(buffer_str, start_offset, buffer_str.count - start_offset);
        after_wrap  := slice(buffer_str, 0, end_offset);

        index := find_index_from_left(before_wrap, selected_text);
        if index >= 0 then found_offset = start_offset + index;
        if found_offset < 0 then found_offset = find_index_from_left(after_wrap, selected_text);
    } else {
        // Main cursor is not last - search until the next cursor only
        end_offset := pos_to_offset(buffer, get_selection(cursors[main_cursor+1]).start);
        target_range := slice(buffer_str, start_offset, end_offset - start_offset);
        index := find_index_from_left(target_range, selected_text);
        if index >= 0 then found_offset = start_offset + index;
    }
    if found_offset < 0 return;  // found no matches

    new_cursor := array_add(*cursors);
    new_cursor.sel = offset_to_pos(buffer, found_offset);
    new_cursor.pos = offset_to_pos(buffer, found_offset + selected_text.count);
    main_cursor = cursors.count - 1;
}

get_selected_text_all_cursors :: (using editor: Editor, buffer: Buffer) -> string {
    // Returns a selected string only if all cursors have the same text selected.
    // Otherwise returns an empty string.
    empty: string;

    text := get_selected_string(cursors[main_cursor], buffer);
    if text.count == 0 return empty;

    for cursor : cursors {
        if text != get_selected_string(cursor, buffer) return empty;
    }

    return text;
}

switch_to_pane :: (side: enum { left; right; }) {
    if editors_layout != .Double return;
    editor_active = ifx side == .left then editor_left else editor_right;
}

find_or_create_editor :: (buffer_id: s64, existing_editor: s64 = -1) -> editor_id: s64 {
    assert(buffer_id >= 0 && buffer_id < open_buffers.count, "Attempt to create editor for nonexistent buffer");
    for open_editors {
        if it.buffer_id == buffer_id && it_index != existing_editor return it_index;
    }
    editor_id := open_editors.count;
    editor := array_add(*open_editors);
    editor.buffer_id = buffer_id;
    array_add(*editor.cursors, Cursor.{});
    return editor_id;
}

find_or_create_buffer :: (path: string) -> buffer_id: s64 {
    for open_buffers {
        if it.file == path return it_index;
    }

    // Create and load file
    buffer_id := open_buffers.count;
    buffer := array_add(*open_buffers);
    buffer.file = copy_string(path);

    file_data, success := read_entire_file(path);
    if !success then file_data = sprint("Couldn't load file '%'", path);
    defer free(file_data);
    array_copy(*buffer.bytes, cast([]u8) file_data);
    remove_crlf(buffer);

    if ends_with_nocase(path, ".jai") {
        buffer.lang = .Jai;
    } else if ends_with(path, "LOG.md") {
        buffer.lang = .Worklog;
    }

    return buffer_id;
}

#scope_export

Editor :: struct {
    buffer_id: s64;

    cursors: [..] Cursor;
    main_cursor: s64;
    viewport: Viewport;
    dragging_lmb := false;
    cursor_moved  := false;

    paste_animations: [..] Paste_Animation;
}

Viewport :: struct {
    top:  s32;
    left: s32;
    scroll_y: Scroll_Animation;
    scroll_x: Scroll_Animation;
}

Scroll_Animation :: struct {
    start, target: s32;
    started_at: float64;
    SPEED :: 0.1;  // how many seconds to finish any scroll animation
}

Paste_Animation :: struct {
    range: Range;
    started_at: float64;
    SPEED :: 0.5;
}

open_buffers: [..] Buffer;
open_editors: [..] Editor;

editors_layout: enum {
    None;
    Single;
    Double;
} = .None;

editor_active: s64 = -1;
editor_left:   s64 = -1;
editor_right:  s64 = -1;

dragging_splitter := false;
splitter_pos: float = 0;  // zero means it's in the middle
