highlight_jai_syntax :: (bytes: [] u8, colors: [] Simp.Code_Color) {
    PROFILE_FUNCTION();

    tokenizer: Tokenizer = ---;
    tokenizer.source = to_string(bytes);
    tokenizer.buf = to_string(bytes);
    tokenizer.state = .default;

    color: Simp.Code_Color;

    while true {
        token := get_next_token(*tokenizer);
        if token.type == .eof break;

        color := COLOR_MAP[token.type];
        memset(colors.data + token.start, xx color, token.len);
    }
}

#scope_file

get_next_token :: (using tokenizer: *Tokenizer) -> Token {
    EOF :: Token.{ start = 0, len = 0, type = .eof };

    str, success := parse_token(*buf, delimiters = ";=()-+*/");
    if !success return EOF;

    result: Token;
    result.start = cast(s32) (str.data - source.data);
    result.len = xx str.count;

    type, ok := table_find(*KEYWORD_MAP, str);
    if ok {
        result.type = type;
        return result;
    }

    result.type = .punctuation;
    return result;
}

Tokenizer :: struct {
    source: string;  // original string
    buf: string;     // for cursor
    state: State;

    State :: enum {
        default;

    }
}

Token :: struct {
    start, len: s32;
    type: Type;

    // Additional info to distinguish between keywords/punctuation
    union {
        keyword:            Keyword;
        punctuation:        Punctuation;
        compiler_directive: Compiler_Directive;
    }

    Type :: enum u16 {
        eof;

        identifier;
        string_literal;
        here_string;
        number;
        comment;
        multiline_comment;
        punctuation;
        modifier_keyword;
        keyword;
        type_keyword;
        value_keyword;
        compiler_directive;
    }
}

COLOR_MAP :: Simp.Code_Color.[
    .DEFAULT,       // eof - obviously not used
    .DEFAULT,       // identifier
    .STRING,        // string_literal
    .STRING,        // here_string
    .VALUE,         // number
    .COMMENT,       // comment
    .COMMENT,       // multiline_comment
    .PUNCTUATION,   // punctuation
    .KEYWORD,       // keyword
    .KEYWORD,       // modifier_keyword
    .TYPE,          // type_keyword
    .VALUE_KEYWORD, // value_keyword
    .KEYWORD,       // compiler_directive
];

PUNCTUATION :: string.[
    "arrow", "bang", "pipe", "pipe_pipe", "pipe_equal", "equal", "equal_equal", "bang_equal", "semicolon", "percent",
    "percent_equal", "l_paren", "r_paren", "l_brace", "r_brace", "l_bracket", "r_bracket", "period", "ellipsis2",
    "less_than", "double_less_than", "less_than_equals", "greater_than", "greater_than_equals", "plus", "plus_equal",
    "minus", "minus_equal", "asterisk", "asterisk_equal", "colon", "slash", "slash_equal", "comma", "ampersand",
    "ampersand_equal", "tilde",
];

KEYWORDS :: string.[
    "align_of", "break", "case", "cast", "code_of", "continue", "defer", "else", "enum", "enum_flags", "for",
    "if", "ifx", "is_constant", "push_context", "return", "size_of", "struct", "then", "type_info", "type_of", "union",
    "using", "while", "xx", "operator",
];

TYPE_KEYWORDS :: string.[
    "__reg", "bool", "float", "float32", "float64", "int", "reg", "s16", "s32", "s64", "s8", "string",
    "u16", "u32", "u64", "u8", "void",
];

VALUE_KEYWORDS :: string.[
    "context", "it", "it_index", "null", "true", "false",
];

COMPILER_DIRECTIVES :: string.[
    "add_context", "align", "as", "asm", "assert", "bake_arguments", "bake_constants", "bytes", "c_call", "caller_code",
    "caller_location", "char", "code", "compiler", "complete", "cpp_method", "cpp_return_type_is_non_pod", "deprecated",
    "dump", "dynamic_specialize", "elsewhere", "expand", "file", "filepath", "foreign", "foreign_library",
    "foreign_system_library", "if", "ifx", "import", "insert", "insert_internal", "intrinsic", "line", "load",
    "location", "modify", "module_parameters", "must", "no_abc", "no_alias", "no_context", "no_padding", "no_reset",
    "place", "placeholder", "poke_name", "procedure_of_call", "program_export", "run", "runtime_support",
    "scope_export", "scope_file", "scope_module", "specified", "string", "symmetric", "this", "through", "type",
    "type_info_no_size_complaint", "type_info_none", "type_info_procedures_are_void_pointers",
];

// TODO: implement
MODIFIERS :: string.[
    "isa", "distinct",  // type
    "only", "except", "map",  // using
    "no_check", "truncate",  // cast
    "no_dll",  // foreign_library
    "file", "dir", "string",  // import
    "scope",  // insert
];

#insert -> string {
    b: String_Builder;
    init_string_builder(*b);

    define_enum :: (b: *String_Builder, enum_name: string, prefix: string, value_lists: [][] string) {
        print_to_builder(b, "% :: enum u16 {\n", enum_name);
        for values : value_lists {
            for v : values print_to_builder(b, "    %0%;\n", prefix, v);
        }
        print_to_builder(b, "}\n");
    }

    define_enum(*b, "Punctuation",        "",          .[PUNCTUATION]);
    define_enum(*b, "Keyword",            "kw_",       .[KEYWORDS, TYPE_KEYWORDS, VALUE_KEYWORDS]);
    define_enum(*b, "Compiler_Directive", "compiler_", .[COMPILER_DIRECTIVES]);

    return builder_to_string(*b);
}

KEYWORD_MAP :: #run build_keyword_map();

build_keyword_map :: () -> Table(string, Token.Type) {
    table: Table(string, Token.Type);
    init(*table, KEYWORDS.count + TYPE_KEYWORDS.count + VALUE_KEYWORDS.count + COMPILER_DIRECTIVES.count);

    for KEYWORDS        table_add(*table, it, .keyword);
    for TYPE_KEYWORDS   table_add(*table, it, .type_keyword);
    for VALUE_KEYWORDS  table_add(*table, it, .value_keyword);
    for COMPILER_DIRECTIVES table_add(*table, it, .compiler_directive);

    return table;
}


#import "Hash_Table";
