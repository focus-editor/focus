highlight_hlsl_syntax :: (using buffer: *Buffer, start_offset := -1, count := -1) -> [] Buffer_Region {
    tokenizer := get_tokenizer(buffer, start_offset, count);

    last_token: Token;

    while true {
        token := get_next_token(*tokenizer);
        if token.type == .eof break;

        using tokenizer;
        // Maybe retroactively highlight a function
        if token.type == .punctuation && token.punctuation == .l_paren {
            // Handle "func("
            if last_token.type == .identifier {
                memset(colors.data + last_token.start, xx Color.CODE_FUNCTION, last_token.len);
            }
        }

        last_token = token;

        color := COLOR_MAP[token.type];
        memset(colors.data + token.start, xx color, token.len);
    }

    return .[];
}

get_next_hlsl_token :: get_next_token;  // export for indent tokenization

#scope_file

get_next_token :: (using tokenizer: *Tokenizer) -> Token {
    eat_white_space(tokenizer);

    token: Token;
    token.start = cast(s32) (t - buf.data);
    token.type  = .eof;
    if t >= max_t return token;

    start_t = t;

    // Look at the first char as if it's ASCII (if it isn't, this is just a text line)
    char := t.*;

    if is_alpha(char) || char == #char "_" {
        parse_identifier(tokenizer, *token);
    } else if is_digit(char) {
        parse_number(tokenizer, *token);
    } else if char == {
        case #char ":";  parse_colon                 (tokenizer, *token);
        case #char "?";  parse_question              (tokenizer, *token);
        case #char "=";  parse_equal                 (tokenizer, *token);
        case #char "-";  parse_minus                 (tokenizer, *token);
        case #char "+";  parse_plus                  (tokenizer, *token);
        case #char "*";  parse_asterisk              (tokenizer, *token);
        case #char "<";  parse_less_than             (tokenizer, *token);
        case #char ">";  parse_greater_than          (tokenizer, *token);
        case #char "!";  parse_bang                  (tokenizer, *token);
        case #char "#";  parse_preprocessor_directive(tokenizer, *token);
        case #char "\""; parse_string_literal        (tokenizer, *token);
        case #char "'";  parse_char_literal          (tokenizer, *token);
        case #char "/";  parse_slash_or_comment      (tokenizer, *token);
        case #char "&";  parse_ampersand             (tokenizer, *token);
        case #char "|";  parse_pipe                  (tokenizer, *token);
        case #char "%";  parse_percent               (tokenizer, *token);
        case #char "^";  parse_caret                 (tokenizer, *token);

        case #char ";";  token.type = .punctuation; token.punctuation = .semicolon; t += 1;
        case #char "\\"; token.type = .punctuation; token.punctuation = .backslash; t += 1;
        case #char ",";  token.type = .punctuation; token.punctuation = .comma;     t += 1;
        case #char ".";  token.type = .punctuation; token.punctuation = .period;    t += 1;
        case #char "{";  token.type = .punctuation; token.punctuation = .l_brace;   t += 1;
        case #char "}";  token.type = .punctuation; token.punctuation = .r_brace;   t += 1;
        case #char "(";  token.type = .punctuation; token.punctuation = .l_paren;   t += 1;
        case #char ")";  token.type = .punctuation; token.punctuation = .r_paren;   t += 1;
        case #char "[";  token.type = .punctuation; token.punctuation = .l_bracket; t += 1;
        case #char "]";  token.type = .punctuation; token.punctuation = .r_bracket; t += 1;

        case #char "~";  token.type = .operation;   token.operation   = .tilde;     t += 1;
        case #char "`";  token.type = .operation;   token.operation   = .backtick;  t += 1;

        case;            token.type = .invalid; t += 1;
    }

    if t >= max_t then t = max_t;
    token.len = cast(s32) (t - start_t);

    return token;
}

