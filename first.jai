#run build();

build :: () {
    options := get_build_options();
    args := options.compile_time_command_line;

    set_build_options_dc(.{do_output=false});
    set_working_directory(#filepath);

    optimized := false;
    options.output_executable_name = "focus_debug";
    set_optimization(*options, .DEBUG);

    for arg: args {
        if arg == {
          case "release";
            optimized = true;
            set_optimization(*options, .VERY_OPTIMIZED);
            options.llvm_options.enable_split_modules = false;
            options.output_executable_name = "focus";
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

    while true {
        message := compiler_wait_for_message();
        if message.workspace != w continue;
        if message.kind == .COMPLETE break;
    }

    compiler_end_intercept(w);

    // NOTE: currently we're intercepting compiler messages only to know when the executable
    // has been written so that we can set icon and manifest

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
    }
}

#import "Compiler";
#import "Basic";

#if OS == .WINDOWS {
    #import "Ico_File";
    #import "Windows_Resources";
}
