tokenize_uxntal :: (using buffer: *Buffer, start_offset := -1, count := -1) -> [] Buffer_Region {
    tokenizer := get_tokenizer(buffer, start_offset, count);

    while true {
        token := get_next_token(*tokenizer);
        if token.type == .eof then break;

        highlight_token(buffer, token);
    }

    return .[];
}

#scope_file

get_next_token :: (using tokenizer: *Tokenizer) -> Token {
    eat_white_space(tokenizer);

    token := Token.{
        start = cast(s32) (t - buf.data),
        type = .eof
    };

    if t >= max_t then return token;
    start_t = t;

    char := t.*;

                        /* I dont know what identifiers may start with */
    if is_alnum(char) || char == #char "<" {
        parse_identifier(tokenizer, *token);
    } else if char == {
        case #char ","; #through;
        case #char "."; #through;
        case #char ";"; #through;
        case #char "_"; #through;
        case #char "-"; #through;
        case #char "="; #through;
        case #char "&"; #through;
        case #char "@";
            parse_label(tokenizer, *token);

        case #char "!"; token.type = .punctuation; token.punctuation = .jmi;          t += 1;
        case #char "?"; token.type = .punctuation; token.punctuation = .jci;          t += 1;
        case #char "{"; token.type = .punctuation; token.punctuation = .lambda_open;  t += 1;
        case #char "}"; token.type = .punctuation; token.punctuation = .lambda_close; t += 1;
        case #char "["; token.type = .punctuation; token.punctuation = .enum_open;    t += 1;
        case #char "]"; token.type = .punctuation; token.punctuation = .enum_close;   t += 1;

        case #char "|"; #through;
        case #char "$";
            parse_padding(tokenizer, *token);

        case #char "\""; parse_ascii_literal(tokenizer, *token);
        case #char "(";  parse_comment(tokenizer, *token);
        case #char "#";  parse_hex_literal(tokenizer, *token);
        case #char "%";  parse_macro(tokenizer, *token);
        case #char "~";  parse_include(tokenizer, *token);

        case;
            token.type = .comment;
            t += 1;
    }

    if t >= max_t then t = max_t;
    token.len = cast(s32) (t - start_t);
    return token;
}

Punctuation :: enum u16 {
    jmi;         /* ! */
    jci;         /* ? */
    lambda_open;  /* { */
    lambda_close; /* } */
    enum_open;
    enum_close;
}

