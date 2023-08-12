#run {
    assert(OS == .MACOS);
    set_build_options_dc(.{do_output = false});
    success :=  build_cpp_dynamic_lib("libLightweightRenderingView", "LightweightRenderingView.m", extra = .["-framework", "AppKit", "-framework", "QuartzCore"]);
    success &&= build_cpp_static_lib("libLightweightRenderingView", "LightweightRenderingView.m", extra = .["-framework", "AppKit", "-framework", "QuartzCore"]);
    if !success {
        compiler_set_workspace_status(.FAILED);
    }
}

#import "Basic";
#import "Compiler";
#import "BuildCpp";
