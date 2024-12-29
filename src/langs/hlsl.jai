tokenize_hlsl :: (using buffer: *Buffer, start_offset := -1, count := -1) -> [] Buffer_Region {
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
                memset(tokens.data + last_token.start, xx Token_Type.function, last_token.len);
            }
        }

        last_token = token;

        memset(tokens.data + token.start, xx token.type, token.len);
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
        parse_number_c_like(tokenizer, *token);
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
        case #char "#";  parse_directive             (tokenizer, *token);
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

    // Or maybe it's a semantic
    if identifier_str.count <= MAX_SEMANTIC_LENGTH {
        // Semantics may have an index in the end
        pure_semantic_name := trim_right(identifier_str, "0123456789");
        if !pure_semantic_name return;

        // They are also case insensitive
        pure_semantic_name = to_lower_copy(pure_semantic_name,, allocator = temp);

        semantic, ok := table_find(*SEMANTICS_MAP, pure_semantic_name);
        if ok { token.type = .keyword; token.semantic = semantic; return; }
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
            if is_digit(t.*) parse_number_c_like(tokenizer, token);
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

parse_directive :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .identifier;

    t += 1;
    eat_white_space(tokenizer);  // there may be spaces between the # and the name
    if !is_alpha(t.*) return;

    directive_str := read_identifier_string(tokenizer);

    while t < max_t && is_alnum(t.*) t += 1;
    if t >= max_t return;

    // Check if it's one of the existing directives
    if directive_str.count > MAX_DIRECTIVE_LENGTH return;
    directive, ok := table_find(*DIRECTIVES_MAP, directive_str);
    if ok {
        token.type = .directive;
        token.directive = directive;
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
    type: Token_Type;

    union {
        keyword:        Keyword;
        punctuation:    Punctuation;
        operation:      Operation;
        directive:      Directive;
        semantic:       Semantic;
    }
}

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
    "struct", "technique", "pass", "while", "for", "do", "if", "else", "switch", "case", "default", "break", "continue",
    "return", "discard", "typedef", "cbuffer", "tbuffer",
];

MODIFIER_KEYWORDS :: string.[
    "extern", "precise", "shared", "groupshared", "static", "uniform", "volatile", "inline",
    "const", "row_major", "column_major",
    "packoffset", "register",
    "linear", "centroid", "nointerpolation", "noperspective", "sample",
    "in", "inout", "out",
    "snorm", "unorm",
    // NOTE: these are in brackets, but we don't parse them with brackets yet
    "numthreads", "branch", "flatten", "unroll", "loop",
];

#insert -> string {
    builder : String_Builder;
    append(*builder, "TYPE_KEYWORDS :: string.[\n");

    SCALAR_TYPES :: string.[
        "bool", "int", "uint", "dword", "half", "float", "double",
        "min16float", "min10float", "min16int", "min12int", "min16uint",
        "int16_t", "int32_t", "int64_t", "uint16_t", "uint32_t", "uint64_t", "float16_t", "float32_t", "float64_t",
    ];
    for SCALAR_TYPES print(*builder, "    \"%\",\n", it);

VOID_AND_STRING :: #string END
    "void",
    "string",

END;
    append(*builder, VOID_AND_STRING);

    append(*builder, "    \"vector\",\n");
    for scalar : SCALAR_TYPES {
        append(*builder, "   ");
        for 1 .. 4 {
            print(*builder, " \"%0%\",", scalar, it);
        }
        append(*builder, "\n");
    }
    append(*builder, "\n");

    append(*builder, "    \"matrix\",\n");
    for scalar : SCALAR_TYPES {
        for i : 1 .. 4 {
            append(*builder, "   ");
            for j : 1 .. 4 {
                print(*builder, " \"%0%x%\",", scalar, i, j);
            }
            append(*builder, "\n");
        }
    }
    append(*builder, "\n");

BUFFER_TYPES :: #string END
    "Buffer",
    "ConstantBuffer",
    "StructuredBuffer",
    "ByteAddressBuffer",
    "RWBuffer",
    "RWStructuredBuffer",
    "RWByteAddressBuffer",
    "AppendStructuredBuffer",
    "ConsumeStructuredBuffer",

END;
    append(*builder, BUFFER_TYPES);

TEXTURE_TYPES :: #string END
    "texture",
    "Texture1D", "Texture1DArray",
    "Texture2D", "Texture2DArray",
    "Texture3D",
    "TextureCube", "TextureCubeArray",
    "Texture2DMS", "Texture2DMSArray",
    "RWTexture1D", "RWTexture1DArray",
    "RWTexture2D", "RWTexture2DArray",
    "RWTexture3D",

END;
    append(*builder, TEXTURE_TYPES);

SAMPLER_TYPES :: #string END
    "sampler", "sampler1D", "sampler2D", "sampler3D", "samplerCUBE",
    "sampler_state",
    "SamplerState", "SamplerComparisonState",

END;
    append(*builder, SAMPLER_TYPES);

STATE_TYPES :: #string END
    "StateObjectConfig",
    "GlobalRootSignature",
    "LocalRootSignature",
    "SubobjectToExportsAssocation",
    "RaytracingShaderConfig",
    "RaytracingPipelineConfig",
    "TriangleHitGroup",
    "ProceduralPrimitiveHitGroup",

END;
    append(*builder, STATE_TYPES);

RTX_TYPES :: #string END
    "RaytracingAccelerationStructure",