parse_identifier :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .identifier;

    identifier_str := read_identifier_string(tokenizer);

    // Maybe it's a keyword
    if identifier_str.count <= MAX_KEYWORD_LENGTH {
        kw_token, ok := table_find(*KEYWORD_MAP, identifier_str);
        if ok { token.type = kw_token.type; token.keyword = kw_token.keyword; return; }
    }
}

// TODO: simplify (this was copied from C). Also simplify for GLSL
parse_number :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .number;

    t += 1;
    if t >= max_t return;

    if is_digit(t.*) {
        // Decimal
        t += 1;
        seen_decimal_point := false;
        while t < max_t && (is_digit(t.*) || t.* == #char ".") {
            if t.* == #char "." {
                if seen_decimal_point break;
                seen_decimal_point = true;
            }
            t += 1;
        }
        if t >= max_t return;
        // t += 1;
        // if t >= max_t return;

        // exponent
        if t.* == #char "e" || t.* == #char "E" {
            t += 1;
            if t >= max_t return;

            if t.* == #char "+" || t.* == #char "-" {
              t += 1;
              if t >= max_t return;
            }

            while t < max_t && is_digit(t.*) {
                t += 1;
            }
            if t >= max_t return;
        }

        // suffixes
        if seen_decimal_point {
            if t.* == #char "f" || t.* == #char "F" || t.* == #char "d" || t.* == #char "D" {
              t += 1;
            }
        } else {

          // This is getting kindof hard to follow...
          if t.* == #char "l" || t.* == #char "L" {             // l
              t += 1;
              if t >= max_t return;

              if t.* == #char "l" || t.* == #char "L" {         // ll
                  t += 1;
                  if t >= max_t return;

                  if t.* == #char "u" || t.* == #char "U" {     // llu
                    t += 1;
                  }
              } else if t.* == #char "u" || t.* == #char "U" {  // lu
                t += 1;
              }
          } else if  t.* == #char "u" || t.* == #char "U" {     // u
              t += 1;
          }

        }

    } else if t.* == #char "x" || t.* == #char "X" {
        // Hex
        t += 1;
        while t < max_t && (is_hex(t.*)) t += 1;

    } else if t.* == #char "b" || t.* == #char "B" {
        // Binary
        t += 1;
        while t < max_t && (t.* == #char "1" || t.* == #char "0") t += 1;
    }
}

parse_colon :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .colon;
    t += 1;
}

parse_question :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .question;
    t += 1;
}

parse_equal :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .equal;

    t += 1;
    if t >= max_t return;

    if t.* == {
        case #char "=";  token.operation = .equal_equal; t += 1;
    }
}

parse_minus :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .minus;

    t += 1;
    if t >= max_t return;

    if t.* == {
        case #char "=";
            token.operation = .minus_equal;
            t += 1;
        case #char ">";
            token.operation = .arrow;
            t += 1;
        case #char "-";
            token.operation = .minus_minus;
            t += 1;
        case;
            if is_digit(t.*) parse_number(tokenizer, token);
    }
}

parse_plus :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .plus;

    t += 1;
    if t >= max_t return;

    if t.* == {
        case #char "=";
            token.operation = .plus_equal;
            t += 1;
        case #char "+";
            token.operation = .plus_plus;
            t += 1;
    }
}

parse_asterisk :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .asterisk;

    t += 1;
    if t >= max_t return;

    if t.* == {
        case #char "=";
            token.operation = .asterisk_equal;
            t += 1;
    }
}

parse_less_than :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .less_than;

    t += 1;
    if t >= max_t return;

    if t.* == {
        case #char "=";
            token.operation = .less_than_equal;
            t += 1;
        case #char "<";
            token.operation = .double_less_than;
            t += 1;
    }
}

parse_greater_than :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .greater_than;

    t += 1;
    if t >= max_t return;

    if t.* == {
        case #char "=";
            token.operation = .greater_than_equal;
            t += 1;
    }
}

