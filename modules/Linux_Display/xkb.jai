LD_XKB_Key_Event_Type :: enum {
    Press;
    Release;
}

LD_XKB_State :: struct {
    kb_context: *xkb_context;
    kb_keymap : *xkb_keymap;
    kb_state  : *xkb_state;

    kb_compose_table: *xkb_compose_table;
    kb_compose_state: *xkb_compose_state;

    mod_idx_shift     : u32;
    mod_idx_ctrl      : u32;
    mod_idx_alt       : u32;
    mod_idx_caps_lock : u32;
    mod_idx_super     : u32;
    mod_idx_alt_gr    : u32;

    mods_depressed : u32;
    mods_latched   : u32;
    mods_locked    : u32;
    grp_depressed  : u32;
    grp_latched    : u32;
    grp_locked     : u32;
}

ld_xkb_state_init :: (d: *Base_Display, handle: *xcb_connection_t) -> bool {
    state := *d.xkb_state;

    core_kb_id := xkb_x11_get_core_keyboard_device_id(handle);
    if core_kb_id < 0 {
        log_error("Failed to get device ID for core keyboard");
        return false;
    }

    kb_context := xkb_context_new(.XKB_CONTEXT_NO_FLAGS);
    kb_keymap  := xkb_x11_keymap_new_from_device(kb_context, handle, core_kb_id, .XKB_KEYMAP_COMPILE_NO_FLAGS);
    kb_state   := xkb_x11_state_new_from_device(kb_keymap, handle, core_kb_id);

    kb_compose_table := xkb_compose_table_new_from_locale(kb_context, setlocale(LC_ALL, null), .XKB_COMPOSE_COMPILE_NO_FLAGS);
    kb_compose_state := xkb_compose_state_new(kb_compose_table, .XKB_COMPOSE_STATE_NO_FLAGS);

    mod_idx_shift     := xkb_keymap_mod_get_index(kb_keymap, XKB_MOD_NAME_SHIFT.data);
    mod_idx_ctrl      := xkb_keymap_mod_get_index(kb_keymap, XKB_MOD_NAME_CTRL.data);
    mod_idx_alt       := xkb_keymap_mod_get_index(kb_keymap, XKB_MOD_NAME_ALT.data);
    mod_idx_caps_lock := xkb_keymap_mod_get_index(kb_keymap, XKB_MOD_NAME_CAPS.data);
    mod_idx_super     := xkb_keymap_mod_get_index(kb_keymap, XKB_MOD_NAME_LOGO.data);
    mod_idx_alt_gr    := xkb_keymap_mod_get_index(kb_keymap, XKB_MOD_NAME_ALT_GR.data);

    xkb_compose_state_unref(state.kb_compose_state);
    xkb_compose_table_unref(state.kb_compose_table);
    xkb_state_unref(state.kb_state);
    xkb_keymap_unref(state.kb_keymap);
    xkb_context_unref(state.kb_context);

    state.kb_context = kb_context;
    state.kb_keymap = kb_keymap;
    state.kb_state = kb_state;
    state.kb_compose_table = kb_compose_table;
    state.kb_compose_state = kb_compose_state;
    state.mod_idx_shift = mod_idx_shift;
    state.mod_idx_ctrl = mod_idx_ctrl;
    state.mod_idx_alt = mod_idx_alt;
    state.mod_idx_caps_lock = mod_idx_caps_lock;
    state.mod_idx_super = mod_idx_super;
    state.mod_idx_alt_gr = mod_idx_alt_gr;

    ld_xkb_finalize(state);

    return true;
}

