language_dialog_handle_event :: (event: Input.Event) -> handled: bool {
    return dialog_handle_event(*language_dialog, event);
}

language_dialog: Language_Dialog;

Language_Dialog :: struct {
    using #as generic_dialog: Generic_Choice_Dialog(Language);
    generic_dialog.global_widget_id    = .language_dialog;
    generic_dialog.refresh_entries     = language_dialog_refresh_entries;
    generic_dialog.open_entry_in_place = apply_selected_language;
}

#scope_file

apply_selected_language :: () {
    using language_dialog;
    if selected >= filtered.count return;

    editor := *open_editors[editors.active];
    buffer := *open_buffers[editor.buffer_id];

    result := filtered[selected];
    buffer.lang = result.details.value;
    retokenize(buffer);

    hide_dialog(*language_dialog);
}

language_dialog_refresh_entries :: (filter: Fuzzy_Filter) {
    using language_dialog;

    langs :: #run get_languages();

    for lang: langs {
        score, highlights := fuzzy_match(lang.name, filter);
        if score <= 0 && filter.full_string continue;

        entry := array_add(*filtered);
        entry.details = lang;
        entry.highlights = highlights;
        entry.sort_key = cast(u64) score;

        // Sort current language on top when we first open the dialog
        editor := *open_editors[editors.active];
        current_lang := *open_buffers[editor.buffer_id].lang;

        if !filter.full_string && lang.value == << current_lang then entry.sort_key |= cast(u64) 1 << 62;
    }
}

get_languages :: () -> [] Language {
    languages: [..] Language;

    lang_names := enum_names(Buffer.Lang);
    lang_values := enum_values_as_enum(Buffer.Lang);

    // unwrap type_info members into struct containing both the enum, and the enum string
    for lang_names {
        array_add(*languages, .{name = it, value = lang_values[it_index]});
    }

    return languages;
}

Language :: struct {
    name: string;
    value: Buffer.Lang;
}