parse_bang :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .bang;

    t += 1;
    if t >= max_t return;

    if t.* == {
        case #char "=";
            token.operation = .bang_equal;
            t += 1;
    }
}

parse_preprocessor_directive :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .identifier;

    t += 1;
    eat_white_space(tokenizer);  // there may be spaces between the # and the name
    if !is_alpha(t.*) return;

    directive_str := read_identifier_string(tokenizer);

    while t < max_t && is_alnum(t.*) t += 1;
    if t >= max_t return;

    // Check if it's one of the existing directives
    if directive_str.count > MAX_DIRECTIVE_LENGTH return;
    directive, ok := table_find(*PREPROCESSOR_DIRECTIVES_MAP, directive_str);
    if ok {
        token.type = .preprocessor_directive;
        token.preprocessor_directive = directive;
    }
}

parse_string_literal :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .string_literal;

    escape_seen := false;

    t += 1;
    while t < max_t && t.* != #char "\n" {
        if t.* == #char "\"" && !escape_seen break;
        escape_seen = !escape_seen && t.* == #char "\\";
        t += 1;
    }
    if t >= max_t return;

    t += 1;
}

parse_char_literal :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .char_literal;

    escape_seen := false;

    t += 1; //
    if t >= max_t || t.* == #char "\n" return;

    if t.* == #char "\\" {
      escape_seen = true;
      t += 1;
      if t >= max_t || t.* == #char "\n" return;
    }

    if t.* == #char "'" && !escape_seen {
      // not escaped single quote without a character
      token.type = .invalid;
      t += 1; // the invalid '
      return;
    }

    t += 1; // the char
    if t >= max_t || t.* == #char "\n" return;

    t += 1; // ending '
}

parse_slash_or_comment :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .slash;

    t += 1;
    if t >= max_t return;

    if t.* == {
        case #char "=";
            token.operation = .slash_equal;
            t += 1;
        case #char "/";
            token.type = .comment;
            t += 1;
            while t < max_t && t.* != #char "\n" t += 1;
        case #char "*";
            token.type = .multiline_comment;
            t += 1;
            while t + 1 < max_t {
                if t.* == #char "*" && (t + 1).* == #char "/" {
                  t += 2;
                  break;
                }
                t += 1;
            }
    }
}

parse_ampersand :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .ampersand;

    t += 1;
    if t >= max_t return;

    if t.* == {
        case #char "=";
            token.operation = .ampersand_equal;
            t += 1;
        case #char "&";
            token.operation = .double_ampersand;
            t += 1;
    }
}

parse_pipe :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .pipe;

    t += 1;
    if t >= max_t return;

    if t.* == {
        case #char "=";
            token.operation = .pipe_equal;
            t += 1;
        case #char "|";
            token.operation = .double_pipe;
            t += 1;
    }
}

parse_percent :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .percent;

    t += 1;
    if t >= max_t return;

    if t.* == {
        case #char "=";
            token.operation = .percent_equal;
            t += 1;
    }
}

parse_caret :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .caret;

    t += 1;
    if t >= max_t return;

    if t.* == {
        case #char "=";
            token.operation = .caret_equal;
            t += 1;
    }
}

Token :: struct {
    start, len: s32;
    type: Type;

    union {
        keyword:                Keyword;
        punctuation:            Punctuation;
        operation:              Operation;
        preprocessor_directive: Preprocessor_Directive;
    }

    Type :: enum u16 {
        eof;

        identifier;
        string_literal;
        char_literal;
        number;
        comment;
        multiline_comment;
        operation;
        punctuation;
        keyword;
        modifier_keyword;
        type_keyword;
        value_keyword;
        builtin_keyword;
        preprocessor_directive;
        invalid;
    }
}

