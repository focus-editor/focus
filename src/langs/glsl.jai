tokenize_glsl :: (using buffer: *Buffer, start_offset := -1, count := -1) -> [] Buffer_Region {
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

        highlight_token(buffer, token);
    }

    return .[];
}

get_next_glsl_token :: get_next_token;  // export for indent tokenization

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
    using #as base: Base_Token;

    union {
        keyword:        Keyword;
        punctuation:    Punctuation;
        operation:      Operation;
        directive:      Directive;
    }
}

PUNCTUATION :: string.[
    "semicolon", "backslash", "l_paren", "r_paren", "l_brace", "r_brace", "l_bracket", "r_bracket", "period", "comma",
];

OPERATIONS :: string.[
    "arrow", "bang", "backtick", "pipe", "double_pipe", "pipe_equal", "equal", "equal_equal", "bang_equal", "percent",
    "percent_equal", "less_than", "double_less_than", "less_than_equal", "greater_than", "greater_than_equal", "minus",
    "minus_equal", "minus_minus", "asterisk", "asterisk_equal", "colon", "slash", "plus", "plus_equal", "plus_plus",
    "slash_equal", "ampersand", "double_ampersand", "ampersand_equal", "tilde", "question", "unknown", "caret", "caret_equal",
];

KEYWORDS :: string.[
    "break", "case", "compatibility", "continue", "core", "default", "defined", "disable", "discard", "else", "enable",
    "enum", "for", "if", "layout", "require", "restrict", "return", "sizeof", "struct", "switch",
    "typedef", "union", "uniform", "warn", "while",
];

TYPE_KEYWORDS :: string.[
    // built-in types
    "atomic_uint", "bool", "double", "float", "int", "uint", "void",

    // vector types
    "bvec2", "bvec3", "bvec4", "dvec2", "dvec3", "dvec4", "ivec2", "ivec3", "ivec4", "uvec2", "uvec3", "uvec4", "vec2", "vec3", "vec4",

    // matrix types
    "mat2", "mat3", "mat4", "mat2x2", "mat2x3", "mat2x4", "mat3x2", "mat3x3", "mat3x4", "mat4x2", "mat4x3", "mat4x4", "dmat2", "dmat3", "dmat4", "dmat2x2", "dmat2x3", "dmat2x4", "dmat3x2", "dmat3x3", "dmat3x4", "dmat4x2", "dmat4x3", "dmat4x4",

    // image types
    "image1D", "image2D", "image3D", "imageCube", "image2DRect", "image1DArray", "image2DArray", "imageCubeArray", "imageBuffer", "image2DMS", "image2DMSArray",
    "iimage1D", "iimage2D", "iimage3D", "iimageCube", "iimage2DRect", "iimage1DArray", "iimage2DArray", "iimageCubeArray", "iimageBuffer", "iimage2DMS", "iimage2DMSArray",
    "uimage1D", "uimage2D", "uimage3D", "uimageCube", "uimage2DRect", "uimage1DArray", "uimage2DArray", "uimageCubeArray", "uimageBuffer", "uimage2DMS", "uimage2DMSArray",

    // GL_KHR_vulkan_glsl texture types
    "texture1D", "texture2D", "texture3D", "textureCube", "texture1DArray", "texture2DArray", "textureCubeArray", "textureBuffer", "texture2DMS", "texture2DMSArray",
    "itexture1D", "itexture2D", "itexture3D", "itextureCube", "itexture1DArray", "itexture2DArray", "itextureCubeArray", "itextureBuffer", "itexture2DMS", "itexture2DMSArray",
    "utexture1D", "utexture2D", "utexture3D", "utextureCube", "utexture1DArray", "utexture2DArray", "utextureCubeArray", "utextureBuffer", "utexture2DMS", "utexture2DMSArray",

    // sampler types
    "sampler", "sampler1D", "sampler2D", "sampler3D", "samplerCube", "sampler2DRect", "sampler1DArray", "sampler2DArray", "samplerCubeArray", "samplerBuffer", "sampler2DMS", "sampler2DMSArray",
    "isampler1D", "isampler2D", "isampler3D", "isamplerCube", "isampler2DRect", "isampler1DArray", "isampler2DArray", "isamplerCubeArray", "isamplerBuffer", "isampler2DMS", "isampler2DMSArray",
    "usampler1D", "usampler2D", "usampler3D", "usamplerCube", "usampler2DRect", "usampler1DArray", "usampler2DArray", "usamplerCubeArray", "usamplerBuffer", "usampler2DMS", "usampler2DMSArray",

    // shadow sampler types
    "samplerShadow", "sampler1DShadow", "sampler2DShadow", "samplerCubeShadow", "sampler2DRectShadow", "sampler1DArrayShadow", "sampler2DArrayShadow", "samplerCubeArrayShadow",

    // GL_KHR_vulkan_glsl input attachment types
    "subpassInput", "isubpassInput", "usubpassInput", "subpassInputMS", "isubpassInputMS", "usubpassInputMS",

    // GL_EXT_shader_explicit_arithmetic_types
    "float64_t", "f64vec2", "f64vec3", "f64vec4", "f64mat2", "f64mat3", "f64mat4", "f64mat2x2", "f64mat2x3", "f64mat2x4", "f64mat3x2", "f64mat3x3", "f64mat3x4", "f64mat4x2", "f64mat4x3", "f64mat4x4",
    "float32_t", "f32vec2", "f32vec3", "f32vec4", "f32mat2", "f32mat3", "f32mat4", "f32mat2x2", "f32mat2x3", "f32mat2x4", "f32mat3x2", "f32mat3x3", "f32mat3x4", "f32mat4x2", "f32mat4x3", "f32mat4x4",
    "float16_t", "f16vec2", "f16vec3", "f16vec4", "f16mat2", "f16mat3", "f16mat4", "f16mat2x2", "f16mat2x3", "f16mat2x4", "f16mat3x2", "f16mat3x3", "f16mat3x4", "f16mat4x2", "f16mat4x3", "f16mat4x4",
    "int64_t",   "i64vec2", "i64vec3", "i64vec4",
    "uint64_t",  "u64vec2", "u64vec3", "u64vec4",
    "int32_t",   "i32vec2", "i32vec3", "i32vec4",
    "uint32_t",  "u32vec2", "u32vec3", "u32vec4",
    "int16_t",   "i16vec2", "i16vec3", "i16vec4",
    "uint16_t",  "u16vec2", "u16vec3", "u16vec4",
    "int8_t",    "i8vec2",  "i8vec3",  "i8vec4",
    "uint8_t",   "u8vec2",  "u8vec3",  "u8vec4",
];

