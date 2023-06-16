// TODO: we're leaking a lot of memory
// TODO: $0 is looking weird

highlight_swift_syntax :: (using buffer: *Buffer) {
    lexer: Lexer;
    lexer.contents = to_string(bytes);
    tokenize(*lexer);

    last_token: Token = ---;

    for token: lexer.tokens {
        if !(token.start == 0 && token.end == 0) {
            color := color_for_token_type(token.type, token.is_capitalized);
            memset(colors.data + token.start, xx color, token.end - token.start);
        } else {
            print("Warning: This token does not have correct cursor information: %\n", token);
        }

        if last_token.type == .IDENTIFIER && !last_token.is_capitalized
            && (token.type == #char "(" || token.type == #char "{") 
        {
            memset(colors.data + last_token.start, xx Code_Color.FUNCTION, last_token.end - last_token.start);
        }

        last_token = token;
    }
}

#scope_file

color_for_token_type :: (type: Token_Type, is_capitalized: bool) -> Code_Color {
    if type == {
    case .IDENTIFIER;
        if !is_capitalized {
            return .DEFAULT;
        } else {
            return .TYPE;
        }
    case .ATTRIBUTE;
        return .TYPE;
    case .DIRECTIVE;
        return .KEYWORD;
    case .BINDING;  
        return .TYPE;
    case .INOUT;
        return .VALUE_KEYWORD;
    case .NUMBER;
        return .VALUE;
    case .STRING;
        return .STRING;
    case .COMMENT;
        return .COMMENT;
    }

    if type < 200 {
        return .PUNCTUATION;
    } else if type > 200 && type < 250 {
        return .OPERATION;
    } else { // keywords
        return .KEYWORD;
    }

    return .DEFAULT;
}

#load "/Users/iaroslav.erokhin/Documents/GitHub/Complicator/lexer.jai";
