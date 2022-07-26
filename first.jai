#run build();

build :: () {
    options := get_build_options();
    args := options.compile_time_command_line;

    set_build_options_dc(.{do_output=false});
    set_working_directory(#filepath);

    build_debug   := false;
    build_release := false;

    for arg: args {
        if arg == {
          case "debug";
            build_debug = true;
          case "release";
            build_release = true;
          case;
            compiler_report(tprint("Command-line argument #%, '%', is invalid. Valid options are: 'debug', 'release'.\n", it_index+1, arg));
        }
    }

    if build_debug && build_release   then build_debug = false;
    if !build_debug && !build_release then build_debug = true;

    if build_debug {
        options.output_executable_name = "focus_debug";
        options.optimization_level     = .DEBUG;
    } else if build_release {
        options.output_executable_name = "focus";
        options.optimization_level     = .RELEASE;
    }

    w := compiler_create_workspace(options.output_executable_name);
    set_build_options(options, w);

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

        ico_data := Ico_File.create_ico_file_from_bitmap_filename("images/focus.png");
        success := Windows_Resources.set_icon_by_data(exe_name, ico_data);
        if !success {
            log_error("ERROR: Couldn't set icon for '%'\n", exe_name);
        }

        manifest_options: Windows_Resources.Manifest_Options;
        success = Windows_Resources.add_manifest_to_executable(exe_name, manifest_options);
        if !success {
            log_error("ERROR: Couldn't add manifest to executable '%'\n", exe_name);
        }
    }
}

#import "Compiler";
#import "Basic";

Windows_Resources :: #import "Windows_Resources";
Ico_File :: #import "Ico_File";
