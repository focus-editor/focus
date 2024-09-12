dialog_handle_event :: (using dialog: *Generic_Choice_Dialog, event: Input.Event) -> handled: bool {
    if event.type == .KEYBOARD && event.key_pressed {
        action, mapping := map_event_to_action(event, Action_Open_File_Dialog);
        if action == {
            case .escape;                   #through;
            case .close_dialog;             hide_dialog(dialog)   ;                         return true;

            case .open_entry_in_place;      dialog.open_entry_in_place(); return true;
            case .open_entry_on_the_side;   if dialog.open_entry_on_the_side  then dialog.open_entry_on_the_side();  else dialog.open_entry_in_place(); return true;
            case .open_entry_on_the_left;   if dialog.open_entry_on_the_left  then dialog.open_entry_on_the_left();  else dialog.open_entry_in_place(); return true;
            case .open_entry_on_the_right;  if dialog.open_entry_on_the_right then dialog.open_entry_on_the_right(); else dialog.open_entry_in_place(); return true;

            case .move_up;                  move_dialog_cursor(dialog, -1, wrap = true);    return true;
            case .move_down;                move_dialog_cursor(dialog,  1, wrap = true);    return true;
            case .move_up_fast;             move_dialog_cursor(dialog, -5);                 return true;
            case .move_down_fast;           move_dialog_cursor(dialog,  5);                 return true;
            case .move_up_one_page;         move_dialog_cursor(dialog, -per_page);          return true;
            case .move_down_one_page;       move_dialog_cursor(dialog,  per_page);          return true;
        }

        handled := maybe_handle_dialog_input_event(dialog, *input, event);
        return handled;

    } else if event.type == .TEXT_INPUT {
        char := event.utf32;
        text_input_type_char(*dialog.input, char);
        refresh_dialog_entries(dialog);
        return true;
    }
    return false;
}

show_dialog :: (dialog: *Generic_Choice_Dialog) {
    active_global_widget = dialog.global_widget_id;
    assert(dialog.open_entry_in_place != null, "Generic dialogs must define open_entry_in_place and this one doesn't. This is a bug.");
    text_input_fully_clear(*dialog.input);
    refresh_dialog_entries(dialog);
    if dialog.on_show then dialog.on_show();
}

hide_dialog :: (dialog: Generic_Choice_Dialog) {
    activate_editors();
    if dialog.on_hide then dialog.on_hide();
}

refresh_dialog_entries :: (using dialog: *Generic_Choice_Dialog) {
    pool_allocator := Allocator.{ proc = flat_pool_allocator_proc, data = *memory_pool };
    push_allocator(pool_allocator);
    reset(*memory_pool);

    array_reset(*filtered);

    scroll_to_cursor = .snap;
    scroll_y = 0;
    selected = 0;

    filter := construct_fuzzy_filter(to_string(input.text));

    dialog.refresh_entries(filter);

    compare_entries :: (e1: Entry, e2: Entry) -> s64 {
        key_diff := cast,no_check(s64) e2.sort_key - cast,no_check(s64) e1.sort_key;
        if key_diff != 0 return key_diff;
        return memcmp(e1.name.data, e2.name.data, min(e1.name.count, e2.name.count));
    }

    quick_sort(filtered, compare_entries);

    if dialog.after_refresh then dialog.after_refresh();
}

#scope_file

move_dialog_cursor :: (using dialog: *Generic_Choice_Dialog, delta: s64, wrap := false, snap := true) {
    selected += delta;

    if wrap {
        if selected < 0 then selected = max(0, filtered.count - 1);
        if selected >= filtered.count then selected = 0;
    } else {
        if selected < 0 then selected = 0;
        if selected >= filtered.count then selected = filtered.count - 1;
    }
    scroll_to_cursor = ifx snap then Scroll_Mode.snap else .yes;

    if on_move then on_move();
}

maybe_handle_dialog_input_event :: (dialog: *Generic_Choice_Dialog, using input: *Text_Input, event: Input.Event) -> handled: bool {
    input_text := copy_temporary_string(to_string(text));
    handled := text_input_handle_event(input, event);
    if handled {
        if input_text != to_string(input.text) then refresh_dialog_entries(dialog);
        return true;
    }
    return false;
}


#scope_export

Generic_Choice_Dialog :: struct(Entry_Details: Type) {
    input: Text_Input;
    filtered: [..] Entry;
    selected: s64;
    selected_by_mouse: s64 = -1;  // to remember which entry the left mouse button went down on

    scroll_y: s32;
    scroll_anim := #run Tween_Animation(s32).{ speed = 0.1, func = .lerp };
    per_page: s64 = 10;
    scroll_to_cursor: Scroll_Mode = .no;

    memory_pool: Flat_Pool;

    Entry :: struct {
        highlights: [] bool;
        sort_key: u64;
        using details: Entry_Details;
    }

    // Will be overridden by the actual dialog structs
    global_widget_id: Active_Global_Widget;
    refresh_entries: (filter: Fuzzy_Filter) -> ();
    after_refresh: () -> ();
    on_move: () -> ();
    on_show: () -> ();
    on_hide: () -> ();
    open_entry_in_place:     () -> ();
    open_entry_on_the_side:  () -> ();
    open_entry_on_the_left:  () -> ();
    open_entry_on_the_right: () -> ();
}
