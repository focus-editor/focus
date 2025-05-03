VERSION      :: #run -> string {
    result, revision := run_command("git", "rev-parse", "--short", "HEAD", capture_and_return_output = true);
    if revision return sprint("0.3.8-%", trim(revision));
    return "0.3.8-dev";
}
RELEASE_DATE :: #run -> string {
    current_time := to_calendar(current_time_consensus());
    return calendar_to_string(current_time);
}

// // NOTE: Uncomment when releasing, comment out when not releasing
// VERSION :: "0.3.8";
// RELEASE_DATE :: "27 February 2025";

#run,stallable build();

build :: () {
    options := get_build_options();
    options.minimum_os_version = .{10, 13};
    options.temporary_storage_size = 1048576;  // 1 MB per thread
    args := options.compile_time_command_line;

    import_path: [..] string;
    array_add(*import_path, "modules");
    array_add(*import_path, ..options.import_path);
    options.import_path = import_path;

    set_build_options_dc(.{do_output=false});
    set_working_directory(#filepath);

    optimized := false;
    windows7  := false;
    set_optimization(*options, .DEBUG);
    options.arithmetic_overflow_check = .FATAL;
    build_dir := "build_debug";
    options.output_executable_name = "focus";

    for arg: args {
        if arg == {
          case "release";
            optimized = true;
            build_dir = "build_release";
            set_optimization(*options, .VERY_OPTIMIZED);
            options.llvm_options.enable_split_modules = false;
            options.array_bounds_check = .ON;
            options.null_pointer_check = .ON;
            options.arithmetic_overflow_check = .OFF;
          case "debug";
          case "no_output";
            options.output_type = .NO_OUTPUT;
          case "windows7";
            windows7 = true;
            options.output_executable_name = "focus_windows7";
          case;
            compiler_report(tprint("Command-line argument #%, '%', is invalid. Valid options are: 'debug', 'release'.\n", it_index+1, arg));
        }
    }

    options.output_path = build_dir;
    make_directory_if_it_does_not_exist(build_dir);

    #if OS == .WINDOWS {
        options.use_custom_link_command = true;
    }

    w := compiler_create_workspace(options.output_executable_name);
    set_build_options(options, w);
    #if OS == .WINDOWS {
        // Disable runtime console
        if optimized {
            set_build_options_dc(.{append_linker_arguments=.["/SUBSYSTEM:windows", "/ENTRY:mainCRTStartup"]}, w);

            // For tracing release builds use this:
            // set_build_options_dc(.{append_linker_arguments=.["/SUBSYSTEM:windows", "/ENTRY:mainCRTStartup", "ws2_32.lib", "msvcprtd.lib"]}, w);
        } else {
            set_build_options_dc(.{append_linker_arguments=.["ws2_32.lib", "msvcprtd.lib"]}, w);
        }
    }

    compiler_begin_intercept(w);

    add_build_file("src/main.jai", w);

    build_constants := tprint(#string STRING
            VERSION         :: "%";
            RELEASE_DATE    :: "%";
            DEBUG           :: %;
            WINDOWS7        :: %;
            NO_OUTPUT_BUILD :: %;
        STRING,
            VERSION,
            RELEASE_DATE,
            ifx optimized then "false" else "true",
            ifx windows7  then "true"  else "false",
            options.output_type == .NO_OUTPUT,
    );
    add_build_string(build_constants, w);

    failed := false;
    while true {
        message := compiler_wait_for_message();
        if message.workspace != w continue;
        if message.kind == {
            case .TYPECHECKED;
                if options.output_type != .NO_OUTPUT {
                    typechecked := cast(*Message_Typechecked) message;
                    for typechecked.structs {
                        s := it.expression.defined_type;
                        if s.name == "Settings"  register_settings_members(s, it.expression);
                    }
                    for typechecked.declarations {
                        if it.expression.name == "ADDED_SETTINGS" {
                            register_added_settings(it.expression);
                        } else if it.expression.name == "RENAMED_SETTINGS" {
                            register_renamed_settings(it.expression);
                        }
                    }
                }

            case .PHASE;
                phase_message := cast(*Message_Phase) message;
                if phase_message.phase == {
                    case .ALL_TARGET_CODE_BUILT;
                        if options.output_type == .NO_OUTPUT  exit(0);
                        check_settings();

                    case .READY_FOR_CUSTOM_LINK_COMMAND;
                        failed = !run_custom_link(message.workspace, phase_message);
                        compiler_custom_link_command_is_complete(message.workspace);
                        if failed break;
                }

            case .COMPLETE;
                m := cast(*Message_Complete) message;
                if m.error_code == .COMPILATION_FAILED then failed = true;
                break;
        }
    }

    compiler_end_intercept(w);

    // Don't try to set icon or manifest if we failed compilation
    if failed then return;

    #if OS == .WINDOWS {
        exe_path := tprint("%/%.exe", build_dir, options.output_executable_name);

        ico_data := create_ico_file_from_bitmap_filename("images/focus.png");
        success := set_icon_by_data(exe_path, ico_data);
        if !success {
            log_error("ERROR: Couldn't set icon for '%'\n", exe_path);
        }

        manifest_options: Manifest_Options;
        success = add_manifest_to_executable(exe_path, manifest_options);
        if !success {
            log_error("ERROR: Couldn't add manifest to executable '%'\n", exe_path);
        }
    } else #if OS == .MACOS {
        if !optimized return; // When debugging, use the Unix program directly. This saves us compile time.

        // Set up our temporary directory to turn into a .dmg disk image
        DMG_DIR :: "dmg";
        run_command("mkdir", DMG_DIR);

        // Generate Focus.app inside our temporary directory
        set_working_directory(DMG_DIR);
        create_app_bundle("Focus", tprint("../build_release/%", options.output_executable_name), "../images/mac.png", "", true, true);
        write_entire_file("Focus.app/Contents/Info.plist", tprint(INFO_PLIST_CONTENTS, VERSION, VERSION));
        set_working_directory(#filepath);

        // Create a symbolic link to /Applications (what all the cool kids do)
        run_command("ln", "-s", "/Applications", DMG_DIR);

        // Generate a .DMG using Disk Utility
        run_command("hdiutil", "create", "-volname", tprint("Focus %", VERSION), "-srcfolder", DMG_DIR, "-ov", "-format", "UDZO", tprint("Focus-%-Intel.dmg", VERSION));

        // Remove our temporary directory when we're done
        run_command("rm", "-r", DMG_DIR);

        #import "MacOS_Bundler";
        #import "File";
    }
}

