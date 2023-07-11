#module_parameters(ENABLE_BACKTRACE_ON_CRASH: bool);

debug_break :: () #no_context {
    if #compile_time {
        compile_time_debug_break :: () #compiler #no_context;
        compile_time_debug_break();
    } else {
        // Break into the debugger, or stop the running process.
        #if OS == .PS5 {
            #asm { int 0x41; }
        } else {
            #asm { int3; }
        }
    }
}


// @Cleanup: __element_duplicate should lose its c_call status, and also be faster...!
__element_duplicate :: (start: *u8, num_elements: s64, size: s64) #c_call {
    cursor := start + size;
    for 1..num_elements-1 {
        memcpy(cursor, start, size);
        cursor += size;
    }
}

write_nonnegative_number :: (n: u64, base := 10, to_standard_error := false) #no_context {
    if n == 0 {
        write_string("0", to_standard_error);
        return;
    }

    if base > 16  base = 16;
    if base < 2   base = 2;

    ubase := cast(u64) base;

    // This is of course a horrible hack.
    // A u64 in base 2 can be up to 64 digits,
    // so we need at least that much space. Add a few more digits for superstition.
    N :: 69;
    buf: [69] u8;

    starting_cursor : s32 = N;
    cursor := starting_cursor;

    while n {
        cursor -= 1;
        index := n % ubase;
        if index <= 9 {
            buf[cursor] = cast(u8)(index + #char "0");
        } else {
            buf[cursor] = cast(u8)(index - 10 + #char "a");
        }

        n /= ubase;
    }

    s: string = ---;
    s.data  = buf.data + cursor;
    s.count = starting_cursor - cursor;
    write_string(s, to_standard_error);
}

write_number :: (n: s64, base := 10, to_standard_error := false) #no_context {
    if n < 0 {
        write_string("-", to_standard_error);
        n = -n;
    }

    write_nonnegative_number(cast,no_check(u64) n, base, to_standard_error = to_standard_error);
}

write_loc :: (loc: Source_Code_Location, to_standard_error := false) #no_context {
	write_string(loc.fully_pathed_filename, to_standard_error);
	write_string(":", to_standard_error);
	write_number(loc.line_number, to_standard_error = to_standard_error);
	write_string(",", to_standard_error);
	write_number(loc.character_number, to_standard_error = to_standard_error);
}

runtime_support_assertion_failed :: (loc: Source_Code_Location, message: string) {
    write_loc(loc, to_standard_error = true);
	write_string(": Assertion failed", to_standard_error = true);

	if message {
		write_string(": ", to_standard_error = true);
		write_string(message, to_standard_error = true);
		write_string("\n", to_standard_error = true);
	} else {
		write_string("!\n", to_standard_error = true);
	}

    report_failed_assertion_more_visibly(loc, message);

    print_stack_trace :: (node: *Stack_Trace_Node) {  // @Cutnpaste from modules/Basic, but wihtout calling print.
        while node {
            // There are two different line numbers available.
            // node.info.location has a line number, but this is the location of
            // the start of the procedure. That may be useful in some cases, but often
            // what we really want is the line number of the procedure call, which is
            // stored in node.line_number. That's what we print in this case.

            if node.info {
                write_string(node.info.location.fully_pathed_filename, to_standard_error = true);
                write_string(":", to_standard_error = true);
                write_nonnegative_number(node.line_number, to_standard_error = true);
                write_string(": ", to_standard_error = true);
                if node.info.name write_string(node.info.name, to_standard_error = true);
                else write_string("(anonymous procedure)", to_standard_error = true);
                write_string("\n", to_standard_error = true);
            }

            node = node.next;
        }
    }

    if context.stack_trace {
        write_string("\nStack trace:\n", to_standard_error = true);
        print_stack_trace(context.stack_trace);
    } else {
        write_string("Exiting.\n", to_standard_error = true);
    }

    __runtime_support_disable_stack_trace = true;
    debug_break();
}

runtime_support_default_logger :: (message: string, data: *void, info: Log_Info) {
    if !message then return;

    to_standard_error := (info.common_flags & .ERROR) != 0;

    if message[message.count-1] != #char "\n" {
        write_strings(message, "\n", to_standard_error = to_standard_error);
    } else {
        write_string(message, to_standard_error = to_standard_error);
    }
}

my_panic :: () #no_context {
    write_string("Panic.\n", to_standard_error = true);
    debug_break();
}

