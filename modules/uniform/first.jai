#load "modules/stubborn/run.jai";

#run {
	args := get_build_options().compile_time_command_line;

	entrypoint := ifx args.count then args[0] else "";
	if entrypoint == "test" {
		test_args := args;
		test_args.data += 1;
		test_args.count -= 1;

		build_tests("tests", #string END
			#load "module.jai";
			// #load "char_class.jai";
			// #load "rune.jai";
		END, "modules", args = test_args, run = true);
	} else {
		build("module.jai", .NO_OUTPUT);
	}
}

build :: (filename: string, output_type: type_of(Build_Options.output_type) = .EXECUTABLE, executable := "") {
	set_build_options_dc(.{do_output = false});

    w := compiler_create_workspace(tprint("Compile %", filename));
    build_options := get_build_options(w);
    build_options.output_type = output_type;
	build_options.output_executable_name = ifx executable then executable else basename(filename);
	// build_options.backend = .X64;
    // build_options.optimization_level = Optimization_Level.RELEASE;

	// llvm_args: [..] string;
	// array_add(*llvm_args, "-fasdgasgsanitize=address");
	// build_options.llvm_options.debug_options = llvm_args;
	import_path: [..] string;
	array_add(*import_path, .. build_options.import_path);
	array_add(*import_path, "modules");
	build_options.import_path = import_path;
    set_build_options(build_options, w);

    add_build_file(filename, w);
}

#scope_file

#import "Basic";
#import "Compiler";
#import "String";