// Must match the order of the types in the enum above
COLOR_MAP :: Color.[
    .CODE_COMMENT,       // eof - obviously not used
    .CODE_DEFAULT,       // identifier
    .CODE_STRING,        // string_literal
    .CODE_STRING,        // char_literal
    .CODE_VALUE,         // number
    .CODE_COMMENT,       // comment
    .CODE_COMMENT,       // multiline_comment
    .CODE_OPERATION,     // operation
    .CODE_PUNCTUATION,   // punctuation
    .CODE_KEYWORD,       // keyword
    .CODE_KEYWORD,       // modifier_keyword
    .CODE_TYPE,          // type_keyword
    .CODE_VALUE,         // value_keyword
    .CODE_VALUE,         // builtin_keyword
    .CODE_KEYWORD,       // preprocessor_directive
    .CODE_ERROR,         // invalid
];

PUNCTUATION :: string.[
    "semicolon", "backslash", "l_paren", "r_paren", "l_brace", "r_brace", "l_bracket", "r_bracket", "period", "comma",
];

OPERATIONS :: string.[
    "arrow", "bang", "backtick", "pipe", "double_pipe", "pipe_equal", "equal", "equal_equal", "bang_equal", "percent",
    "percent_equal", "less_than", "double_less_than", "less_than_equal", "greater_than", "greater_than_equal",
    "minus", "minus_equal", "minus_minus", "asterisk", "asterisk_equal", "colon", "slash", "plus", "plus_equal", "plus_plus",
    "slash_equal", "ampersand", "double_ampersand", "ampersand_equal", "tilde", "question", "unknown", "caret", "caret_equal",
];

KEYWORDS :: string.[
    // "unroll", "loop", "flatten", "branch", "numthreads",  // NOTE: these are in brackets, but we don't parse them with brackets yet
    "struct", "technique", "pass", "while", "for", "do", "if", "else", "switch", "case", "default", "break", "continue",
    "return", "discard", "static", "inline", "extern", "volatile", "uniform", "shared", "groupshared", "register", "packoffset",
    "numthreads", "branch", "flatten", "unroll", "loop", "nointerpolation", "linear", "sample", "centroid", "noperspective",
    "cbuffer", "tbuffer",
];

TYPE_KEYWORDS :: string.[
    "bool", "int", "uint", "half", "float", "double", "min16float", "min10float", "min16int", "min12int", "min16uint",
    "bool1", "bool2", "bool3", "bool4", "int1", "int2", "int3", "int4", "uint1", "uint2", "uint3", "uint4",
    "half1", "half2", "half3", "half4", "float1", "float2", "float3", "float4", "double1", "double2", "double3", "double4",
    "min16float1", "min16float2", "min16float3", "min16float4", "min10float1", "min10float2", "min10float3", "min10float4",
    "min16int1", "min16int2", "min16int3", "min16int4", "min12int1", "min12int2", "min12int3", "min12int4", "min16uint1",
    "min16uint2", "min16uint3", "min16uint4", "matrix", "float1x1", "float1x2", "float1x3", "float1x4", "float2x1", "float2x2",
    "float2x3", "float2x4", "float3x1", "float3x2", "float3x3", "float3x4", "float4x1", "float4x2", "float4x3", "float4x4",
    "double1x1", "double1x2", "double1x3", "double1x4", "double2x1", "double2x2", "double2x3", "double2x4", "double3x1",
    "double3x2", "double3x3", "double3x4", "double4x1", "double4x2", "double4x3", "double4x4", "Texture1D", "Texture1DArray",
    "Texture2D", "Texture2DArray", "Texture3D", "TextureCube", "TextureCubeArray", "Buffer", "StructuredBuffer",
    "ByteAddressBuffer", "RWTexture1D", "RWTexture1DArray", "RWTexture2D", "RWTexture2DArray", "RWTexture3D", "RWBuffer",
    "RWStructuredBuffer", "RWByteAddressBuffer", "AppendStructuredBuffer", "ConsumeStructuredBuffer", "SamplerState", "SamplerComparisonState",
    "snorm", "unorm",
    "SV_POSITION", "SV_TARGET", "SV_DEPTH", "SV_COVERAGE", "SV_VERTEXID", "SV_PRIMITIVEID", "SV_INSTANCEID",
    "SV_DISPATCHTHREADID", "SV_GROUPTHREADID", "SV_GROUPID", "SV_DOMAINLOCATION", "SV_ISFRONTFACE", "SV_SAMPLEINDEX",
    "SV_VIEWPORTARRAYINDEX", "SV_RENDERTARGETARRAYINDEX", "SV_DEPTHGREATEREQUAL", "SV_DEPTHLESSEQUAL",
    "SV_VertexID", "SV_InstanceID", "SV_PrimitiveID", "SV_DomainLocation", "SV_Position", "SV_IsFrontFace", "SV_Depth", "SV_Target",
    "SV_Coverage", "SV_SampleIndex", "SV_DispatchThreadID", "SV_GroupID", "SV_GroupIndex", "SV_GroupThreadID",
];

