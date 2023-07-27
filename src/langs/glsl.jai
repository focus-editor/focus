highlight_glsl_syntax :: (using buffer: *Buffer) {
    tokenizer: Tokenizer = ---;
    tokenizer.buf   = to_string(bytes);
    tokenizer.max_t = bytes.data + bytes.count;
    tokenizer.t     = bytes.data;

    while true {
        token := get_next_token(*tokenizer);
        if token.type == .eof break;

        using tokenizer;
        // Maybe retroactively highlight a function
        if token.type == .punctuation && token.punctuation == .l_paren {
            // Handle "func("
            prev := last_tokens[0];
            if prev.type == .identifier {
                memset(colors.data + prev.start, xx Code_Color.FUNCTION, prev.len);
            }
        }

        // Remember last tokens
        last_tokens[0] = token;


        color := COLOR_MAP[token.type];
        memset(colors.data + token.start, xx color, token.len);
    }
}

#scope_file

get_next_token :: (using tokenizer: *Tokenizer) -> Token {
    t = eat_white_space(t, max_t);

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

    // mark := get_temporary_storage_mark();
    // defer   set_temporary_storage_mark(mark);

    identifier_str := read_identifier_string(tokenizer);

    // Maybe it's a keyword
    if identifier_str.count <= MAX_KEYWORD_LENGTH {
        kw_token, ok := table_find(*KEYWORD_MAP, identifier_str);
        if ok { token.type = kw_token.type; token.keyword = kw_token.keyword; return; }
    }
}

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
        is_hex :: inline (c: u8) -> bool {
            return is_digit(c) || (c >= #char "a" && c <= #char "f") || (c >= #char "A" && c <= #char "F");
        }

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
    t = eat_white_space(t, max_t);  // there may be spaces between the # and the name
    if !is_alpha(t.*) return;

    // mark := get_temporary_storage_mark();
    // defer   set_temporary_storage_mark(mark);

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

//~

Tokenizer :: struct {
    buf: string;
    max_t:   *u8;
    start_t: *u8;  // cursor when starting parsing new token
    t:       *u8;  // cursor

    last_tokens: [1] Token;  // to retroactively highlight functions
}

Token :: struct {
    start, len: s32;
    type: Type;

    union {
        keyword:            Keyword;
        punctuation:        Punctuation;
        operation:          Operation;
        preprocessor_directive: Directive;
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
COLOR_MAP :: Code_Color.[
    .COMMENT,       // eof - obviously not used
    .DEFAULT,       // identifier
    .STRING,        // string_literal
    .STRING,        // char_literal
    .VALUE,         // number
    .COMMENT,       // comment
    .COMMENT,       // multiline_comment
    .OPERATION,     // operation
    .PUNCTUATION,   // punctuation
    .KEYWORD,       // keyword
    .KEYWORD,       // modifier_keyword
    .TYPE,          // type_keyword
    .VALUE_KEYWORD, // value_keyword
    .VALUE_KEYWORD, // builtin_keyword
    .KEYWORD,       // preprocessor_directive
    .ERROR,         // invalid
];

Keyword :: enum u16 {
    kw_break;
    kw_case;
    kw_compatibility;
    kw_continue;
    kw_core;
    kw_default;
    kw_defined;
    kw_disable;
    kw_discard;
    kw_else;
    kw_enable;
    kw_enum;
    kw_for;
    kw_if;
    kw_in;
    kw_inout;
    kw_layout;
    kw_out;
    kw_require;
    kw_restrict;
    kw_return;
    kw_sizeof;
    kw_struct;
    kw_switch;
    kw_typedef;
    kw_union;
    kw_uniform;
    kw_warn;
    kw_while;

    kwv_false;
    kwv_true;

    // modifiers
    kwm_buffer;
    kwm_centroid;
    kwm_coherent;
    kwm_const;
    kwm_flat;
    kwm_highp;
    kwm_in;
    kwm_inout;
    kwm_invariant;
    kwm_lowp;
    kwm_mediump;
    kwm_noperspective;
    kwm_out;
    kwm_patch;
    kwm_precise;
    kwm_precision;
    kwm_readonly;
    kwm_restrict;
    kwm_sample;
    kwm_shared;
    kwm_smooth;
    kwm_uniform;
    kwm_volatile;
    kwm_writeonly;

    // built-in types
    kwt_atomic_uint;
    kwt_bool;
    kwt_double;
    kwt_float;
    kwt_int;
    kwt_uint;
    kwt_void;

    // vector types
    kwt_bvec2;
    kwt_bvec3;
    kwt_bvec4;
    kwt_dvec2;
    kwt_dvec3;
    kwt_dvec4;
    kwt_ivec2;
    kwt_ivec3;
    kwt_ivec4;
    kwt_uvec2;
    kwt_uvec3;
    kwt_uvec4;
    kwt_vec2;
    kwt_vec3;
    kwt_vec4;

    // matrix types
    kwt_mat2;
    kwt_mat3;
    kwt_mat4;
    kwt_mat2x2;
    kwt_mat2x3;
    kwt_mat2x4;
    kwt_mat3x2;
    kwt_mat3x3;
    kwt_mat3x4;
    kwt_mat4x2;
    kwt_mat4x3;
    kwt_mat4x4;
    kwt_dmat2;
    kwt_dmat3;
    kwt_dmat4;
    kwt_dmat2x2;
    kwt_dmat2x3;
    kwt_dmat2x4;
    kwt_dmat3x2;
    kwt_dmat3x3;
    kwt_dmat3x4;
    kwt_dmat4x2;
    kwt_dmat4x3;
    kwt_dmat4x4;

    // image types
    kwt_image1D;
    kwt_image2D;
    kwt_image3D;
    kwt_imageCube;
    kwt_image2DRect;
    kwt_image1DArray;
    kwt_image2DArray;
    kwt_imageCubeArray;
    kwt_imageBuffer;
    kwt_image2DMS;
    kwt_image2DMSArray;

    kwt_iimage1D;
    kwt_iimage2D;
    kwt_iimage3D;
    kwt_iimageCube;
    kwt_iimage2DRect;
    kwt_iimage1DArray;
    kwt_iimage2DArray;
    kwt_iimageCubeArray;
    kwt_iimageBuffer;
    kwt_iimage2DMS;
    kwt_iimage2DMSArray;

    kwt_uimage1D;
    kwt_uimage2D;
    kwt_uimage3D;
    kwt_uimageCube;
    kwt_uimage2DRect;
    kwt_uimage1DArray;
    kwt_uimage2DArray;
    kwt_uimageCubeArray;
    kwt_uimageBuffer;
    kwt_uimage2DMS;
    kwt_uimage2DMSArray;

    // sampler types
    kwt_sampler1D;
    kwt_sampler2D;
    kwt_sampler3D;
    kwt_samplerCube;
    kwt_sampler2DRect;
    kwt_sampler1DArray;
    kwt_sampler2DArray;
    kwt_samplerCubeArray;
    kwt_samplerBuffer;
    kwt_sampler2DMS;
    kwt_sampler2DMSArray;
    kwt_isampler1D;
    kwt_isampler2D;
    kwt_isampler3D;
    kwt_isamplerCube;
    kwt_isampler2DRect;
    kwt_isampler1DArray;
    kwt_isampler2DArray;
    kwt_isamplerCubeArray;
    kwt_isamplerBuffer;
    kwt_isampler2DMS;
    kwt_isampler2DMSArray;
    kwt_usampler1D;
    kwt_usampler2D;
    kwt_usampler3D;
    kwt_usamplerCube;
    kwt_usampler2DRect;
    kwt_usampler1DArray;
    kwt_usampler2DArray;
    kwt_usamplerCubeArray;
    kwt_usamplerBuffer;
    kwt_usampler2DMS;
    kwt_usampler2DMSArray;

    // shadow sampler types
    kwt_sampler1DShadow;
    kwt_sampler2DShadow;
    kwt_samplerCubeShadow;
    kwt_sampler2DRectShadow;
    kwt_sampler1DArrayShadow;
    kwt_sampler2DArrayShadow;
    kwt_samplerCubeArrayShadow;

    // builtin variables
    kwb_gl_in;
    kwb_gl_out;
    kwb_gl_BaseVertex;
    kwb_gl_BaseInstance;
    kwb_gl_ClipDistance;
    kwb_gl_DrawID;
    kwb_gl_DepthRangeParameters;
    kwb_gl_DepthRange;
    kwb_gl_FragCoord;
    kwb_gl_FragDepth;
    kwb_gl_FrontFacing;
    kwb_gl_GlobalInvocationID;
    kwb_gl_InstanceID;
    kwb_gl_InvocationID;
    kwb_gl_Layer;
    kwb_gl_LocalInvocationID;
    kwb_gl_LocalInvocationIndex;
    kwb_gl_NumSamples;
    kwb_gl_NumWorkGroups;
    kwb_gl_PatchVerticesIn;
    kwb_gl_PerVertex;
    kwb_gl_Position;
    kwb_gl_PointCoord;
    kwb_gl_PointSize;
    kwb_gl_PrimitiveID;
    kwb_gl_PrimitiveIDIn;
    kwb_gl_SampleID;
    kwb_gl_SamplePosition;
    kwb_gl_SampleMask;
    kwb_gl_SampleMaskIn;
    kwb_gl_TessLevelOuter;
    kwb_gl_TessLevelInner;
    kwb_gl_TessCoord;
    kwb_gl_VertexID;
    kwb_gl_ViewportIndex;
    kwb_gl_WorkGroupID;
    kwb_gl_WorkGroupSize;

    // builtin constants
    kwb_gl_MaxClipDistances;
    kwb_gl_MaxDrawBuffers;
    kwb_gl_MaxImageSamples;
    kwb_gl_MaxImageUnits;
    kwb_gl_MaxPatchVertices;
    kwb_gl_MinProgramTexelOffset;
    kwb_gl_MaxProgramTexelOffset;
    kwb_gl_MaxTessGenLevel;
    kwb_gl_MaxTessPatchComponents;
    kwb_gl_MaxTextureImageUnits;
    kwb_gl_MaxTransformFeedbackBuffers;
    kwb_gl_MaxTransformFeedbackInterleavedComponents;
    kwb_gl_MaxVaryingVectors;
    kwb_gl_MaxViewports;

    kwb_gl_MaxAtomicCounterBindings;
    kwb_gl_MaxAtomicCounterBufferSize;

    kwb_gl_MaxCombinedAtomicCounters;
    kwb_gl_MaxCombinedAtomicCounterBuffers;
    kwb_gl_MaxCombinedImageUniforms;
    kwb_gl_MaxCombinedImageUnitsAndFragmentOutputs;
    kwb_gl_MaxCombinedTextureImageUnits;

    kwb_gl_MaxComputeWorkGroupCount;
    kwb_gl_MaxComputeWorkGroupSize;
    kwb_gl_MaxComputeUniformComponents;
    kwb_gl_MaxComputeTextureImageUnits;
    kwb_gl_MaxComputeImageUniforms;
    kwb_gl_MaxComputeAtomicCounters;
    kwb_gl_MaxComputeAtomicCounterBuffers;

    kwb_gl_MaxFragmentAtomicCounters;
    kwb_gl_MaxFragmentAtomicCounterBuffers;
    kwb_gl_MaxFragmentImageUniforms;
    kwb_gl_MaxFragmentInputComponents;
    kwb_gl_MaxFragmentUniformComponents;
    kwb_gl_MaxFragmentUniformVectors;

    kwb_gl_MaxGeometryAtomicCounters;
    kwb_gl_MaxGeometryAtomicCounterBuffers;
    kwb_gl_MaxGeometryImageUniforms;
    kwb_gl_MaxGeometryInputComponents;
    kwb_gl_MaxGeometryOutputComponents;
    kwb_gl_MaxGeometryOutputVertices;
    kwb_gl_MaxGeometryTextureImageUnits;
    kwb_gl_MaxGeometryTotalOutputComponents;
    kwb_gl_MaxGeometryUniformComponents;
    kwb_gl_MaxGeometryVaryingComponents;

    kwb_gl_MaxTessControlAtomicCounterBuffers;
    kwb_gl_MaxTessControlAtomicCounters;
    kwb_gl_MaxTessControlImageUniforms;
    kwb_gl_MaxTessControlInputComponents;
    kwb_gl_MaxTessControlOutputComponents;
    kwb_gl_MaxTessControlUniformComponents;
    kwb_gl_MaxTessControlTextureImageUnits;
    kwb_gl_MaxTessControlTotalOutputComponents;

    kwb_gl_MaxTessEvaluationAtomicCounters;
    kwb_gl_MaxTessEvaluationAtomicCounterBuffers;
    kwb_gl_MaxTessEvaluationImageUniforms;
    kwb_gl_MaxTessEvaluationInputComponents;
    kwb_gl_MaxTessEvaluationOutputComponents;
    kwb_gl_MaxTessEvaluationUniformComponents;
    kwb_gl_MaxTessEvaluationTextureImageUnits;

    kwb_gl_MaxVertexAtomicCounters;
    kwb_gl_MaxVertexAtomicCounterBuffers;
    kwb_gl_MaxVertexAttribs;
    kwb_gl_MaxVertexImageUniforms;
    kwb_gl_MaxVertexOutputComponents;
    kwb_gl_MaxVertexTextureImageUnits;
    kwb_gl_MaxVertexUniformComponents;
    kwb_gl_MaxVertexUniformVectors;
}

Operation :: enum u16 {
    arrow;
    bang;
    backtick;
    pipe;
    double_pipe;
    pipe_equal;
    equal;
    equal_equal;
    bang_equal;
    percent;
    percent_equal;
    less_than;
    double_less_than;
    less_than_equal;
    greater_than;
    greater_than_equal;
    minus;
    minus_equal;
    minus_minus;
    asterisk;
    asterisk_equal;
    colon;
    slash;
    plus;
    plus_equal;
    plus_plus;
    slash_equal;
    ampersand;
    double_ampersand;
    ampersand_equal;
    tilde;
    question;
    unknown;
    caret;
    caret_equal;
}

Punctuation :: enum u16 {
    semicolon;
    backslash;
    l_paren;
    r_paren;
    l_brace;
    r_brace;
    l_bracket;
    r_bracket;
    period;
    comma;
}

Directive :: enum u16 {
    di_define;
    di_elif;
    di_elifdef;
    di_elifndef;
    di_else;
    di_endif;
    di_error;
    di_extension;
    di_if;
    di_ifdef;
    di_ifndef;
    // di_include;
    di_line;
    di_pragma;
    di_undef;
    di_warning;
    di_version;
}

//- Keyword Specifics
Keyword_Token :: struct {
    type: Token.Type;
    keyword: Keyword;
}

KEYWORD_MAP :: #run -> Table(string, Keyword_Token) {
    table: Table(string, Keyword_Token);
    _, keywords_count := enum_range(Keyword);
    size := 2 * (keywords_count);
    init(*table, size);

    // NOTE:
    // These #inserts need to be split here because trying to generate cases
    // for all 277 (!) keyword values makes the compiler crap itself:
    //
    // ```
    // Error: Jai encountered an exception running the program and is terminating.
    //
    // Command line arguments:
    //   jai.exe first.jai
    //
    // This happened outside compile-time execution, so it is likely the compiler's fault.
    //
    // Stack trace of the compiler:
    //
    //   unknown(C1D87614) : BaseThreadInitThunk
    // ```
    //
    // When testing, this happens when keywords_count >= 267.
    // With split #inserts, the compiler can handle them just fine.

    #insert -> string {
        curr_slice_count := 3;
        curr_type := "keyword";

        b: String_Builder;
        init_string_builder(*b);
        for enum_names(Keyword) {
            if !starts_with(it, "kw_") {
                continue;
            }

            print_to_builder(*b, "table_add(*table, \"%\", Keyword_Token.{type = .%, keyword = .%});\n",
                            slice(it, curr_slice_count, it.count - curr_slice_count), curr_type, it);
        }
        return builder_to_string(*b);
    }

    #insert -> string {
        curr_slice_count := 4;
        curr_type := "type_keyword";

        b: String_Builder;
        init_string_builder(*b);
        for enum_names(Keyword) {
            if !starts_with(it, "kwt_") {
                continue;
            }

            print_to_builder(*b, "table_add(*table, \"%\", Keyword_Token.{type = .%, keyword = .%});\n",
                            slice(it, curr_slice_count, it.count - curr_slice_count), curr_type, it);
        }
        return builder_to_string(*b);
    }

    #insert -> string {
        curr_slice_count := 4;
        curr_type := "modifier_keyword";

        b: String_Builder;
        init_string_builder(*b);
        for enum_names(Keyword) {
            if !starts_with(it, "kwm_") {
                continue;
            }

            print_to_builder(*b, "table_add(*table, \"%\", Keyword_Token.{type = .%, keyword = .%});\n",
                            slice(it, curr_slice_count, it.count - curr_slice_count), curr_type, it);
        }
        return builder_to_string(*b);
    }

    #insert -> string {
        curr_slice_count := 4;
        curr_type := "value_keyword";

        b: String_Builder;
        init_string_builder(*b);
        for enum_names(Keyword) {
            if !starts_with(it, "kwv_") {
                continue;
            }

            print_to_builder(*b, "table_add(*table, \"%\", Keyword_Token.{type = .%, keyword = .%});\n",
                            slice(it, curr_slice_count, it.count - curr_slice_count), curr_type, it);
        }
        return builder_to_string(*b);
    }

    #insert -> string {
        curr_slice_count := 4;
        curr_type := "builtin_keyword";

        b: String_Builder;
        init_string_builder(*b);
        for enum_names(Keyword) {
            if !starts_with(it, "kwb_") {
                continue;
            }

            print_to_builder(*b, "table_add(*table, \"%\", Keyword_Token.{type = .%, keyword = .%});\n",
                            slice(it, curr_slice_count, it.count - curr_slice_count), curr_type, it);
        }
        return builder_to_string(*b);
    }

    return table;
}
MAX_KEYWORD_LENGTH :: #run -> s32 {
    max_len := 0;

    curr_slice_count := 3;

    for enum_names(Keyword) {
        if starts_with(it, "kwt") curr_slice_count = 4;
        else if starts_with(it, "kwm") curr_slice_count = 4;
        else if starts_with(it, "kwv") curr_slice_count = 4;
        else if starts_with(it, "kwb") curr_slice_count = 4;
        else curr_slice_count = 3;

        actual := slice(it, curr_slice_count, it.count - curr_slice_count);
        if actual.count > max_len max_len = actual.count;
    }
    return xx max_len;
}

