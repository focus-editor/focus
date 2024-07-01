tokenize_markdown ::  (using buffer: *Buffer, start_offset := -1, count := -1) -> [] Buffer_Region {
    tokenizer := get_md_tokenizer(buffer, start_offset, count);
        
    while true { 
        token := get_next_token(*tokenizer);
        if token.type == .eof break;

        memset(tokens.data + token.start, xx token.type, token.len);
    }
    return .[];
}

#scope_file
get_md_tokenizer :: (using buffer: *Buffer, start_offset := -1, count := -1) -> MD_Tokenizer {
    tokenizer: MD_Tokenizer;

    tokenizer.buf      = cast(string) bytes;
    tokenizer.max_t    = bytes.data + bytes.count;
    tokenizer.t        = bytes.data;
    tokenizer.found_new_line_char = true;
    tokenizer.found_white_char    = true;

    if start_offset >= 0 {
        start_offset = clamp(start_offset, 0, bytes.count - 1);
        count        = clamp(count,        0, bytes.count - 1);
        tokenizer.t += start_offset;
        tokenizer.max_t = tokenizer.t + count;
    }

    return tokenizer;
}

get_next_token :: (using tokenizer: *MD_Tokenizer) -> Token {
    // Eat white space and look fo new line.    
    while t < max_t && is_white_space(t.*) {
        found_white_char    = true;
        if t.* == #char "\n" found_new_line_char = true;
        t += 1;
    }     

    token: Token;
    token.start = cast(s32) (t - buf.data);    
    token.type = .eof;
    if t >= max_t return token;
    
    start_t = t;
    char := t.*;    
    if maybe_do_task_list && !found_new_line_char {
        parse_task_list(tokenizer, *token);
    }
    
    else if is_digit(char) {
        parse_number(tokenizer, *token);
    }

    else if char == {
        // Only after new line.
        case #char "#"; parse_hash(tokenizer, *token);          
        case #char ">"; parse_greater_than(tokenizer, *token); 
        case #char "-"; parse_bullet_point(tokenizer, *token);
        case #char "+"; parse_bullet_point(tokenizer, *token);
        
        // Only after white space.
        case #char "@"; parse_at(tokenizer, *token);
        case #char "h"; parse_link(tokenizer, *token);
        
        // Only after every character.
        case #char "`"; parse_backtick(tokenizer, *token);
        case #char "~"; parse_tilde(tokenizer, *token);
        case #char "*"; parse_char_for_style(tokenizer, *token, char);
        case #char "_"; parse_char_for_style(tokenizer, *token, char);
        case #char "<"; parse_smaller_than(tokenizer, *token);
        case #char "["; parse_square_bracket(tokenizer, *token);
        case #char "!"; parse_exclamation_mark(tokenizer, *token);
        case;           token.type = .default; t += 1;
    }    

    found_new_line_char = false;
    found_white_char    = false;

    if t >= max_t then t = max_t;
    token.len = cast(s32) (t - start_t);
    return token;
}

parse_at :: (using tokenizer: *MD_Tokenizer, token: *Token) {    
    #insert return_if_no_white_space_was_found;    

    token.type = .string_literal;
    while t < max_t && !is_white_space(t.*) {
        t += 1;
    }

}

parse_number :: (using tokenizer: *MD_Tokenizer, token: *Token) {    
    #insert return_if_no_new_line_was_found;
        
    while is_digit(t.*) {
        t += 1;
        if t >= max_t return;
    }
    
    if t.* == #char "." {
        token.type = .keyword;
        t += 1;
        maybe_do_task_list = true;
    } else token.type = .default;
 
}

parse_hash :: (using tokenizer: *MD_Tokenizer, token: *Token) {    
    #insert return_if_no_new_line_was_found;
    
    token.type = .type;
    t += 1;

    while t < max_t && t.* != #char "\n" {
        // When encountering a link we highlight it because that is often done in README's on Github to reference a section in the README.
        if t.* == #char "[" return;
        next_t := t +1;
        if next_t < max_t && t.* == #char "!" && next_t.* == #char "[" return;
        
        t += 1;
    }
}