register_settings_members :: (settings: *Type_Info_Struct, code_struct: *Code_Struct) {
    for settings.members {
        version := get_member_version_from_notes(it);
        if !version {
            compiler_report(tprint("Settings member \"%\" must have a version annotation!\n", it.name), make_location(code_struct));
        }
        array_add(*settings_info.setting_members, .{version, it.name});
    }
    settings_info.settings_node = code_struct;
}

get_member_version_from_notes :: (member: Type_Info_Struct_Member) -> int {
    for member.notes {
        if it && it[0] == #char "v" {
            s := it;
            advance(*s, 1);
            v, ok := parse_int(*s);
            if ok  return v;
        }
    }
    return 0;
}

register_added_settings :: (decl: Code_Declaration) {
    literal := cast(*Code_Literal) decl.expression;
    assert(literal.kind == .LITERAL && literal.value_type == .ARRAY);
    for literal.array_literal_info.array_members {
        entry := cast(*Code_Literal) it;
        arguments := entry.struct_literal_info.arguments;
        // Maybe there's a way to just get the value of ADDED_SETTINGS, which would be easier to use than
        // what we're doing here, which is parsing the the code nodes of its literal.
        version := 0;
        for arguments {
            literal := cast(*Code_Literal) it;
            i := it_index % 3; // Number of members for Added_Settings
            if i == {
                case 0;  version = literal._s64;
                case 1;  array_add(*settings_info.present_in_migrator, .{ version, literal._string});
                case;    // Remainder of struct members which we don't care about.
            }
        }
    }
}