OPCODES :: string.[
    "BRK",    "INC",    "POP",    "NIP",    "SWP",    "ROT",    "DUP",    "OVR",    "EQU",    "NEQ",    "GTH",    "LTH",    "JMP",    "JCN",    "JSR",    "STH",
    "LDZ",    "STZ",    "LDR",    "STR",    "LDA",    "STA",    "DEI",    "DEO",    "ADD",    "SUB",    "MUL",    "DIV",    "AND",    "ORA",    "EOR",    "SFT",
    "JCI",    "INC2",   "POP2",   "NIP2",   "SWP2",   "ROT2",   "DUP2",   "OVR2",   "EQU2",   "NEQ2",   "GTH2",   "LTH2",   "JMP2",   "JCN2",   "JSR2",   "STH2",
    "LDZ2",   "STZ2",   "LDR2",   "STR2",   "LDA2",   "STA2",   "DEI2",   "DEO2",   "ADD2",   "SUB2",   "MUL2",   "DIV2",   "AND2",   "ORA2",   "EOR2",   "SFT2",
    "JMI",    "INCr",   "POPr",   "NIPr",   "SWPr",   "ROTr",   "DUPr",   "OVRr",   "EQUr",   "NEQr",   "GTHr",   "LTHr",   "JMPr",   "JCNr",   "JSRr",   "STHr",
    "LDZr",   "STZr",   "LDRr",   "STRr",   "LDAr",   "STAr",   "DEIr",   "DEOr",   "ADDr",   "SUBr",   "MULr",   "DIVr",   "ANDr",   "ORAr",   "EORr",   "SFTr",
    "JSI",    "INC2r",  "POP2r",  "NIP2r",  "SWP2r",  "ROT2r",  "DUP2r",  "OVR2r",  "EQU2r",  "NEQ2r",  "GTH2r",  "LTH2r",  "JMP2r",  "JCN2r",  "JSR2r",  "STH2r",
    "LDZ2r",  "STZ2r",  "LDR2r",  "STR2r",  "LDA2r",  "STA2r",  "DEI2r",  "DEO2r",  "ADD2r",  "SUB2r",  "MUL2r",  "DIV2r",  "AND2r",  "ORA2r",  "EOR2r",  "SFT2r",
    "LIT",    "INCk",   "POPk",   "NIPk",   "SWPk",   "ROTk",   "DUPk",   "OVRk",   "EQUk",   "NEQk",   "GTHk",   "LTHk",   "JMPk",   "JCNk",   "JSRk",   "STHk",
    "LDZk",   "STZk",   "LDRk",   "STRk",   "LDAk",   "STAk",   "DEIk",   "DEOk",   "ADDk",   "SUBk",   "MULk",   "DIVk",   "ANDk",   "ORAk",   "EORk",   "SFTk",
    "LIT2",   "INC2k",  "POP2k",  "NIP2k",  "SWP2k",  "ROT2k",  "DUP2k",  "OVR2k",  "EQU2k",  "NEQ2k",  "GTH2k",  "LTH2k",  "JMP2k",  "JCN2k",  "JSR2k",  "STH2k",
    "LDZ2k",  "STZ2k",  "LDR2k",  "STR2k",  "LDA2k",  "STA2k",  "DEI2k",  "DEO2k",  "ADD2k",  "SUB2k",  "MUL2k",  "DIV2k",  "AND2k",  "ORA2k",  "EOR2k",  "SFT2k",
    "LITr",   "INCkr",  "POPkr",  "NIPkr",  "SWPkr",  "ROTkr",  "DUPkr",  "OVRkr",  "EQUkr",  "NEQkr",  "GTHkr",  "LTHkr",  "JMPkr",  "JCNkr",  "JSRkr",  "STHkr",
    "LDZkr",  "STZkr",  "LDRkr",  "STRkr",  "LDAkr",  "STAkr",  "DEIkr",  "DEOkr",  "ADDkr",  "SUBkr",  "MULkr",  "DIVkr",  "ANDkr",  "ORAkr",  "EORkr",  "SFTkr",
    "LIT2r",  "INC2kr", "POP2kr", "NIP2kr", "SWP2kr", "ROT2kr", "DUP2kr", "OVR2kr", "EQU2kr", "NEQ2kr", "GTH2kr", "LTH2kr", "JMP2kr", "JCN2kr", "JSR2kr", "STH2kr",
    "LDZ2kr", "STZ2kr", "LDR2kr", "STR2kr", "LDA2kr", "STA2kr", "DEI2kr", "DEO2kr", "ADD2kr", "SUB2kr", "MUL2kr", "DIV2kr", "AND2kr", "ORA2kr", "EOR2kr", "SFT2kr",
];

#insert -> string {
    b: String_Builder;
    init_string_builder(*b);

    print_to_builder(*b, "Opcode :: enum u16 {\n");
    for OPCODES print_to_builder(*b, "    %;\n", it);
    print_to_builder(*b, "}\n");

    return builder_to_string(*b);
}

Token :: struct {
    using #as base: Base_Token;

    union {
        punctuation: Punctuation;
        opcode:      Opcode;
    }
}

OPCODE_MAP :: #run -> Table(string, Opcode) {
    table: Table(string, Opcode);
    size := 10 * OPCODES.count;
    init(*table, size);

    #insert -> string {
        b: String_Builder;
        for OPCODES append(*b, sprint("table_add(*table, \"%1\", .%1);\n", it));
        return builder_to_string(*b);
    }

    return table;
}

