language_dialog_handle_event :: (event: Input.Event) -> handled: bool {
    return dialog_handle_event(*language_dialog, event);
}

language_dialog: Language_Dialog;

Language_Dialog :: struct {
    using #as generic_dialog: Generic_Choice_Dialog(Language);
    generic_dialog.global_widget_id = .language_dialog;
    generic_dialog.refresh_entries  = language_dialog_refresh_entries;
    generic_dialog.open_entry       = apply_selected_language;
    generic_dialog.on_show          = language_dialog_on_show;
}

#scope_file

apply_selected_language :: (_: Editor_Placement) {
    using language_dialog;
    defer hide_dialog(*language_dialog);

    if build_panel_is_active() return;  // shouldn't ever be active

    if selected >= filtered.count return;

    _, buffer := get_visible_editor_and_buffer();
    if !buffer return;

    result := filtered[selected];
    buffer.lang = result.details.value;

    retokenize(buffer);
    recalculate_settings(buffer);
}

language_dialog_on_show :: () {
    hide_build_panel();
}

language_dialog_refresh_entries :: (filter: Fuzzy_Filter) {
    using language_dialog;

    editor, buffer := get_visible_editor_and_buffer();
    if !editor || !buffer return;

    langs := #run get_available_language_list();

    for * lang: langs {
        score, highlights := fuzzy_match(lang.name, filter);
        if score <= 0 && filter.full_string continue;

        entry := array_add(*filtered);
        entry.highlights = highlights;
        entry.sort_key = cast(u64) score;

        // When sorting, put the current language on top when we first open the dialog
        if !filter.full_string && lang.value == buffer.lang {
            lang.active = true;
            entry.sort_key |= cast(u64) 1 << 62;
        }

        entry.details = lang;
    }
}

get_available_language_list :: () -> [] Language {  // to be run once at compile time!
    languages: [..] Language;

    lang_names  := enum_names(Buffer.Lang);
    lang_values := enum_values_as_enum(Buffer.Lang);

    for lang_names {
        if equal_nocase(it, "focus_build_panel") continue;  // filter out "internal" languages
        array_add(*languages, .{name = replace(it, "_", " "), value = lang_values[it_index]});
    }

    return languages;
}

Language :: struct {
    active: bool = false;
    name: string;
    value: Buffer.Lang;
}
