ASCII_Char_Type :: enum_flags u8 {
    none;
    alpha;
    digit;
    space;
    print;
    underscore;
}

ascii_is_alpha :: inline (c: u8) -> bool {
    return char_type_table[c] & .alpha != 0;
}

ascii_is_digit :: inline (c: u8) -> bool {
    return char_type_table[c] & .digit != 0;
}

ascii_is_alnum :: inline (c: u8) -> bool { // This also includes underscore!
    return char_type_table[c] & (.alpha | .digit | .underscore) != 0;
}

ascii_is_space :: inline (c: u8) -> bool {
    return char_type_table[c] & .space != 0;
}

#scope_file

char_type_table :: #run -> [256] ASCII_Char_Type {
    table: [256] ASCII_Char_Type;

    for * type : table {
        c := cast(u8) it_index;
        if is_alpha(c)    then type.* |= .alpha;
        if is_digit(c)    then type.* |= .digit;
        if is_space(c)    then type.* |= .space;
        if c == 0x0C      then type.* |= .space;  // form feed
        if c == 0x0B      then type.* |= .space;  // vertical tab
        if is_print(c)    then type.* |= .print;
        if c == #char "_" then type.* |= .underscore;
    }

    return table;
}
