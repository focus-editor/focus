#run {
    assert(OS == .MACOS);
    set_build_options_dc(.{do_output = false});

    macos_x64_version_arg   := "-mmacos-version-min=10.13"; // Our current x64 min version
    macos_arm64_version_arg := "-mmacos-version-min=11.0";  // Earliest version that supports arm64
    // x64 variant
    success :=  build_cpp_dynamic_lib("libLightweightRenderingView_x64", "LightweightRenderingView.m", extra = .["-arch", "x86_64", "-framework", "AppKit", "-framework", "QuartzCore", macos_x64_version_arg]);
    success &&= build_cpp_static_lib( "libLightweightRenderingView_x64", "LightweightRenderingView.m", extra = .["-arch", "x86_64", "-framework", "AppKit", "-framework", "QuartzCore", macos_x64_version_arg]);
    // arm64 variant
    success &&= build_cpp_dynamic_lib("libLightweightRenderingView_arm64", "LightweightRenderingView.m", extra = .["-arch", "arm64", "-framework", "AppKit", "-framework", "QuartzCore", macos_arm64_version_arg]);
    success &&= build_cpp_static_lib( "libLightweightRenderingView_arm64", "LightweightRenderingView.m", extra = .["-arch", "arm64", "-framework", "AppKit", "-framework", "QuartzCore", macos_arm64_version_arg]);

    // create universal binaries
    run_result := run_command("lipo", "-create", "libLightweightRenderingView_x64.dylib", "libLightweightRenderingView_arm64.dylib", "-output", "libLightweightRenderingView.dylib");
    success &&= (run_result.exit_code == 0);
    run_result =  run_command("lipo", "-create", "libLightweightRenderingView_x64.a",     "libLightweightRenderingView_arm64.a",     "-output", "libLightweightRenderingView.a");
    success &&= (run_result.exit_code == 0);
    if !success {
        compiler_set_workspace_status(.FAILED);
    }
}

#import "Basic";
#import "Compiler";
#import "BuildCpp";
#import "Process";