__panic_due_to_runtime_call_of_compile_time_procedure :: (line_number: s64, filename: *u8) #no_context {
    write_string("Error: Attempt to call a compile-time procedure at runtime. The location of the call was: ", to_standard_error = true);
    write_string(to_string(filename), to_standard_error = true);
    write_string(":", to_standard_error = true);
    write_number(line_number, to_standard_error = true);
    write_string(".\n", to_standard_error = true);

    my_panic();
}

c_style_strlen :: (str: *u8) -> s64 #no_context {
    p := str;
    while << p  { p += 1; }
    return p - str;
}

to_string :: (c_string: *u8) -> string #no_context {
    if c_string == null return "";

    s: string = ---;
    s.data = c_string;
    s.count = c_style_strlen(c_string);

    return s;
}

// @Incomplete: Pass loc to Runtime_Support versions.
__array_bounds_check_fail :: (index: s64, limit: s64, line_number: s64, filename: *u8) #no_context {
    // @Volatile: It is a good idea for these to match the error reports in constant-expression evaluation inside the compiler.
    write_string("Array bounds check failed. (The attempted index is ", to_standard_error = true);
    write_number(index, to_standard_error = true);

    if limit > 0 {
        write_string(", but the highest valid index is ", to_standard_error = true);
        write_number(limit-1, to_standard_error = true);
    } else if limit == 0 {
        write_string(", but the array has dimension 0, so no index is valid", to_standard_error = true);
    } else {
        write_string(", but the array has invalid negative dimension ", to_standard_error = true);
        write_number(limit, to_standard_error = true);
    }

    write_string("). Site is ", to_standard_error = true);
    write_string(to_string(filename), to_standard_error = true);
    write_string(":", to_standard_error = true);
    write_number(line_number, to_standard_error = true);
    write_string(".\n", to_standard_error = true);

    report_bounds_check_error_more_visibly(index, limit, line_number, filename);

    my_panic();
}

__cast_bounds_check_fail :: (pre_value: s64, pre_flags: u32, post_value: s64, post_flags: u32, fatal: u8, line_number: s64, filename: *u8) #no_context {
    bits : s32 = 0;

    NUMBER_FLAG_SIGNED   :: 0x40;
    NUMBER_FLAG_8BIT     :: 0x100;
    NUMBER_FLAG_16BIT    :: 0x200;
    NUMBER_FLAG_32BIT    :: 0x400;
    NUMBER_FLAG_64BIT    :: 0x800;

    if post_flags & NUMBER_FLAG_64BIT bits = 64;
    if post_flags & NUMBER_FLAG_32BIT bits = 32;
    if post_flags & NUMBER_FLAG_16BIT bits = 16;
    if post_flags & NUMBER_FLAG_8BIT  bits = 8;

    write_string("Cast bounds check failed.  Number must be in [", to_standard_error = true);

    if post_flags & NUMBER_FLAG_SIGNED {
        high_value := (1 << (bits - 1)) - 1;
        low_value  := ~high_value;
        write_number(low_value, to_standard_error = true);
        write_string(", ", to_standard_error = true);
        write_number(high_value, to_standard_error = true);
    } else {
        // We don't yet have our stringent definition of left-shift, so, we are generating results
        // that will vary on different machines unless we check. So let's check.
        high_value: u64;
        if bits == 64 {
            high_value = 0xffff_ffff_ffff_ffff;
        } else {
            high_value = ((cast(u64)1) << bits) - 1;
        }

        write_string("0, ", to_standard_error = true);
        write_nonnegative_number(high_value, to_standard_error = true);
    }

    write_string("]; it was ", to_standard_error = true);

    if pre_flags & NUMBER_FLAG_SIGNED {
        write_number(pre_value, to_standard_error = true);
    } else {
        write_nonnegative_number(cast,no_check(u64) pre_value, to_standard_error = true);
    }

    write_string(".  Site is ", to_standard_error = true);

	write_string(to_string(filename), to_standard_error = true);
    write_string(":", to_standard_error = true);
	write_number(line_number, to_standard_error = true);
    write_string(".\n", to_standard_error = true);

    if fatal my_panic();
}

