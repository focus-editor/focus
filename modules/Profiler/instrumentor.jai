#import "Basic";
#import "String";
#import "File";
#import "File_Utilities";

// This is the jai version of the C++ Instrumentor project:
// https://github.com/zjrubin/Visual_Profiler/blob/master/Instrumentor.cpp

// It basically creates a JSON file in which is logged all timing information.
// That JSON file can be used in Chrome tracing to help visualize the timings.

// Chrome tracing can be accessed by typing "chrome://tracing" in the url of
// your Google Chrome browser.

profiler_begin_session :: (name : string, json_filepath : string)
{
	ensure_directory(path_strip_filename(json_filepath));

	// @Cleanup: Need to implement a way to clear a file upon opening it
	if file_exists(json_filepath)
		file_delete(json_filepath);

	success : bool;
	file, success = file_open(json_filepath, for_writing=true, keep_existing_content=true, log_errors=true);

	if !success
	{
		log("Failed to open file at path: %", json_filepath);
		return;
	}

	assert(is_valid(file));

	write_header();

	current_session_name = name;
	log_count = 0;
}

profiler_end_session :: ()
{
	assert(is_valid(file));

	write_footer();
	file_close(*file);
	file.handle = null;
	current_session_name = "";

	profile_count = 0;
	log_count = 0;
}

#scope_module

profiler_write_profile :: (marker : *Profiler_Marker)
{
	if !is_valid(file)
		return;

	if log_count >= 500000
	{
		if log_count == 500000
		{
			log("500000 logs have been written already. To prevent the log file from getting too big, nothing will be logged in this file anymore. Please try to profile for shorter periods.");
			log_count += 1;
		}

		return;
	}

	log_count += 1;

	sb : String_Builder;
	init_string_builder(*sb);
	defer free_buffers(*sb);

	if profile_count != 0
		append(*sb, ",");

	profile_count += 1;

	name := marker.name;

	append(*sb, "\n\t\t{");

	print_to_builder(*sb, "%\"cat\": \"function\",",	INDENT_3C);
	print_to_builder(*sb, "%\"dur\": %,",				INDENT_3C, (marker.end_time - marker.start_time) * 1000000);
	print_to_builder(*sb, "%\"name\": \"%\",",			INDENT_3C, name);
	print_to_builder(*sb, "%\"ph\": \"X\",",			INDENT_3C);
	print_to_builder(*sb, "%\"pid\": 0,",				INDENT_3C);
	print_to_builder(*sb, "%\"tid\": %,",				INDENT_3C, marker.thread_id);
	print_to_builder(*sb, "%\"ts\": %",					INDENT_3C, get_unique_start_time_ns(marker.start_time));

	append(*sb, "\n\t\t}");

	file_write(*file, *sb);
}

#scope_file

log_count := 0;

get_unique_start_time_ns :: (value : float64) -> float64
{
	result := value * 1000000;

	if result == last_start_time
	{
		result += 1;
	}

	last_start_time = result;

	return result;
}

last_start_time : float64 = -1;

profile_count			:= 0;
file					: File;
current_session_name	: string;

INDENT_3C :: "\n\t\t\t";

ensure_directory :: (_path: string)
{
	path := _path;
	if path.count && path[path.count-1] == #char "/" {
		path.count -= 1;
	}

	if path == "" return;
	parent := path_strip_filename(path);
	ensure_directory(parent);

	make_directory_if_it_does_not_exist(path);
}

write_header :: inline ()
{
	assert(is_valid(file));

	sb : String_Builder;
	init_string_builder(*sb);
	defer free_buffers(*sb);

	append(*sb, "{");
	append(*sb, "\n\t\"otherData\": {},");
	append(*sb, "\n\t\"traceEvents\": [");

	file_write(*file, *sb);
}

write_footer :: inline ()
{
	assert(is_valid(file));

	sb : String_Builder;
	init_string_builder(*sb);
	defer free_buffers(*sb);

	append(*sb, "\n\t]");
	append(*sb, "\n}");

	file_write(*file, *sb);
}
