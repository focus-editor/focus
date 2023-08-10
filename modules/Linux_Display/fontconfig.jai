fc_find_font :: (name: string, allocator := temp) -> success: bool, path: string {
    if !load_fc_lib() return false, "";

    escaped_name: [..]u8;
    defer array_reset(*escaped_name);

    array_reserve(*escaped_name, name.count);
    for 0..name.count - 1 {
        if name[it] == {
            case #char "\\"; #through;
            case #char "-"; #through;
            case #char ":"; #through;
            case #char ","; {
                array_add(*escaped_name, #char "\\");
                array_add(*escaped_name, name[it]);
            }

            case; array_add(*escaped_name, name[it]);
        }
    }

    match_string := sprint("%:spacing=100\0", to_string(escaped_name.data, escaped_name.count));
    defer free(match_string);

    pat := FcNameParse(match_string.data); defer FcPatternDestroy(pat);
    os := FcObjectSetCreate(); defer FcObjectSetDestroy(os);
    FcObjectSetAdd(os, "file");

    FcConfigSubstitute(null, pat, .Pattern);
    FcDefaultSubstitute(pat);

    fs := FcFontSetCreate(); defer FcFontSetDestroy(fs);

    result: FcResult;
    font_patterns := FcFontSort(null, pat, 1, null, *result);
    defer if font_patterns FcFontSetSortDestroy(font_patterns);
    if !font_patterns || !font_patterns.nfont return false, "";
    for 0..font_patterns.nfont - 1 {
        font_pattern := FcFontRenderPrepare(null, pat, font_patterns.fonts[it]);
        if font_pattern then FcFontSetAdd(fs, font_pattern);
    }

    if !fs.nfont then return false, "";

    font := FcPatternFilter(fs.fonts[0], os); defer FcPatternDestroy(font);
    s := FcPatternFormat(font, "%{=unparse}");
    if s {
        defer FcStrFree(s);
        tmp := to_string(s);
        if starts_with(tmp, ":file=") then advance(*tmp, 6);
        ret := copy_string(tmp, allocator);

        escaped := true;
        size := 0;
        for 0..tmp.count - 1 {
            if escaped {
                escaped = false;
                ret[size] = tmp[it];
                size += 1;
                continue;
            }
            if tmp[it] == {
                case #char "\\"; {
                    assert(!escaped);
                    escaped = true;
                }
                case; {
                    ret[size] = tmp[it];
                    size += 1;
                }
            }
        }
        ret.count = size;

        return true, ret;
    }

    return false, "";
}

#scope_file

load_fc_lib :: () -> bool {
    // if fc_lib_handle {
    //     return FcInitBringUptoDate() != 0;
    // }
    if fc_lib_handle return true;

    if !fc_lib_handle {
        fc_lib_handle = dlopen("libfontconfig.so.1", RTLD_NOW);
        if !fc_lib_handle return false;

        FcInit = xx dlsym(fc_lib_handle, "FcInit");
        FcInitBringUptoDate = xx dlsym(fc_lib_handle, "FcInitBringUptoDate");
        FcFini = xx dlsym(fc_lib_handle, "FcFini");
        FcStrFree = xx dlsym(fc_lib_handle, "FcStrFree");
        FcPatternCreate = xx dlsym(fc_lib_handle, "FcPatternCreate");
        FcPatternDestroy = xx dlsym(fc_lib_handle, "FcPatternDestroy");
        FcPatternFilter = xx dlsym(fc_lib_handle, "FcPatternFilter");
        FcPatternPrint = xx dlsym(fc_lib_handle, "FcPatternPrint");
        FcPatternFormat = xx dlsym(fc_lib_handle, "FcPatternFormat");
        FcNameParse = xx dlsym(fc_lib_handle, "FcNameParse");
        FcObjectSetCreate = xx dlsym(fc_lib_handle, "FcObjectSetCreate");
        FcObjectSetDestroy = xx dlsym(fc_lib_handle, "FcObjectSetDestroy");
        FcObjectSetAdd = xx dlsym(fc_lib_handle, "FcObjectSetAdd");
        FcFontSetCreate = xx dlsym(fc_lib_handle, "FcFontSetCreate");
        FcFontSetAdd = xx dlsym(fc_lib_handle, "FcFontSetAdd");
        FcFontSort = xx dlsym(fc_lib_handle, "FcFontSort");
        FcFontSetDestroy = xx dlsym(fc_lib_handle, "FcFontSetDestroy");
        FcFontSetSortDestroy = xx dlsym(fc_lib_handle, "FcFontSetSortDestroy");
        FcConfigSubstitute = xx dlsym(fc_lib_handle, "FcConfigSubstitute");
        FcDefaultSubstitute = xx dlsym(fc_lib_handle, "FcDefaultSubstitute");
        FcFontRenderPrepare = xx dlsym(fc_lib_handle, "FcFontRenderPrepare");
        FcFontMatch = xx dlsym(fc_lib_handle, "FcFontMatch");
    }

    return FcInit() != 0;
}

FcResult :: enum {
    Match;
    NoMatch;
    TypeMismatch;
    NoId;
    OutOfMemory;
}

FcMatchKind :: enum {
    Pattern;
    Font;
    Scan;
    End;
    Begin :: Pattern;
}

FcFontSet :: struct {
    nfont: s32;
    sfont: s32;
    fonts: **FcPattern;
}

FcObjectSet :: struct {
    nobject: s32;
    sobject: s32;
    objects: **u8;
}

FcCharSet :: struct {}

FcPattern :: struct {}

FcConfig :: struct {};

FcInit : #type () -> s32 #c_call;
FcInitBringUptoDate : #type () -> s32 #c_call;
FcFini : #type () #c_call;
FcStrFree : #type (s: *u8) #c_call;

FcPatternCreate : #type () -> *FcPattern #c_call;
FcPatternDestroy : #type (p: *FcPattern) #c_call;
FcPatternFilter : #type (p: *FcPattern, os: *FcObjectSet) -> *FcPattern #c_call;
FcPatternPrint : #type (p: *FcPattern) #c_call;
FcPatternFormat : #type (pat: *FcPattern, format: *u8) -> *u8 #c_call;
FcNameParse : #type (name: *u8) -> *FcPattern #c_call;

FcObjectSetCreate : #type () -> *FcObjectSet #c_call;
FcObjectSetDestroy : #type (os: *FcObjectSet) #c_call;
FcObjectSetAdd : #type (os: *FcObjectSet, object: *u8) -> s32 #c_call;

FcFontSetCreate : #type () -> *FcFontSet #c_call;
FcFontSetAdd : #type (s: *FcFontSet, font: *FcPattern) -> s32 #c_call;
FcFontSort : #type (config: *FcConfig, p: *FcPattern, trim: s32, csp: **FcCharSet, result: *FcResult) -> *FcFontSet #c_call;
FcFontSetDestroy : #type (fs: *FcFontSet) #c_call;
FcFontSetSortDestroy : #type (fs: *FcFontSet) #c_call;

FcConfigSubstitute : #type (config: *FcConfig, p: *FcPattern, kind: FcMatchKind) -> s32 #c_call;
FcDefaultSubstitute : #type (pattern: *FcPattern) #c_call;
FcFontRenderPrepare : #type (config: *FcConfig, pat: *FcPattern, font: *FcPattern) -> *FcPattern #c_call;
FcFontMatch : #type (config: *FcConfig, p: *FcPattern, result: *FcResult) -> *FcPattern #c_call;

fc_lib_handle: *void;