MAX_OPCODE_LENGTH :: #run -> s32 {
    result: s64;
    for OPCODES { if result < it.count then result = it.count; }
    return xx result;
}

read_identifier_string :: (using tokenizer: *Tokenizer) -> (string, bool) {
    identifier: string;
    identifier.data = t;

    suspected_of_being_number := true;

    while t < max_t && (is_alnum(t.*) || is_char_allowed_within_name(t.*) ) /* TODO: more options are possible here */ {
        if !is_hex_digit(t.*)
            suspected_of_being_number = false;
        t += 1;
    }
    if t >= max_t then t = max_t;
    identifier.count = t - identifier.data;

    if !(identifier.count == 4 || identifier.count == 2)
        suspected_of_being_number = false;

    return identifier, suspected_of_being_number;
}

is_char_allowed_within_name :: inline (char: u8) -> bool {
    if char == {
        case #char "-"; #through;
        case #char "/"; #through;
        case #char "?"; #through;
        case #char "!"; #through;
        case #char "_"; #through;
        case #char "."; #through;
        case #char "+"; #through;
        case #char "<"; #through; // i assume these are cosmetic until proven otherwise
        case #char ">"; #through; // i assume these are cosmetic until proven otherwise
        case #char "^"; // TODO add more if found
            return true;
        case;
            return false;
    }
}

parse_identifier :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .identifier;
    ident, is_number := read_identifier_string(tokenizer);

    if is_number {
        token.type = .number;
        return;
    }

    if ident.count <= MAX_OPCODE_LENGTH {
        opcode, ok := table_find(*OPCODE_MAP, ident);
        if ok {
            token.type = .keyword;
            token.opcode = opcode;
            return;
        }
    }
}

parse_label :: (using tokenizer: *Tokenizer, token: *Token) {
    t += 1;

    while t < max_t && (is_alnum(t.*) || is_char_allowed_within_name(t.*)) {
        t += 1;
    }
    token.type = .function;  // to avoid creating a language-specific token type
}

parse_macro :: (using tokenizer: *Tokenizer, token: *Token) {
    t += 1;

    while t < max_t && (is_alnum(t.*) || is_char_allowed_within_name(t.*)) {
        t += 1;
    }
    token.type = .macro;
}

parse_padding :: (using tokenizer: *Tokenizer, token: *Token) {
    t += 1;

    while t < max_t && is_hex_digit(t.*) {
        t += 1;
    }

    token.type = .operation;
}

parse_ascii_literal :: (using tokenizer: *Tokenizer, token: *Token) {
    t += 1;

    while t < max_t && !is_space(t.*){
        t += 1;
    }

    token.type = .string_literal;
}

parse_comment :: (using tokenizer: *Tokenizer, token: *Token) {
    t += 1;

    while t < max_t && t.* != #char ")" {
        t += 1;
    }

    token.type = .comment; // lol
}

parse_hex_literal :: (using tokenizer: *Tokenizer, token: *Token) {
    t += 1;

    counter := 0;

    while t < max_t && is_hex_digit(t.*) {
        counter += 1;
        t += 1;
    }

    if counter == 2 || counter == 4
        token.type = .number;
    else
        token.type = .invalid;
}

parse_include :: (using tokenizer: *Tokenizer, token: *Token) {
    t += 1;

    while t < max_t && (is_alnum(t.*) || is_char_allowed_within_name(t.*)) {
        t += 1;
    }
    token.type = .operation;
}

is_hex_digit :: inline (char: u8) -> bool {
    return (char >= #char "a" && char <= #char "f") || (char >= #char "0" && char <= #char "9");
}

is_alnum :: inline (c: u8) -> bool { return is_alpha(c) || is_digit(c); }
