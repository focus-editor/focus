add_user_error :: inline (message: string, dismiss_in_seconds: float64 = -1, tag := Tag.none ) {
    add_user_message(message, .error, cast(Time) dismiss_in_seconds, tag);
}

add_user_warning :: inline (message: string, dismiss_in_seconds: float64 = 10, tag := Tag.none) {
    add_user_message(message, .warning, cast(Time) dismiss_in_seconds, tag);
}

add_success_message :: inline (message: string, dismiss_in_seconds: float64 = 10, tag := Tag.none) {
    add_user_message(message, .success, cast(Time) dismiss_in_seconds, tag);
}

add_user_message :: (message: string, level: User_Message.Level, dismiss_in_seconds: Time, tag: Tag) {
    array_add(*user_messages, User_Message.{
        message            = copy_string(message),
        level              = level,
        tag                = tag,
        time               = cast(Time) get_time(),
        dismiss_in_seconds = cast(Time) dismiss_in_seconds,
    });
}

get_user_messages :: (current_time: Time) -> [] User_Message {
    // Cleanup the old or manually dismissed messages
    for < user_messages {
        // We do care about the order here, but since we're looping backwards we won't change the order
        if (it.dismiss_in_seconds >= 0 && current_time - it.time > it.dismiss_in_seconds) || it.dismissed || !it.message {
            free_message(it);
            remove it;
        }
    }

    if user_messages.count > MAX_MESSAGES_ON_SCREEN {
        return array_view(user_messages, user_messages.count - MAX_MESSAGES_ON_SCREEN, MAX_MESSAGES_ON_SCREEN);
    }
    return user_messages;
}

clear_user_messages :: (tag := Tag.none) {
    for < * user_messages {
        if !(it.tag & tag) && tag != .none continue;
        free_message(it);
        remove it;
    }
}

#scope_file

free_message :: (message: User_Message) {
    free(message.message);
    // TODO: when we have a linked file, free it here too
}

user_messages: [..] User_Message;

User_Message :: struct {
    message: string;
    level: Level;
    tag: Tag;
    time: Time;
    dismiss_in_seconds: Time;
    dismissed: bool;

    Level :: enum { warning; error; success; }
}

// Useful for dismissing messages by tag
Tag :: enum_flags {
    none;
    config;
    build;
}

MAX_MESSAGES_ON_SCREEN :: 8;