parse_greater_than :: (using tokenizer: *MD_Tokenizer, token: *Token) {
    #insert return_if_no_new_line_was_found;

    token.type = .operation;
    t += 1;
}

parse_bullet_point :: (using tokenizer: *MD_Tokenizer, token: *Token) {    
    #insert return_if_no_new_line_was_found;

    next_t := t + 1;
    if next_t < max_t && is_white_space(next_t.*) {
        token.type = .keyword;  
        
        if next_t < max_t && next_t.* == #char " " { 
            maybe_do_task_list = true;
        }
    }
    
    else token.type = .default;  
    t += 1;
}

parse_char_for_style :: (using tokenizer: *MD_Tokenizer, token: *Token, char: u8) {
    // Bullet point. Same as minus.
    next_t := t + 1;
    is_bullet_point := next_t < max_t && is_white_space(next_t.*);
    
    if found_new_line_char && is_bullet_point {
        token.type = .keyword;  
        t += 1;
        return;    
    }  

    // Bold, italic and bold+italic.
    token.type = .operation;
    
    is_triple := highlight_for_repeated_chars(char, 3, tokenizer);
    
    is_double := true;
    if !is_triple {
        is_double = highlight_for_repeated_chars(char, 2, tokenizer);    
    }

    if !is_double {
        highlight_for_repeated_chars(char, 1, tokenizer);
    }
}

parse_tilde :: (using tokenizer: *MD_Tokenizer, token: *Token) {
    next_t := t + 1;
    if next_t < max_t && next_t.* == #char "~" {
        token.type = .invalid;
        highlight_for_repeated_chars(#char "~", 2, tokenizer);
    }

    else { token.type = .default; t += 1; }
}