__null_pointer_check_fail :: (index: s64, line_number: s64, filename: *u8) #no_context {
    // @Volatile: It is a good idea for these to match the error reports in constant-expression evaluation inside the compiler.
    if index {
        // This is a procedure argument.
        write_string("Null pointer check failed: Argument ", to_standard_error = true);
        write_number(index, to_standard_error = true);
        write_string(" is undergoing an automatic dereference, but the pointer is null. Site is ", to_standard_error = true);
    } else {
        // It was a dereference that happened in some other way.
        write_string("Null pointer check failed: A pointer is undergoing an automatic dereference, but the pointer is null. Site is ", to_standard_error = true);
    }

    write_string(to_string(filename), to_standard_error = true);
    write_string(":", to_standard_error = true);
    write_number(line_number, to_standard_error = true);
    write_string(".\n", to_standard_error = true);

    report_null_pointer_error_more_visibly(index, line_number, filename);

    my_panic();
}

__arithmetic_overflow :: (left: s64, right: s64, type_code: u16, line_number: s64, filename: *u8) #no_context #no_aoc {
    // We have some free bits in type_code...!
    fatal  := (type_code & 0x8000);
    signed := (type_code & 0x4000);
    operator_index := (type_code >> 7) & 0x3;
    size := (cast(u64)(type_code & 0x000f))*8;

    signed_string := ifx signed then "s" else "u";
    operator_string := " / ";
    
    if      operator_index == 1 then operator_string = " + ";
    else if operator_index == 2 then operator_string = " - ";
    else if operator_index == 3 then operator_string = " * ";
    
    write_string("Arithmetic overflow. We tried to compute:\n    ", to_standard_error = true);

    if signed  write_number(left, to_standard_error = true);
    else       write_nonnegative_number(cast,no_check(u64)left, to_standard_error = true);

    write_string(operator_string, to_standard_error = true);
    
    if signed  write_number(right, to_standard_error = true);
    else       write_nonnegative_number(cast,no_check(u64)right, to_standard_error = true);
    
    write_strings("\nThe operand type is ", signed_string, to_standard_error = true);
    write_nonnegative_number(size, to_standard_error = true);
    write_string(", but the result does not fit into this type.\n", to_standard_error = true);
    
    if fatal my_panic();
}

__relative_pointer_bounds_check_fail :: (delta: s64, size: u8, line_number: s64, filename: *u8) #no_context {
    // @Volatile: It is a good idea for these to match the error reports in constant-expression evaluation inside the compiler.
    upper_limit := (1 << (size * 8 - 1)) - 1;
    write_string("Relative pointer bounds check failed. (Delta is ", to_standard_error = true);
    write_number(delta, to_standard_error = true);
    write_string(", valid range is from ", to_standard_error = true);
    write_number(-upper_limit, to_standard_error = true);
    write_string(" to ", to_standard_error = true);
    write_number(upper_limit, to_standard_error = true);
    write_string(", inclusive). Site is ", to_standard_error = true);

    write_string(to_string(filename), to_standard_error = true);
    write_string(":", to_standard_error = true);
    write_number(line_number, to_standard_error = true);
    write_string(".\n", to_standard_error = true);

    my_panic();
}

write_string_unsynchronized :: (s: string, to_standard_error := false) #no_context {
    #if OS == .NONE {
        // Let the user fill this in, if desired.
    } else #if OS == .WINDOWS {
        // @Robustness @Incomplete: Fails if s.count doesn't fit in an u32.
        written: u32;
        handle := ifx to_standard_error then windows_standard_error else windows_standard_output;
        status := WriteFile(handle, s.data, cast(u32) s.count, *written, null);
    } else {
        STDOUT_FILENO : s32 : 1;
        STDERR_FILENO : s32 : 2;
        handle := ifx to_standard_error then STDERR_FILENO else STDOUT_FILENO;
        written: ssize_t;

        while written != s.count {
            result := write(handle, s.data + written, cast(u64) (s.count - written));
            // We should probably be checking errno for failures,
            // but, on macOS at least, we seem to be getting interrupted
            // only be EAGAIN.
            if result < 0 continue;

            written += result;
        }
    }
}

write_string :: (s: string, to_standard_error := false) #no_context #compiler {
    // write_string is marked #compiler because, if called at compile-time, it
    // involves a different implementation that also syncs with the compiler's output.
    // This runtime version of write_string is just about syncing the threads
    // in your own program.

    one_time_init(*synch_initted, init_synchronization());

    #if OS == .NONE {
        // Let the user fill this in, if desired.
        write_string_unsynchronized(s, to_standard_error);
    } else #if OS == .WINDOWS {
        EnterCriticalSection(*write_string_critical_section);
        write_string_unsynchronized(s, to_standard_error);
        LeaveCriticalSection(*write_string_critical_section);
    } else {
        pthread_mutex_lock(*write_string_mutex);
        write_string_unsynchronized(s, to_standard_error);
        pthread_mutex_unlock(*write_string_mutex);
    }
}

