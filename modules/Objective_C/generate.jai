#assert(OS == .MACOS);

AT_COMPILE_TIME :: true;

// Some macOS types have very "special" alignment, so enabe this check when re-generating the bindings to make sure we don’t mess that up.
// But don’t keep it enabled or you’ll slow down compiling every macOS program by A LOT.
GENERATE_COMPILE_TIME_STRUCT_CHECKS :: false;

DECLARATIONS_TO_OMIT :: string.[
    "BOOL",
    "objc_setMultithreaded", // Only exists in 10.13, not in later SDKs.
];

#if AT_COMPILE_TIME {
    #run,stallable {
        set_build_options_dc(.{do_output=false});
        options := get_build_options();
        args := options.compile_time_command_line;
        if !generate_bindings(args) {
            compiler_set_workspace_status(.FAILED);
        }
    }
} else {
    #import "System";

    main :: () {
        set_working_directory(path_strip_filename(get_path_of_running_executable()));
        args := get_command_line_arguments();
        if !generate_bindings(args) {
            exit(1);
        }
    }
}

generate_bindings :: (args: [] string) -> bool {
    cpu := CPU;
    if array_find(args, "-arm64") {
        cpu = .ARM64;
    }

    bindings_directory: string;
    if cpu == {
        case .X64;   bindings_directory = "bindings/x64";
        case .ARM64; bindings_directory = "bindings/arm64";
        case; assert(false);
    }

    make_directory_if_it_does_not_exist(bindings_directory, recursive = true);

    success := generate_runtime(cpu, bindings_directory);
    success &= generate_message(cpu, bindings_directory);
    // success &= generate_appkit();
    return success;
}

generate_runtime :: (cpu: CPU_Tag, bindings_directory: string) -> bool {
    output_path := tprint("%/runtime.jai", bindings_directory);
    options := get_common_options(cpu);
    libc_path := get_libc_paths();

    array_add(*options.source_files,
        tprint("%/objc/objc.h", libc_path),
        tprint("%/objc/runtime.h", libc_path),
    );

    array_add(*options.path_fragments_to_treat_as_non_system_paths,
        "objc.h",
        "runtime.h",
    );

    return generate_bindings(options, output_path);
}

generate_message :: (cpu: CPU_Tag, bindings_directory: string) -> bool {
    output_path := tprint("%/message.jai", bindings_directory);
    options := get_common_options(cpu);
    libc_path := get_libc_paths();

    array_add(*options.source_files,
        tprint("%/objc/message.h", libc_path),
    );

    array_add(*options.path_fragments_to_treat_as_non_system_paths,
        "message.h",
    );

    return generate_bindings(options, output_path);
}

// generate_appkit :: () -> bool {
//     output_path := tprint("%/appkit_objc.jai", bindings_directory);
//     builder: String_Builder;
//     selectors: [..] string;
//     define(*builder, "NSApplication", *selectors);
//     define(*builder, "NSApplicationDelegate", *selectors);
//     define(*builder, "NSWindow", *selectors);

//     append_selector_struct(*builder, selectors);

//     content := builder_to_string(*builder);
//     return write_entire_file(output_path, content);
// }

get_common_options :: (cpu: CPU_Tag) -> Generate_Bindings_Options {
    sdk_path := get_macos_sdk_path();
    build_options := get_build_options(); // @Incomplete: run-time version
    target_triple_with_sdk := get_macos_target_triple(cpu, build_options.minimum_os_version.major, build_options.minimum_os_version.minor);

    options: Generate_Bindings_Options;
    options.cpu = cpu;
    array_add(*options.system_library_names, "libobjc");

    array_add(*options.extra_clang_arguments,
        "-x", "c",
        "-target", target_triple_with_sdk,
        "-isysroot", sdk_path,
    );
    array_add(*options.system_library_paths, tprint("%/usr/lib", sdk_path));

    options.log_stripped_declarations = true;
    options.generate_compile_time_struct_checks = GENERATE_COMPILE_TIME_STRUCT_CHECKS;

    options.visitor = objc_visitor;
    return options;
}