parse_backtick :: (using tokenizer: *MD_Tokenizer, token: *Token) {
    token.type = .function;

    // ```Code Block```
    is_triple := highlight_for_repeated_chars(#char "`", 3, tokenizer, stop_at_new_para = false);

    // `Code line`    
    if !is_triple highlight_for_repeated_chars(#char "`", 1, tokenizer);    
}

parse_task_list :: (using tokenizer: *MD_Tokenizer, token: *Token) {
    token.type = .default;
    maybe_do_task_list = false;

    previous_t := t;
    identifier_str := read_identifier_string_tmp(tokenizer, stop_at_char = #char "\n", stop_at_white_space = false);

    if      begins_with(identifier_str, "[X]") token.type = .type;
    else if begins_with(identifier_str, "[ ]") token.type = .keyword;
    else { t = start_t; return; }
    
    t = previous_t + 3;
}

parse_square_bracket :: (using tokenizer: *MD_Tokenizer, token: *Token) {
    token.type = .number;
    add_link := false;
    
    nubmer_of_open_brackets := 1;
    t += 1;
    while t < max_t {
        if nubmer_of_open_brackets == 0 && t.* == #char "(" {
            while t < max_t {
                if t.* == #char "\n" return; 
                if t.* == #char ")" { t += 1; return; }
                t +=1;
            }
        }

        if t.* == #char "\n" return;
        
        else if t.* == #char "]" nubmer_of_open_brackets -= 1;
        else if t.* == #char "[" nubmer_of_open_brackets += 1;
        
        t += 1;
    }
    
}

parse_exclamation_mark :: (using tokenizer: *MD_Tokenizer, token: *Token) {    
    next_t := t + 1;
    if next_t < max_t && next_t.* == #char "[" {
        token.type = .number;
        t += 1;
        parse_square_bracket(tokenizer, token);    
    } else {
        token.type = .default;
        t += 1;
    }
    
}

parse_link :: (using tokenizer: *MD_Tokenizer, token: *Token) {
    #insert return_if_no_white_space_was_found;    
    
    identifier_str := read_identifier_string_tmp(tokenizer);
    
    if begins_with(identifier_str, "https://") || begins_with(identifier_str, "http://") {
        token.type = .number;
        while t < max_t {
            if is_white_space(t.*) return;
            t += 1;
        }
    } else token.type = .default;
    
}

parse_smaller_than :: (using tokenizer: *MD_Tokenizer, token: *Token) {
    #insert return_if_no_white_space_was_found;    
    
    tags: [..] Tag;    
    array_add(*tags, .{"<sub>", "</sub>", .number} );
    array_add(*tags, .{"<sup>", "</sup>", .number} );
    array_add(*tags, .{"<!--",  "-->",    .comment} );

    found_tag := false;        
    identifier_str := read_identifier_string_tmp(tokenizer);
    closing_tag: string;    

    for tags {
       if begins_with(identifier_str, it.opening_tag) { 
            token.type = it.type;  
            t = start_t + it.opening_tag.count; 
            closing_tag = it.closing_tag;
            found_tag = true;
            break;
        }
    }      
    
    if found_tag {
        while t < max_t {
            identifier_str = read_identifier_string_tmp(tokenizer, stop_at_char = #char ">");
            if ends_with(identifier_str, closing_tag) return;
        }
    } else token.type = .default;
    
}
    
check_repeated_chars :: (char: u8, repeats: s64, using tokenizer: *MD_Tokenizer) -> bool {
    for i:0..repeats-1 {
        next_t := t+i;
        if next_t < max_t && next_t.* != char return false;
    }
    return true;
}

highlight_for_repeated_chars :: (char: u8, repeats: s64, using tokenizer: *MD_Tokenizer, stop_at_new_para := true) -> bool {    
    is_repeated := check_repeated_chars(char, repeats, tokenizer);    
    if !is_repeated return false;

    t += repeats;
    if t >= max_t return true;
    
    while true {
        if check_repeated_chars(char, repeats, tokenizer) {
            t += repeats;
            break;
        }
        
        if stop_at_new_para && skip_white_space_and_look_for_next_paragraph(tokenizer) break;

        t += 1;
        if t >= max_t break;
    }
    
    return true;
}

read_identifier_string_tmp :: (using tokenizer: *MD_Tokenizer, stop_at_char := #char " ", stop_at_white_space := true) -> string /* temp */ {
    identifier: [..] u8;
    identifier.allocator = temp;

    array_add(*identifier, t.*);    
    t += 1;
    while t < max_t {
        c := t.*;
        if c == stop_at_char                          { t += 1; array_add(*identifier, c); break; }
        if !stop_at_white_space || !is_white_space(c) { t += 1; array_add(*identifier, c); continue; }
        break;
    }

    if t >= max_t then t = max_t;
    return cast(string) identifier;
}

skip_white_space_and_look_for_next_paragraph :: (using tokenizer: *MD_Tokenizer) -> found_new_para: bool {
    number_of_new_lines := 0;
    while t < max_t {
        if !is_white_space(t.*) break;
        if t.* == #char "\n" number_of_new_lines += 1;
        if number_of_new_lines >= 2 return true;
        t += 1;
    }
    return false;
}

MD_Tokenizer :: struct {
    using #as base: Tokenizer;
    found_new_line_char: bool;
    found_white_char   : bool;
    maybe_do_task_list : bool;
}

Token :: struct {
    start, len: s32;
    type: Token_Type = .invalid;
}

Tag :: struct {
    opening_tag: string;
    closing_tag: string;
    type: Token_Type;
}

return_if_no_white_space_was_found :: #string Done
    if !found_white_char { 
        t += 1; 
        token.type = .default;
        return; 
    }    
Done


return_if_no_new_line_was_found :: #string Done
    if !found_new_line_char { 
        t += 1; 
        token.type = .default;
        return; 
    }    
Done