register_renamed_settings :: (decl: Code_Declaration) {
    literal := cast(*Code_Literal) decl.expression;
    assert(literal.kind == .LITERAL && literal.value_type == .ARRAY);
    for literal.array_literal_info.array_members {
        entry := cast(*Code_Literal) it;
        arguments := entry.struct_literal_info.arguments;
        version := 0;
        for arguments {
            literal := cast(*Code_Literal) it;
            i := it_index % 5; // Number of members for Renamed_Settings
            if i == {
                case 0;  version = literal._s64;
                case 1;  // Old name, which we don't care about.
                case 2;  array_add(*settings_info.present_in_migrator, .{ version, literal._string});
                case;    // Remainder of struct members which we don't care about.
            }
        }
    }
}

check_settings :: () {
    for member: settings_info.setting_members {
        if member.version == 1  continue;

        found := false;
        for settings_info.present_in_migrator {
            if it.name == member.name {
                if member.version != it.version {
                    compiler_report(tprint("Setting member version for \"%\" in config.jai did not match version in config_migrator.jai (% != %)\n", member.name, member.version, it.version), make_location(settings_info.settings_node));
                }
                found = true;
                break;
            }
        }

        if !found {
            compiler_report(tprint("Could not find entry in config_migrator.jai for \"%\".  It should appear in ADDED_SETTINGS or RENAMED_SETTINGS! Be sure to increment CURRENT_CONFIG_VERSION if you haven't already. Also consider adding the setting to the default config.\n", member.name), make_location(settings_info.settings_node));
        }
    }
}

settings_info: struct {
    settings_node: *Code_Node;
    setting_members: [..] Version_Lookup;
    present_in_migrator: [..] Version_Lookup;

    Version_Lookup :: struct {
        version: int;
        name: string;
    }
}

#import "Compiler";
#import "Basic";
#import "File";
#import "Process";
#import "String";

#if OS == .WINDOWS {
    /*
     * Generate a link command that uses static CRT libraries only.
     *
     * We do this by iterating over the extra linker arguments/system library list and translating
     * any non-static CRT .lib to the static version (see `crt_lib_to_static()`).
     *
     * Ideally we would like to simply modify the original linker command that the compiler generates
     * however there is currently no way to retrieve it. We simply emulate the linker command here.
     *
     * - ileonte, 2025.01.16
     */
    run_custom_link :: (w: Workspace, m: *Message_Phase) -> bool {
        build_opts := get_build_options(w);
        vs_library_path, vs_linker_path := find_visual_studio_in_a_ridiculous_garbage_way();
        win_kit_path, win_kit_ver := find_windows_kit_root();
        compiler_obj_path := path_decomp(m.compiler_generated_object_files[0]);
        link_exe := tprint("%\\link.exe", vs_linker_path);

        link_command: [..] string;

        array_add(*link_command, link_exe);
        array_add(*link_command, "/nologo");
        for m.compiler_generated_object_files
            array_add(*link_command, it);
        array_add(*link_command, tprint("/OUT:%/%.exe", build_opts.output_path, build_opts.output_executable_name));
        array_add(*link_command, "/MACHINE:AMD64", "/INCREMENTAL:NO", "/DEBUG");
        array_add(*link_command, tprint("/IMPLIB:%/%.lib", compiler_obj_path, build_opts.output_executable_name));
        array_add(*link_command, tprint("/LIBPATH:%", vs_library_path));
        array_add(*link_command, tprint("/LIBPATH:%/um/x64", win_kit_path));
        array_add(*link_command, tprint("/LIBPATH:%/ucrt/x64", win_kit_path));
        array_add(*link_command, "/NODEFAULTLIB");
        for build_opts.additional_linker_arguments
            array_add(*link_command, crt_lib_to_static(it));
        for m.system_libraries
            array_add(*link_command, crt_lib_to_static(it));
        for m.user_libraries {
            if ends_with(it, "freetype.lib")  array_add(*link_command, "modules/freetype/windows/freetype.lib");
            else  array_add(*link_command, it);
        }

        print("Running custom link command: %\n", get_quoted_command_string(link_command));
        result := run_command(..link_command);
        if result.exit_code != 0 {
            compiler_report(tprint("Error: Link step failed! (Exit code: %)", result.exit_code));
            return false;
        }

        return true;
    }

    // https://learn.microsoft.com/en-us/cpp/c-runtime-library/crt-library-features?view=msvc-160
    crt_lib_to_static :: (original: string) -> string {
        original_lower := to_lower_copy(original);
        translated := original;
        if original_lower == {
            // UCRT
            case "ucrt.lib";       translated = "libucrt.lib";
            case "ucrtd.lib";      translated = "libucrtd.lib";

            // VCRUNTIME
            case "vcruntime.lib";  translated = "libvcruntime.lib";
            case "vcruntimed.lib"; translated = "libvcruntimed.lib";

            // CRT
            case "msvcrt.lib";     translated = "libcmt.lib";
            case "msvcrtd.lib";    translated = "libcmtd.lib";

            // C++ standard lib
            case "msvcprt.lib";    translated = "libcpmt.lib";
            case "msvcprtd.lib";   translated = "libcpmtd.lib";
        }
        return translated;
    }

    #import "Ico_File";
    #import "Windows_Resources";
} else #if OS == .MACOS {
    run_custom_link :: (w: Workspace, m: *Message_Phase) -> bool {
        compiler_report("You should not be here!");
        return false;
    }

    INFO_PLIST_CONTENTS :: #string STRING