ld_xkb_state_init :: (d: *Base_Display, keymap: *void) -> bool {
    state := *d.xkb_state;

    kb_context := xkb_context_new(.XKB_CONTEXT_NO_FLAGS);
    kb_keymap  := xkb_keymap_new_from_string(kb_context, keymap, .XKB_KEYMAP_FORMAT_TEXT_V1, .XKB_KEYMAP_COMPILE_NO_FLAGS);
    kb_state   := xkb_state_new(kb_keymap);

    kb_compose_table := xkb_compose_table_new_from_locale(kb_context, setlocale(LC_ALL, null), .XKB_COMPOSE_COMPILE_NO_FLAGS);
    kb_compose_state := xkb_compose_state_new(kb_compose_table, .XKB_COMPOSE_STATE_NO_FLAGS);

    mod_idx_shift     := xkb_keymap_mod_get_index(kb_keymap, XKB_MOD_NAME_SHIFT.data);
    mod_idx_ctrl      := xkb_keymap_mod_get_index(kb_keymap, XKB_MOD_NAME_CTRL.data);
    mod_idx_alt       := xkb_keymap_mod_get_index(kb_keymap, XKB_MOD_NAME_ALT.data);
    mod_idx_caps_lock := xkb_keymap_mod_get_index(kb_keymap, XKB_MOD_NAME_CAPS.data);
    mod_idx_super     := xkb_keymap_mod_get_index(kb_keymap, XKB_MOD_NAME_LOGO.data);
    mod_idx_alt_gr    := xkb_keymap_mod_get_index(kb_keymap, XKB_MOD_NAME_ALT_GR.data);

    xkb_compose_state_unref(state.kb_compose_state);
    xkb_compose_table_unref(state.kb_compose_table);
    xkb_state_unref(state.kb_state);
    xkb_keymap_unref(state.kb_keymap);
    xkb_context_unref(state.kb_context);

    state.kb_context = kb_context;
    state.kb_keymap = kb_keymap;
    state.kb_state = kb_state;
    state.mod_idx_shift = mod_idx_shift;
    state.mod_idx_ctrl = mod_idx_ctrl;
    state.mod_idx_alt = mod_idx_alt;
    state.mod_idx_caps_lock = mod_idx_caps_lock;
    state.mod_idx_super = mod_idx_super;
    state.mod_idx_alt_gr = mod_idx_alt_gr;
    state.kb_compose_table = kb_compose_table;
    state.kb_compose_state = kb_compose_state;

    ld_xkb_finalize(state);

    return true;
}

ld_xkb_state_set_mods :: inline (d: *Base_Display,
    mods_depressed: u32, mods_latched: u32, mods_locked: u32,
    grp_depressed: u32, grp_latched: u32, grp_locked: u32) #c_call
{
    state := *d.xkb_state;
    state.mods_depressed = mods_depressed;
    state.mods_latched   = mods_latched;
    state.mods_locked    = mods_locked;
    state.grp_depressed  = grp_depressed;
    state.grp_latched    = grp_latched;
    state.grp_locked     = grp_locked;
}

ld_xkb_state_set_mods :: inline (d: *Base_Display, depressed: u32, latched: u32, locked: u32, group: u32) #c_call {
    ld_xkb_state_set_mods(d, depressed, latched, locked, group, group, group);
}

ld_xkb_state_apply_mods :: inline (d: *Base_Display) #c_call {
    state := *d.xkb_state;
    xkb_state_update_mask(
        state.kb_state,
        state.mods_depressed, state.mods_latched, state.mods_locked,
        state.grp_depressed, state.grp_latched, state.grp_locked);
}