END;
    append(*builder, RTX_TYPES);

    append(*builder, "];");
    return builder_to_string(*builder);
}

// @Important: Should be in lower case since they are case insensitive
SYSTEM_VALUE_SEMANTICS :: string.[
    "sv_clipdistance",
    "sv_culldistance",
    "sv_coverage",
    "sv_depth",
    "sv_depthgreaterequal",
    "sv_depthlessequal",
    "sv_dispatchthreadid",
    "sv_domainlocation",
    "sv_groupid",
    "sv_groupindex",
    "sv_groupthreadid",
    "sv_gsinstanceid",
    "sv_innercoverage",
    "sv_insidetessfactor",
    "sv_instanceid",
    "sv_isfrontface",
    "sv_outputcontrolpointid",
    "sv_position",
    "sv_primitiveid",
    "sv_rendertargetarrayindex",
    "sv_sampleindex",
    "sv_stencilref",
    "sv_target",
    "sv_tessfactor",
    "sv_vertexid",
    "sv_viewportarrayindex",
    "sv_shadingrate",
];

VALUE_KEYWORDS :: string.[
    "true", "false", "null",
];

PREPROCESSOR_DIRECTIVES :: string.[
    "define", "undef", "if", "ifdef", "ifndef", "else", "elif", "endif", "include", "error", "pragma", "line",
];

#insert -> string {
    b: String_Builder;

    Prefix_And_Values :: struct {
        prefix : string;
        values : [] string;
    }

    define_enum :: (b: *String_Builder, enum_name: string, prefix_and_values: [] Prefix_And_Values) {
        print_to_builder(b, "% :: enum u16 {", enum_name);
        for pav : prefix_and_values {
            append(b, "\n");
            for pav.values print(b, "    %0%;\n", pav.prefix, it);
        }
        print_to_builder(b, "}\n");
    }

    define_enum(*b, "Punctuation",            .[.{"", PUNCTUATION}]);
    define_enum(*b, "Operation",              .[.{"", OPERATIONS}]);
    define_enum(*b, "Keyword",                .[.{"kw_", KEYWORDS}, .{"kwm_", MODIFIER_KEYWORDS}, .{"kwt_", TYPE_KEYWORDS}, .{"kwv_", VALUE_KEYWORDS}]);
    define_enum(*b, "Directive", .[.{"directive_", PREPROCESSOR_DIRECTIVES}]);
    define_enum(*b, "Semantic",               .[.{"", SYSTEM_VALUE_SEMANTICS}]);

    return builder_to_string(*b);
}

Keyword_Token :: struct {
    type: Token_Type;
    keyword: Keyword;
}

KEYWORD_MAP :: #run,stallable -> Table(string, Keyword_Token) {
    table: Table(string, Keyword_Token);
    size := 10 * (KEYWORDS.count + TYPE_KEYWORDS.count + VALUE_KEYWORDS.count);
    init(*table, size);

    #insert -> string {
        b: String_Builder;
        for KEYWORDS          print(*b, "table_add(*table, \"%1\", Keyword_Token.{ type = .keyword,  keyword = .kw_%1  });\n", it);
        for MODIFIER_KEYWORDS print(*b, "table_add(*table, \"%1\", Keyword_Token.{ type = .modifier, keyword = .kwm_%1 });\n", it);
        for TYPE_KEYWORDS     print(*b, "table_add(*table, \"%1\", Keyword_Token.{ type = .type,     keyword = .kwt_%1 });\n", it);
        for VALUE_KEYWORDS    print(*b, "table_add(*table, \"%1\", Keyword_Token.{ type = .value,    keyword = .kwv_%1 });\n", it);
        return builder_to_string(*b);
    }

    return table;
}

SEMANTICS_MAP :: #run -> Table(string, Semantic) {
    table: Table(string, Semantic);
    init(*table, 10 * SYSTEM_VALUE_SEMANTICS.count);

    #insert -> string {
        b: String_Builder;
        for SYSTEM_VALUE_SEMANTICS print(*b, "table_add(*table, \"%1\", .%1);\n", it);
        return builder_to_string(*b);
    }

    return table;
}

DIRECTIVES_MAP :: #run -> Table(string, Directive) {
    table: Table(string, Directive);
    size := 2 * PREPROCESSOR_DIRECTIVES.count;
    init(*table, size);

    #insert -> string {
        b: String_Builder;
        for PREPROCESSOR_DIRECTIVES print(*b, "table_add(*table, \"%1\", .directive_%1);\n", it);
        return builder_to_string(*b);
    }

    return table;
}

MAX_KEYWORD_LENGTH :: #run,stallable -> s32 {
    result: s64;
    for KEYWORDS          { if it.count > result then result = it.count; }
    for MODIFIER_KEYWORDS { if it.count > result then result = it.count; }
    for TYPE_KEYWORDS     { if it.count > result then result = it.count; }
    for VALUE_KEYWORDS    { if it.count > result then result = it.count; }
    return xx result;
}

MAX_SEMANTIC_LENGTH :: #run -> s32 {
    result: s64;
    // +2 because semantics may have two-digit number in the end
    for SYSTEM_VALUE_SEMANTICS { if it.count + 2 > result then result = it.count + 2; }
    return xx result;
}

MAX_DIRECTIVE_LENGTH :: #run -> s32 {
    result: s64;
    for PREPROCESSOR_DIRECTIVES { if it.count > result then result = it.count; }
    return xx result;
}

