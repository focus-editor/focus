#run {
    assert(OS == .MACOS);
    set_build_options_dc(.{do_output = false});

    MACOS_VERSION_ARG :: #run -> string {
        using options := get_build_options();
        return tprint("-mmacosx-version-min=%.%", minimum_os_version.major, minimum_os_version.minor);
    }

    success :=  build_cpp_dynamic_lib("libLightweightRenderingView", "LightweightRenderingView.m", extra = .["-framework", "AppKit", "-framework", "QuartzCore", MACOS_VERSION_ARG]);
    success &&= build_cpp_static_lib("libLightweightRenderingView", "LightweightRenderingView.m", extra = .["-framework", "AppKit", "-framework", "QuartzCore", MACOS_VERSION_ARG]);
    if !success {
        compiler_set_workspace_status(.FAILED);
    }
}

#import "Basic";
#import "Compiler";
#import "BuildCpp";