PREPROCESSOR_DIRECTIVES_MAP :: #run -> Table(string, Directive) {
    table: Table(string, Directive);
    temp, keywords_count := enum_range(Keyword);
    size := 2 * (keywords_count);
    init(*table, size);

    #insert -> string {
        b: String_Builder;
        init_string_builder(*b);
        for enum_names(Directive) {
            print_to_builder(*b, "table_add(*table, \"%\", .%);\n",
                            slice(it, 3, it.count - 3), it);
        }
        return builder_to_string(*b);
    }

    return table;
}
MAX_DIRECTIVE_LENGTH :: #run -> s32 {
    max_len := 0;

    for enum_names(Directive) {
        actual := slice(it, 3, it.count - 3);
        if actual.count > max_len max_len = actual.count;
    }
    return xx max_len;
}


read_identifier_string :: (using tokenizer: *Tokenizer) -> string {
    ret: string;
    ret.data = t;

    while t < max_t {
        c := t.*;
        if is_alnum(c) { t += 1; continue; }
        break;
    }
    if t >= max_t then t = max_t;
    ret.count = xx (t - ret.data);

    return ret;
}

eat_white_space :: inline (start: *u8, max_t: *u8) -> *u8 {
    t := start;
    while t < max_t && is_white_space(t.*) {
        t += 1;
    }
    return t;
}

is_white_space :: inline (c: u8) -> bool {
    return c == #char " " || c == #char "\r" || c == #char "\n";
}

#run assert(enum_highest_value(Token.Type) == COLOR_MAP.count - 1);