write_strings :: (strings: ..string, to_standard_error := false) #no_context #compiler {
    // write_strings is marked #compiler because, if called at compile-time, it
    // involves a different implementation that also syncs with the compiler's output.
    // This runtime version of write_strings is just about syncing the threads
    // in your own program.

    one_time_init(*synch_initted, init_synchronization());

    #if OS == .NONE {
        // Let the user fill this in, if desired.
        for strings write_string_unsynchronized(it, to_standard_error);
    } else #if OS == .WINDOWS {
        EnterCriticalSection(*write_string_critical_section);
        for strings write_string_unsynchronized(it, to_standard_error);
        LeaveCriticalSection(*write_string_critical_section);
    } else {
        pthread_mutex_lock(*write_string_mutex);
        for strings write_string_unsynchronized(it, to_standard_error);
        pthread_mutex_unlock(*write_string_mutex);
    }
}

init_synchronization :: () #no_context {
    // For now, we do not bother to destroy write_string_critical_section, etc
    // on shutdown.
    #if OS == .NONE {
        // Let the user fill this in, if desired.
    } else #if OS == .WINDOWS {
        InitializeCriticalSection :: (section: *_CRITICAL_SECTION) #foreign kernel32;
        InitializeCriticalSection(*write_string_critical_section);

        STD_OUTPUT_HANDLE :: -11;
        STD_ERROR_HANDLE  :: -12;
        windows_standard_output = GetStdHandle(STD_OUTPUT_HANDLE);
        windows_standard_error  = GetStdHandle(STD_ERROR_HANDLE);
    } else {
        _pthread_mutexattr_t :: struct { size: [16] s8; }
        #if OS == .MACOS {
            _PTHREAD_MUTEX_RECURSIVE_NP :: 2;
        } else {
            _PTHREAD_MUTEX_RECURSIVE_NP :: 1;
        }
        pthread_mutexattr_init    :: (attr: *_pthread_mutexattr_t) -> s32             #foreign pthreads;
        pthread_mutexattr_settype :: (attr: *_pthread_mutexattr_t, type:  s32) -> s32 #foreign pthreads;
        pthread_mutex_init        :: (mutex: *_pthread_mutex_t, attr: *_pthread_mutexattr_t) -> s32 #foreign pthreads;

        attr: _pthread_mutexattr_t;
        pthread_mutexattr_init(*attr);
        pthread_mutexattr_settype(*attr, _PTHREAD_MUTEX_RECURSIVE_NP);
        pthread_mutex_init(*write_string_mutex, *attr);  // This had better not fail!
    }
}

// TEMPORARY_STORAGE_SIZE is defined by the compiler based on Build_Options.

first_thread_context: Context;
first_thread_stack_trace_node: Stack_Trace_Node;
first_thread_temporary_storage: Temporary_Storage;
first_thread_temporary_storage_data: [TEMPORARY_STORAGE_SIZE] u8 #align 64;

#program_export
__jai_runtime_init :: (argc: s32, argv: **u8) -> *Context #c_call {
    __command_line_arguments.count = argc;
    __command_line_arguments.data  = argv;

    ts := *first_thread_temporary_storage;
    set_initial_data(ts, TEMPORARY_STORAGE_SIZE, first_thread_temporary_storage_data.data);

    first_thread_context.temporary_storage = ts;

    first_thread_context.base.context_info = type_info(Context);

    dummy_context: Context;
    dummy_context.base.context_info = type_info(Context);
    push_context dummy_context {
        // Allocator should not rely on a good context for STARTUP. For other modes, it's fine.
        first_thread_context.allocator.data = runtime_support_default_allocator_proc(.STARTUP, 0, 0, null, null);
    }

    return *first_thread_context;
}

#program_export
__jai_runtime_fini :: (_context: *void) #c_call {
    // Nothing here for now!
    // We don't bother shutting down the default allocator. The OS frees the memory.
}

__instrumentation_first  :: () {
}

__instrumentation_second :: () {
}

#program_export "main"
__system_entry_point :: (argc: s32, argv: **u8) -> s32 #c_call {
    __jai_runtime_init(argc, argv);

    push_context first_thread_context {
        #if ENABLE_BACKTRACE_ON_CRASH {
            // It's possible we should move the init of the crash handler to after __instrumentation_*, so that
            // plugins can set it? But, plugin inits can crash. So maybe we need some other way for a plugin
            // to say it's taking over the crash handler.

            Handler :: #import "Runtime_Support_Crash_Handler";
            Handler.init();
        }

        __instrumentation_first ();
        __instrumentation_second();

        __program_main :: () #runtime_support;
        __program_main();
    }

    return 0;
}