VALUE_KEYWORDS :: string.[
    "true", "false",
];

MODIFIER_KEYWORDS :: string.[
    "buffer", "centroid", "coherent", "const", "flat", "highp", "in", "inout", "invariant", "lowp", "mediump", "noperspective",
    "out", "patch", "precise", "precision", "readonly", "sample", "shared", "smooth", "volatile", "writeonly",
];

BUILTIN_VARS :: string.[
    "gl_in", "gl_out", "gl_BaseVertex", "gl_BaseInstance", "gl_ClipDistance", "gl_CullDistance", "gl_DrawID", "gl_DepthRangeParameters",
    "gl_DepthRange", "gl_FragCoord", "gl_FragDepth", "gl_FrontFacing", "gl_GlobalInvocationID", "gl_HelperInvocation", "gl_InstanceID",
    "gl_InvocationID", "gl_Layer", "gl_LocalInvocationID", "gl_LocalInvocationIndex", "gl_NumSamples", "gl_NumWorkGroups",
    "gl_PatchVerticesIn", "gl_PerVertex", "gl_Position", "gl_PointCoord", "gl_PointSize", "gl_PrimitiveID", "gl_PrimitiveIDIn",
    "gl_SampleID", "gl_SamplePosition", "gl_SampleMask", "gl_SampleMaskIn", "gl_TessLevelOuter", "gl_TessLevelInner", "gl_TessCoord",
    "gl_VertexID", "gl_ViewportIndex", "gl_WorkGroupID", "gl_WorkGroupSize",

    // GL_KHR_vulkan_glsl built-in variables
    "gl_VertexIndex", "gl_InstanceIndex",

    // built-in constants
    "gl_MaxClipDistances", "gl_MaxDrawBuffers", "gl_MaxImageSamples", "gl_MaxImageUnits", "gl_MaxPatchVertices", "gl_MinProgramTexelOffset",
    "gl_MaxProgramTexelOffset", "gl_MaxTessGenLevel", "gl_MaxTessPatchComponents", "gl_MaxTextureImageUnits",
    "gl_MaxTransformFeedbackBuffers", "gl_MaxTransformFeedbackInterleavedComponents", "gl_MaxVaryingVectors", "gl_MaxViewports",
    "gl_MaxAtomicCounterBindings", "gl_MaxAtomicCounterBufferSize", "gl_MaxCombinedAtomicCounters", "gl_MaxCombinedAtomicCounterBuffers",
    "gl_MaxCombinedImageUniforms", "gl_MaxCombinedImageUnitsAndFragmentOutputs", "gl_MaxCombinedTextureImageUnits",
    "gl_MaxComputeWorkGroupCount", "gl_MaxComputeWorkGroupSize", "gl_MaxComputeUniformComponents", "gl_MaxComputeTextureImageUnits",
    "gl_MaxComputeImageUniforms", "gl_MaxComputeAtomicCounters", "gl_MaxComputeAtomicCounterBuffers", "gl_MaxFragmentAtomicCounters",
    "gl_MaxFragmentAtomicCounterBuffers", "gl_MaxFragmentImageUniforms", "gl_MaxFragmentInputComponents", "gl_MaxFragmentUniformComponents",
    "gl_MaxFragmentUniformVectors", "gl_MaxGeometryAtomicCounters", "gl_MaxGeometryAtomicCounterBuffers", "gl_MaxGeometryImageUniforms",
    "gl_MaxGeometryInputComponents", "gl_MaxGeometryOutputComponents", "gl_MaxGeometryOutputVertices", "gl_MaxGeometryTextureImageUnits",
    "gl_MaxGeometryTotalOutputComponents", "gl_MaxGeometryUniformComponents", "gl_MaxGeometryVaryingComponents",
    "gl_MaxTessControlAtomicCounterBuffers", "gl_MaxTessControlAtomicCounters", "gl_MaxTessControlImageUniforms",
    "gl_MaxTessControlInputComponents", "gl_MaxTessControlOutputComponents", "gl_MaxTessControlUniformComponents",
    "gl_MaxTessControlTextureImageUnits", "gl_MaxTessControlTotalOutputComponents", "gl_MaxTessEvaluationAtomicCounters",
    "gl_MaxTessEvaluationAtomicCounterBuffers", "gl_MaxTessEvaluationImageUniforms", "gl_MaxTessEvaluationInputComponents",
    "gl_MaxTessEvaluationOutputComponents", "gl_MaxTessEvaluationUniformComponents", "gl_MaxTessEvaluationTextureImageUnits",
    "gl_MaxVertexAtomicCounters", "gl_MaxVertexAtomicCounterBuffers", "gl_MaxVertexAttribs", "gl_MaxVertexImageUniforms",
    "gl_MaxVertexOutputComponents", "gl_MaxVertexTextureImageUnits", "gl_MaxVertexUniformComponents", "gl_MaxVertexUniformVectors",
];

