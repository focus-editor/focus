add_user_error :: inline (message: string, link_file := "") {
    add_user_message(message, .error, link_file);
}

add_user_warning :: inline (message: string, link_file := "") {
    add_user_message(message, .warning, link_file);
}

add_user_message :: (message: string, level: User_Message.Level, link_file: string) {
    if user_messages.count >= MAX_MESSAGES then cleanup_old_messages();
    
    array_add(*user_messages, User_Message.{
        message   = copy_string(message),
        level     = level,
        time      = cast(Time) get_time(),
        link_file = copy_string(link_file),
    });
}

get_user_messages :: (current_time: Time) -> [] User_Message {
    count := 0;
        
    for < user_messages {
        if current_time - it.time > MAX_SHOW_TIME_S break;
        count += 1;
        if count >= 5 break;
    }
    
    return array_view(user_messages, user_messages.count - count, count);
}

#scope_file

cleanup_old_messages :: () {
    COUNT :: 10;
    last_messages := array_view(user_messages, user_messages.count - COUNT, COUNT);
    memcpy(user_messages.data, last_messages.data, COUNT * size_of(User_Message));
    user_messages.count = COUNT;
}

user_messages: [..] User_Message;

User_Message :: struct {
    message: string;
    level: Level;
    time: Time;
    link_file: string;
    dismissed: bool;
    
    Level :: enum { warning; error; };
}

MAX_SHOW_TIME_S :: 60;
MAX_MESSAGES    :: 64;  // need to cleanup after that
