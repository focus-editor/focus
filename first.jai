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
    build_dir := "build_debug";
    options.output_executable_name = "focus";

    // for arg: args {
    //     if arg == {
    //       case "release";
    //         optimized = true;
    //         build_dir = "build_release";
    //         set_optimization(*options, .VERY_OPTIMIZED);
    //         options.llvm_options.enable_split_modules = false;
    //         options.array_bounds_check = .ON;
    //         options.null_pointer_check = .ON;
    //         options.arithmetic_overflow_check = .OFF;
    //       case "debug";
    //       // case "no_output";
    //       //   options.output_type = .NO_OUTPUT;
    //       // case "windows7";
    //       //   windows7 = true;
    //       //   options.output_executable_name = "focus_windows7";
    //       // case;
    //       //   compiler_report(tprint("Command-line argument #%, '%', is invalid. Valid options are: 'debug', 'release'.\n", it_index+1, arg));
    //     }
    // }

    options.output_path = build_dir;
    make_directory_if_it_does_not_exist(build_dir);

    w := compiler_create_workspace(options.output_executable_name);
    set_build_options(options, w);
    // // #if OS == .WINDOWS {
    // //     // Disable runtime console
    // //     if optimized {
    // //         set_build_options_dc(.{append_linker_arguments=.["/SUBSYSTEM:windows", "/ENTRY:mainCRTStartup"]}, w);

    // //         // For tracing release builds use this:
    // //         // set_build_options_dc(.{append_linker_arguments=.["/SUBSYSTEM:windows", "/ENTRY:mainCRTStartup", "ws2_32.lib", "msvcprtd.lib"]}, w);
    // //     } else {
    // //         set_build_options_dc(.{append_linker_arguments=.["ws2_32.lib", "msvcprtd.lib"]}, w);
    // //     }
    // // }

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

    // exe_path := tprint("%/%.exe", build_dir, options.output_executable_name);

    // ico_data := create_ico_file_from_bitmap_filename("images/focus.png");
    // success := set_icon_by_data(exe_path, ico_data);
    // if !success {
    //     log_error("ERROR: Couldn't set icon for '%'\n", exe_path);
    // }

    // manifest_options: Manifest_Options;
    // success = add_manifest_to_executable(exe_path, manifest_options);
    // if !success {
    //     log_error("ERROR: Couldn't add manifest to executable '%'\n", exe_path);
    // }

}


#import "Compiler";
#import "Basic";
#import "File";
#import "Process";
#import "String";

#import "Ico_File";
#import "Windows_Resources";