#scope_file

objc_visitor :: (decl: *Declaration, parent_decl: *Declaration) -> Declaration_Visit_Result {
    // Get rid of all the "<name> :: __darwin_<name>" and "__darwin_<name> :: _opague_<name>" indirections
    // if decl.kind == .TYPEDEF {
    //     typedef := cast (*Typedef) decl;
    //     target_name := get_type_name(typedef.type);
    //     if begins_with(target_name, "__darwin") || begins_with(target_name, "__opaque") {
    //         decl.decl_flags |= .OMIT_FROM_OUTPUT;
    //         while typedef.type.type_of_typedef {
    //             typedef.type.type_of_typedef.output_name = decl.output_name;
    //             if !(decl.decl_flags & .OMIT_FROM_OUTPUT)   break;
    //             typedef = typedef.type.type_of_typedef;
    //         }

    //         if typedef.type.type_of_struct {
    //             typedef.type.type_of_struct.output_name = decl.output_name;
    //         }
    //     }
    // }
    if !parent_decl {
        if array_find(DECLARATIONS_TO_OMIT, decl.name) {
            decl.decl_flags |= .OMIT_FROM_OUTPUT;
            return .STOP;
        }

        if context.generator_options.cpu == .ARM64 {
            // Workaround for incorrect symbol information for libobjc on ARM64 in SDKs 11.x-13.x:
            // Apple claims that the *_stret functions exist, but when you then open up the DLL, they’re missing.
            // You can’t make this stuff up…
            //  -rluba, 2024-02-23
            if ends_with(decl.name, "_stret") {
                decl.decl_flags |= .OMIT_FROM_OUTPUT;
                return .STOP;
            }
        }

        if decl.name == "objc_object" {
            decl.output_name = "NSObject";
        }

        if decl.name == "objc_class" {
            // Replace the "isa: Class" field with a "using #as base: objc_object" to allow classes to auto-cast to "id", which they do in Objective-C.
            assert(decl.kind == .STRUCT);
            _struct := cast(*Struct) decl;
            assert(_struct.declarations.count > 1);
            assert(_struct.declarations[0].name == "isa");
            array_ordered_remove_by_index(*_struct.declarations, 0);
            nsobject_decl: *Declaration;
            for context.generator.global_scope.members {
                if it.name == "objc_object" {
                    nsobject_decl = it;
                    break;
                }
            }
            assert(nsobject_decl != null);
            assert(nsobject_decl.kind == .STRUCT);

            parent := New(Declaration);
            parent.name = "super";
            parent.output_name = parent.name;
            parent.type = New(CType);
            parent.type.type_of_struct = cast(*Struct) nsobject_decl;
            parent.decl_flags |= .QUALIFIER_AS;
            parent.decl_flags |= .QUALIFIER_USING;
            array_add(*_struct.parents, parent);
        }

        // if decl.kind == .TYPEDEF {
        //     for TYPE_REPLACEMENTS_TO_MAKE if decl.name == it.type {
        //         decl.output_name = it.replacement;
        //         decl.decl_flags |= .OMIT_FROM_OUTPUT;
        //         return .STOP;
        //     }
        // }
        // // This should probably happen in the generator itself
        // if decl.kind == .MACRO_DEFINITION {
        //     if decl.expression.kind == .LITERAL {
        //         litteral := cast(*Literal)decl.expression;
        //         if decl.output_name == string_from_macro_value(litteral.macro_value) {
        //             decl.decl_flags |= .OMIT_FROM_OUTPUT;
        //             return .STOP;
        //         }
        //     }
        // }
    }

    return .RECURSE;
}

#import "Basic";
#import "Bindings_Generator";
#import "Compiler";
#import "File";
#import "String";
#import "Toolchains/macOS";
