add_user_error :: inline (message: string, args: .. Any, dismiss_in_seconds: float64 = 10, tag := Tag.none ) {
    add_user_message(message, ..args, .error, dismiss_in_seconds, tag);
} @PrintLike

add_user_warning :: inline (message: string, args: .. Any, dismiss_in_seconds: float64 = 10, tag := Tag.none) {
    add_user_message(message, ..args, .warning, dismiss_in_seconds, tag);
} @PrintLike

add_success_message :: inline (message: string, args: .. Any, dismiss_in_seconds: float64 = 10, tag := Tag.none) {
    add_user_message(message, ..args, .success, dismiss_in_seconds, tag);
} @PrintLike

add_user_message :: (message: string, args: .. Any, level: User_Message.Level, dismiss_in_seconds: float64, tag: Tag) {
    push_allocator(focus_allocator);  // so that we can call this function from anywhere. We always want to allocate messages using the same allocator
    array_add(*user_messages, User_Message.{
        message            = sprint(message, ..args),
        level              = level,
        tag                = tag,
        time               = current_time_monotonic(),
        dismiss_in_seconds = dismiss_in_seconds,
    });
} @PrintLike

get_user_messages :: (current_time: Apollo_Time) -> [] User_Message {
    // Cleanup the old or manually dismissed messages
    for < user_messages {
        // We do care about the order here, but since we're looping backwards we won't change the order
        if (it.dismiss_in_seconds >= 0 && to_float64_seconds(current_time - it.time) > it.dismiss_in_seconds) || it.dismissed || !it.message {
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
    time: Apollo_Time;
    dismiss_in_seconds: float64;
    dismissed: bool;

    Level :: enum { warning; error; success; }
}

// Useful for dismissing messages by tag
Tag :: enum_flags {
    none;
    config;
    workspace;
    build;
}

MAX_MESSAGES_ON_SCREEN :: 20;
