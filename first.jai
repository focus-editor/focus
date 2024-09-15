VERSION      :: #run -> string {
    result, revision := run_command("git", "rev-parse", "--short", "HEAD", capture_and_return_output = true);
    if revision return sprint("0.3.7-%", trim(revision));
    return "0.3.7-dev";
}
RELEASE_DATE :: #run -> string {
    current_time := to_calendar(current_time_consensus());
    return calendar_to_string(current_time);
}

// // NOTE: Uncomment when releasing, comment out when not releasing
// VERSION :: "0.3.7";
// RELEASE_DATE :: "15 September 2024";

#run,stallable build();

build :: () {
    options := get_build_options();
    options.minimum_os_version = .{10, 13};
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
            VERSION      :: "%";
            RELEASE_DATE :: "%";
            DEBUG        :: %;
            WINDOWS7     :: %;
        STRING,
            VERSION,
            RELEASE_DATE,
            ifx optimized then "false" else "true",
            ifx windows7  then "true"  else "false",
    );
    add_build_string(build_constants, w);

    failed := false;
    while true {
        message := compiler_wait_for_message();
        if message.workspace != w continue;
        if message.kind == .PHASE {
            phase_message := cast(*Message_Phase) message;
            if phase_message.phase == .ALL_TARGET_CODE_BUILT {
                if options.output_type == .NO_OUTPUT  exit(0);
            }
        } else if message.kind == .COMPLETE {
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

#import "Compiler";
#import "Basic";
#import "File";
#import "Process";
#import "String";

#if OS == .WINDOWS {
    #import "Ico_File";
    #import "Windows_Resources";
} else #if OS == .MACOS {
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
}
