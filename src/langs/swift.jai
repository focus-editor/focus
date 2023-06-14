highlight_swift_syntax :: (using buffer: *Buffer) {
    lexer: Lexer;
    lexer.contents = to_string(bytes);
    tokenize(*lexer);

    print("%\n", lexer.tokens.count);

    for token: lexer.tokens {
        if token.start != 0 && token.end != 0 {
            color := color_for_token_type(token.type);
            memset(colors.data + token.start, xx color, token.end - token.start);
        }
    }
}

#scope_file

color_for_token_type :: (type: Token_Type) -> Code_Color {
    if type == {
    case .IDENTIFIER;
        return .DEFAULT;    
    case .ATTRIBUTE;
        return .KEYWORD;
    case .NUMBER;
        return .VALUE;
    case .STRING;
        return .STRING;
    case .COMMENT;
        return .COMMENT;
    }

    if type > 200 && type < 250 {
        return .OPERATION;
    } else {
        return .KEYWORD;
    }

    return .DEFAULT;
}

#load "/Users/iaroslav.erokhin/Documents/GitHub/Complicator/lexer.jai";
