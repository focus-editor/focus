#import "Basic";

#module_parameters(ENABLE_PROFILER : bool = true);

#if !ENABLE_PROFILER
{
	PROFILE_SCOPE :: (name : string) #expand {}
	PROFILE_FUNCTION :: () #expand {}

	profiler_begin_session :: (name : string, json_filepath : string) #expand {}
	profiler_end_session :: () #expand {}
}

#if ENABLE_PROFILER
{
	#load "instrumentor.jai";

	Profiler_Marker :: struct
	{
		name		: string;
		start_time	: float64;
		end_time	: float64;
		thread_id	: u32;
	}

	PROFILE_SCOPE :: (name : string) #expand
	{
		`push_profiler_marker(name);
		`defer pop_profiler_marker(name);
	}

	PROFILE_FUNCTION :: () #expand
	{
		`push_profiler_marker_with_context_name(#this);
		`defer pop_profiler_marker_with_context_name(#this);
	}

	// Do NOT inline these two functions. Calling this makes it so the stack_trace is populated with
	// the caller's name (the stack_trace is one function late)
	push_profiler_marker_with_context_name :: (proc: $T)
	{
		signature := tprint("%", T);
		signature.count -= 10; signature.data  += 10; // removes 'procedure '
		name := tprint("% :: %", ifx context.stack_trace != null then context.stack_trace.info.name else "", signature);
		push_profiler_marker(name);
	}

	pop_profiler_marker_with_context_name :: (proc: $T)
	{
		signature := tprint("%", T);
		signature.count -= 10; signature.data  += 10; // removes 'procedure '
		name := tprint("% :: %", ifx context.stack_trace != null then context.stack_trace.info.name else "", signature);
		pop_profiler_marker(name);
	}

	push_profiler_marker :: (name : string)
	{
		marker : Profiler_Marker;
		marker.name			= name;
		marker.start_time	= get_time();
		marker.thread_id	= context.thread_index;
		marker.end_time		= -1;

		array_add(*active_markers, marker);
	}

	pop_profiler_marker :: (name : string)
	{
		marker := pop(*active_markers);
		assert(marker.name == name);
		marker.end_time = get_time();

		profiler_write_profile(*marker);
	}

#scope_file

	active_markers : [..]Profiler_Marker;
}