Default_Allocator :: #import "Default_Allocator";

runtime_support_default_allocator_proc :: Default_Allocator.allocator_proc;

#scope_file
#if OS == .WINDOWS {
    kernel32     :: #system_library "kernel32";

    WriteFile    :: (handle: *void, buffer: *void, buffer_length: u32, written_result: *u32, overlapped: *void) -> s32 #foreign kernel32;
    GetStdHandle :: (handle: s32) -> *void #foreign kernel32;

    EnterCriticalSection :: (lpCriticalSection: *_CRITICAL_SECTION) #foreign kernel32;
    LeaveCriticalSection :: (lpCriticalSection: *_CRITICAL_SECTION) #foreign kernel32;

    // Our mutex / critical sections are just dummies to hold as much memory as we need, so we don't bloat Runtime_Support.
    _CRITICAL_SECTION :: struct {
        memory: [40] u8;
    }

    write_string_critical_section: _CRITICAL_SECTION;
    windows_standard_output: *void;
    windows_standard_error: *void;
} else #if OS == .MACOS || OS == .LINUX || OS == .PS5 {
    crt      :: #system_library "libc";
    #if OS == .MACOS {
        pthreads :: #system_library "libc";
    } else {
        pthreads :: #system_library "libpthread";
    }

    pthread_mutex_lock    :: (mutex: *_pthread_mutex_t) -> s32 #foreign pthreads;
    pthread_mutex_unlock  :: (mutex: *_pthread_mutex_t) -> s32 #foreign pthreads;

    size_t  :: u64;
    ssize_t :: s64;
    write :: (fd: s32, buf: *void, count: size_t) -> ssize_t #foreign crt;

    // Our mutex / critical sections are just dummies to hold as much memory as we need, so we don't bloat Runtime_Support.
    // @Volatile: These types have to fit the real declarations on each platform!
    #if OS == .MACOS {
        _pthread_mutex_t :: struct {
            __sig:    s64;
            __opaque: [56] u8;
        }
    } else {
        _pthread_mutex_t :: struct {
            memory: [40] u8;
        }
    }

    write_string_mutex: _pthread_mutex_t;
}
#scope_export

synch_initted: s32 = 0;


#scope_file

// Below are the functions we've added.

report_bounds_check_error_more_visibly :: (index: s64, limit: s64, line_number: s64, filename: *u8) #no_context {
    ctx: Context;
    push_context ctx {
        report_error_in_yer_face("Array bounds check failed in file % at line number %: \nProvided index: %, maximum index: %\n", to_string(filename), line_number, index, limit);
    }
}

report_null_pointer_error_more_visibly :: (index: s64, line_number: s64, filename: *u8) #no_context {
    ctx: Context;
    push_context ctx {
        if index {
            // This is a procedure argument.
            report_error_in_yer_face("Null pointer check failed in file % at line number %: \nArgument % is undergoing an automatic dereference, but the pointer is null.", to_string(filename), line_number, index);
        } else {
            // It was a dereference that happened in some other way.
            report_error_in_yer_face("Null pointer check failed in file % at line number %: \nA pointer is undergoing an automatic dereference, but the pointer is null.", to_string(filename), line_number);
        }
    }
}

report_failed_assertion_more_visibly :: (loc: Source_Code_Location, msg: string) {
    report_error_in_yer_face("Assertion failed in file % at line %, char %: \n%", loc.fully_pathed_filename, loc.line_number, loc.character_number, msg);
}

report_error_in_yer_face :: (message: string, args: .. Any) {
    System :: #import "System";
    String :: #import "String";
    Basic :: #import "Basic";
    File :: #import "File";
    // Log it in a crash report file next to the exe
    exe_dir := String.path_strip_filename(System.get_path_of_running_executable());
    crash_report_file_path := Basic.sprint("%/focus-crash-report.txt", exe_dir);
    formatted_message := Basic.sprint(message, ..args);
    File.write_entire_file(crash_report_file_path, formatted_message);

    // Show a Windows message box
    #if OS == .WINDOWS {
        W :: #import "Windows";
        W_Utf8 :: #import "Windows_Utf8";
        W.MessageBoxW(null, W_Utf8.utf8_to_wide(formatted_message), W_Utf8.utf8_to_wide("Fatal Error"), W.MB_OK);
    }
}

// END of the functions we've added