DIRECTIVES :: string.[
    "define", "elif", "elifdef", "elifndef", "else", "endif", "error", "extension", "if", "ifdef", "ifndef", "line", "pragma",
    "undef", "warning", "version",
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

    define_enum(*b, "Punctuation",  "",    .[PUNCTUATION]);
    define_enum(*b, "Operation",    "",    .[OPERATIONS]);
    define_enum(*b, "Keyword",      "kw_", .[KEYWORDS, TYPE_KEYWORDS, VALUE_KEYWORDS, MODIFIER_KEYWORDS, BUILTIN_VARS]);
    define_enum(*b, "Directive",    "di_", .[DIRECTIVES]);

    return builder_to_string(*b);
}

Keyword_Token :: struct {
    type: Token_Type;
    keyword: Keyword;
}

KEYWORD_MAP :: #run -> Table(string, Keyword_Token) {
    table: Table(string, Keyword_Token);
    size := 10 * (KEYWORDS.count + TYPE_KEYWORDS.count + VALUE_KEYWORDS.count);
    init(*table, size);

    #insert -> string {
        b: String_Builder;
        for KEYWORDS           append(*b, sprint("table_add(*table, \"%1\", Keyword_Token.{ type = .keyword,          keyword = .kw_%1 });\n", it));
        for TYPE_KEYWORDS      append(*b, sprint("table_add(*table, \"%1\", Keyword_Token.{ type = .type,             keyword = .kw_%1 });\n", it));
        for VALUE_KEYWORDS     append(*b, sprint("table_add(*table, \"%1\", Keyword_Token.{ type = .value,            keyword = .kw_%1 });\n", it));
        for MODIFIER_KEYWORDS  append(*b, sprint("table_add(*table, \"%1\", Keyword_Token.{ type = .modifier,         keyword = .kw_%1 });\n", it));
        for BUILTIN_VARS       append(*b, sprint("table_add(*table, \"%1\", Keyword_Token.{ type = .builtin_variable, keyword = .kw_%1 });\n", it));
        return builder_to_string(*b);
    }

    return table;
}

DIRECTIVES_MAP :: #run -> Table(string, Directive) {
    table: Table(string, Directive);
    size := 2 * DIRECTIVES.count;
    init(*table, size);

    #insert -> string {
        b: String_Builder;
        init_string_builder(*b);
        for DIRECTIVES {
            print_to_builder(*b, "table_add(*table, \"%1\", .di_%1);\n", it);
        }
        return builder_to_string(*b);
    }

    return table;
}

MAX_KEYWORD_LENGTH :: #run -> s32 {
    result: s64;
    for KEYWORDS          { if it.count > result then result = it.count; }
    for TYPE_KEYWORDS     { if it.count > result then result = it.count; }
    for VALUE_KEYWORDS    { if it.count > result then result = it.count; }
    for MODIFIER_KEYWORDS { if it.count > result then result = it.count; }
    for BUILTIN_VARS      { if it.count > result then result = it.count; }
    return xx result;
}

MAX_DIRECTIVE_LENGTH :: #run -> s32 {
    result: s64;
    for DIRECTIVES { if it.count > result then result = it.count; }
    return xx result;
}
