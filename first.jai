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

    workspace_name := options.output_executable_name;
    w := create_workspace(options, workspace_name);
    add_build_file("src/main.jai", w);

}

create_workspace :: (opts: Build_Options, workspace_name := "") -> Workspace {
    w := compiler_create_workspace(workspace_name);
    set_build_options(opts, w);
    return w;
}

#import "Compiler";
#import "Basic";