<?xml version="1.0" ?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist>
    <dict>
        <key>CFBundleDevelopmentRegion</key>
        <string>en-US</string>

        <key>CFBundleDisplayName</key>
        <string>Focus</string>

        <key>CFBundleExecutable</key>
        <string>Focus</string>

        <key>CFBundleIconFile</key>
        <string>icon_data.icns</string>

        <key>CFBundleIdentifier</key>
        <string>dev.focus-editor</string>

        <key>CFBundleInfoDictionaryVersion</key>
        <string>6.0</string>

        <key>CFBundleName</key>
        <string>Focus</string>

        <key>CFBundlePackageType</key>
        <string>APPL</string>

        <key>CFBundleShortVersionString</key>
        <string>%</string>

        <key>CFBundleVersion</key>
        <string>%</string>

        <key>NSHumanReadableCopyright</key>
        <string>© 2023 Ivan Ivanov</string>

        <key>NSHighResolutionCapable</key>
        <true/>

        <key>CFBundleDocumentTypes</key>
        <array>
            <dict>
                <key>CFBundleTypeName</key>
                <string>Text Document</string>
                <key>CFBundleTypeRole</key>
                <string>Editor</string>
                <key>LSItemContentTypes</key>
                <array>
                    <string>public.text</string>
                </array>
                <key>NSDocumentClass</key>
                <string>Document</string>
            </dict>
            <dict>
                <key>CFBundleTypeName</key>
                <string>Text Document</string>
                <key>CFBundleTypeRole</key>
                <string>Editor</string>
                <key>LSItemContentTypes</key>
                <array>
                    <string>public.plain-text</string>
                </array>
                <key>NSDocumentClass</key>
                <string>Document</string>
            </dict>
            <dict>
                <key>CFBundleTypeName</key>
                <string>Unknown document</string>
                <key>CFBundleTypeRole</key>
                <string>Editor</string>
                <key>LSItemContentTypes</key>
                <array>
                    <string>public.data</string>
                </array>
                <key>NSDocumentClass</key>
                <string>Document</string>
            </dict>
        </array>
    </dict>
</plist>
STRING
} else #if OS == .LINUX {
    run_custom_link :: (w: Workspace, m: *Message_Phase) -> bool {
        compiler_report("You should not be here!");
        return false;
    }
}