ld_xkb_handle_key_event :: (d: *Base_Display, keycode: u32, event_type: LD_XKB_Key_Event_Type, repeat: bool) -> *Input.Event {
    state := *d.xkb_state;
    ld_xkb_state_apply_mods(d);

    utf32: u32;
    is_printable: bool;
    keysym := xkb_state_key_get_one_sym(state.kb_state, keycode);

    ji_event: Input.Event;
    ji_event.type = .KEYBOARD;
    ji_event.shift_pressed    = xkb_state_mod_index_is_active(state.kb_state, state.mod_idx_shift, .XKB_STATE_MODS_EFFECTIVE) == 1;
    ji_event.ctrl_pressed     = xkb_state_mod_index_is_active(state.kb_state, state.mod_idx_ctrl,  .XKB_STATE_MODS_EFFECTIVE) == 1;
    ji_event.alt_pressed      = xkb_state_mod_index_is_active(state.kb_state, state.mod_idx_alt,   .XKB_STATE_MODS_EFFECTIVE) == 1;
    ji_event.cmd_meta_pressed = xkb_state_mod_index_is_active(state.kb_state, state.mod_idx_super, .XKB_STATE_MODS_EFFECTIVE) == 1;

    if event_type == .Press {
        xkb_compose_state_feed(state.kb_compose_state, keysym);

        status := xkb_compose_state_get_status(state.kb_compose_state);
        if status == .XKB_COMPOSE_COMPOSED || status == .XKB_COMPOSE_CANCELLED {
            keysym = xkb_compose_state_get_one_sym(state.kb_compose_state);
            xkb_compose_state_reset(state.kb_compose_state);
        }

        utf32 = xkb_keysym_to_utf32(keysym);
        is_printable = ((utf32 >= 32) && (utf32 != 127));

        ji_event.key_pressed = 1;
        ji_event.key_code = ifx ld_xkb_is_plus(state, keycode) then cast(Input.Key_Code)(#char "+") else x11_translate_key_code(keysym);
        ji_event.text_input_count = xx is_printable;
        d.input_button_states[ji_event.key_code] = (Input.Key_Current_State.START | Input.Key_Current_State.DOWN);
    } else {
        ji_event.key_pressed = 0;
        ji_event.key_code = x11_translate_key_code(keysym);
        d.input_button_states[ji_event.key_code] = Input.Key_Current_State.END;
    }
    ji_event.repeat = repeat;

    if ji_event.key_code == {
        case .SHIFT; ji_event.shift_pressed = true;
        case .CTRL;  ji_event.ctrl_pressed = true;
        case .ALT;   ji_event.alt_pressed = true;
        case .META;  ji_event.cmd_meta_pressed = true;
    }

    array_add(*d.events_this_frame, ji_event);
    idx := d.events_this_frame.count - 1;

    if ji_event.key_pressed && is_printable {
        text_event: Input.Event;
        text_event.type = .TEXT_INPUT;
        text_event.key_pressed = 1;
        text_event.key_code = ji_event.key_code;
        text_event.utf32 = utf32;
        array_add(*d.events_this_frame, text_event);
    }

    return *d.events_this_frame[idx];
}


#scope_file

#if false {
    /*
     * This code is an attempt at solving the "Ctrl-Plus" problem. While this solution
     * "works" for that specific key combination it doesn't actually solve the underlying
     * problem of having layout-agnostic keybinds. I'm leaving it here as a reference
     * only.
     *
     *  - ileonte, 2024.03.04
     */

    LD_XKB_Plus_Hack :: struct {
        keycode: xkb_keycode_t;
        layout: xkb_layout_index_t;
    }
    plus_hack_entries: [..]LD_XKB_Plus_Hack;

    ld_xkb_finalize :: (state: *LD_XKB_State) {
        array_reset_keeping_memory(*plus_hack_entries);

        kc_min := xkb_keymap_min_keycode(state.kb_keymap);
        kc_max := xkb_keymap_max_keycode(state.kb_keymap);
        layouts_count := xkb_keymap_num_layouts(state.kb_keymap);

        if !layouts_count return;
        for layout: 0..layouts_count - 1 {
            for keycode: kc_min..kc_max {
                levels_count := xkb_keymap_num_levels_for_key(state.kb_keymap, keycode, layout);
                if !levels_count continue;

                for level: 0..levels_count - 1 {
                    syms: *xkb_keysym_t;
                    count := xkb_keymap_key_get_syms_by_level(state.kb_keymap, keycode, layout, level, *syms);
                    if count <= 0 continue;

                    for 0..count - 1 {
                        keysym : X11.Known_Keysyms = xx syms[it];
                        if keysym == .XK_plus {
                            array_add(*plus_hack_entries, .{
                                keycode = keycode,
                                layout = layout
                            });
                            continue layout;
                        }
                    }
                }
            }
        }
    }

    ld_xkb_is_plus :: (state: *LD_XKB_State, keycode: u32) -> bool {
        layout := xkb_state_key_get_layout(state.kb_state, keycode);
        for * plus_hack_entries {
            if it.keycode == keycode && it.layout == layout return true;
        }
        return false;
    }
} else {
    ld_xkb_finalize :: (state: *LD_XKB_State) #expand {
    }

    ld_xkb_is_plus :: (state: *LD_XKB_State, keycode: u32) -> bool #expand {
        return false;
    }
}
