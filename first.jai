VERSION      :: "0.1.10";
RELEASE_DATE :: "6 June 2023";

#run build();

build :: () {
    options := get_build_options();
    options.minimum_macos_version = .{12, 0};
    args := options.compile_time_command_line;

    import_path: [..] string;
    array_add(*import_path, "modules");
    array_add(*import_path, ..options.import_path);
    options.import_path = import_path;

    set_build_options_dc(.{do_output=false});
    set_working_directory(#filepath);

    optimized := false;
    options.output_executable_name = "focus_debug";
    set_optimization(*options, .DEBUG);
    // options.arithmetic_overflow_check = .FATAL; Try uncommenting this line in 0.1.072. Doesn't work correctly on 0.1.071.

    for arg: args {
        if arg == {
          case "release";
            optimized = true;
            set_optimization(*options, .VERY_OPTIMIZED);
            options.llvm_options.enable_split_modules = false;
            options.output_executable_name = "focus";
            options.array_bounds_check = .ON;
            options.null_pointer_check = .ON;
            options.arithmetic_overflow_check = .OFF;
          case "debug";
          case;
            compiler_report(tprint("Command-line argument #%, '%', is invalid. Valid options are: 'debug', 'release'.\n", it_index+1, arg));
        }
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
    add_build_string(tprint(#string STRING
VERSION      :: "%";
RELEASE_DATE :: "%";
STRING, VERSION, RELEASE_DATE), w);

    // Add a debug marker
    if optimized {
        add_build_string("DEBUG :: false;\n", w);
    } else {
        add_build_string("DEBUG :: true;\n", w);
    }

    while true {
        message := compiler_wait_for_message();
        if message.workspace != w continue;
        if message.kind == .COMPLETE break;
    }

    compiler_end_intercept(w);

    #if OS == .WINDOWS {
        exe_name := tprint("%.exe", options.output_executable_name);

        ico_data := create_ico_file_from_bitmap_filename("images/focus.png");
        success := set_icon_by_data(exe_name, ico_data);
        if !success {
            log_error("ERROR: Couldn't set icon for '%'\n", exe_name);
        }

        manifest_options: Manifest_Options;
        success = add_manifest_to_executable(exe_name, manifest_options);
        if !success {
            log_error("ERROR: Couldn't add manifest to executable '%'\n", exe_name);
        }
    } else #if OS == .MACOS {
        if !optimized return; // When debugging, use the Unix program directly. This saves us compile time.

        // Set up our temporary directory to turn into a .dmg disk image
        DMG_DIR :: "dmg";
        run_command("mkdir", DMG_DIR);

        // Generate Focus.app inside our temporary directory
        set_working_directory(DMG_DIR);
        create_app_bundle("Focus", tprint("../%", options.output_executable_name), "../images/mac.png", "", true, true);
        write_entire_file("Focus.app/Contents/Info.plist", tprint(INFO_PLIST_CONTENTS, VERSION, VERSION));
        set_working_directory(#filepath);

        // Create a symbolic link to /Applications (what all the cool kids do)
        run_command("ln", "-s", "/Applications", DMG_DIR);

        // Generate a .DMG using Disk Utility
        run_command("hdiutil", "create", "-volname", tprint("Focus %", VERSION), "-srcfolder", DMG_DIR, "-ov", "-format", "UDZO", tprint("Focus-%-Intel.dmg", VERSION));

        // Remove our temporary directory when we're done
        run_command("rm", "-r", DMG_DIR);

        #import "MacOS_Bundler";
        #import "Process";
        #import "File";
    }
}

#import "Compiler";
#import "Basic";

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
    </dict>
</plist>
STRING
}