VALUE_KEYWORDS :: string.[
    "true", "false", "null", "void",
];

PREPROCESSOR_DIRECTIVES :: string.[
    "define", "undef", "if", "ifdef", "ifndef", "else", "elif", "endif", "include", "error", "pragma", "line",
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

    define_enum(*b, "Punctuation",            "",           .[PUNCTUATION]);
    define_enum(*b, "Operation",              "",           .[OPERATIONS]);
    define_enum(*b, "Keyword",                "kw_",        .[KEYWORDS, TYPE_KEYWORDS, VALUE_KEYWORDS]);
    define_enum(*b, "Preprocessor_Directive", "directive_", .[PREPROCESSOR_DIRECTIVES]);

    return builder_to_string(*b);
}

Keyword_Token :: struct {
    type: Token.Type;
    keyword: Keyword;
}

KEYWORD_MAP :: #run -> Table(string, Keyword_Token) {
    table: Table(string, Keyword_Token);
    size := 10 * (KEYWORDS.count + TYPE_KEYWORDS.count + VALUE_KEYWORDS.count);
    init(*table, size);

    #insert -> string {
        b: String_Builder;
        for KEYWORDS        append(*b, sprint("table_add(*table, \"%1\", Keyword_Token.{ type = .keyword,       keyword = .kw_%1 });\n", it));
        for TYPE_KEYWORDS   append(*b, sprint("table_add(*table, \"%1\", Keyword_Token.{ type = .type_keyword,  keyword = .kw_%1 });\n", it));
        for VALUE_KEYWORDS  append(*b, sprint("table_add(*table, \"%1\", Keyword_Token.{ type = .value_keyword, keyword = .kw_%1 });\n", it));
        return builder_to_string(*b);
    }

    return table;
}

PREPROCESSOR_DIRECTIVES_MAP :: #run -> Table(string, Preprocessor_Directive) {
    table: Table(string, Preprocessor_Directive);
    size := 2 * PREPROCESSOR_DIRECTIVES.count;
    init(*table, size);

    #insert -> string {
        b: String_Builder;
        init_string_builder(*b);
        for PREPROCESSOR_DIRECTIVES {
            print_to_builder(*b, "table_add(*table, \"%1\", .directive_%1);\n", it);
        }
        return builder_to_string(*b);
    }

    return table;
}

MAX_KEYWORD_LENGTH :: #run -> s32 {
    result: s64;
    for KEYWORDS       { if it.count > result then result = it.count; }
    for TYPE_KEYWORDS  { if it.count > result then result = it.count; }
    for VALUE_KEYWORDS { if it.count > result then result = it.count; }
    return xx result;
}

MAX_DIRECTIVE_LENGTH :: #run -> s32 {
    result: s64;
    for PREPROCESSOR_DIRECTIVES { if it.count > result then result = it.count; }
    return xx result;
}


#run assert(enum_highest_value(Token.Type) == COLOR_MAP.count - 1);
