#run build();

build :: () {
    options := get_build_options();
    args := options.compile_time_command_line;

    set_build_options_dc(.{do_output=false});
    set_working_directory(#filepath);

    options.optimization_level = .DEBUG;
    options.output_executable_name = "focus_debug";

    for arg: args {
        if arg == {
          case "release";
            set_optimization_level(*options, 2, 0);
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
        if options.optimization_level == .RELEASE {
            set_build_options_dc(.{append_linker_arguments=.["/SUBSYSTEM:windows", "/ENTRY:mainCRTStartup"]}, w);
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

#import "Ico_File";
#import "Windows_Resources";
