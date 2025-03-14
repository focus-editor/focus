get_most_recent_projects :: () -> [] string {
    if projects_loaded_from_file  return cached_projects;

    projects := load_recent_projects_from_file();
    update_cached_projects(projects);
    projects_loaded_from_file = true;

    return cached_projects;
}

add_to_most_recent_projects :: (path: string) {
    abs_path, success := get_absolute_path(path,, temp);
    if !success {
        log_error("Couldn't get absolute path from %, can't add to most recent projects", path);
        return;
    }
    path_overwrite_separators(abs_path, #char "/");

    deduped_projects: [..] string;
    deduped_projects.allocator = temp;

    array_add(*deduped_projects, abs_path); // insert at the first position

    for project : get_most_recent_projects() {
        path_overwrite_separators(project, #char "/");
        for deduped_projects  if platform_path_equals(it, project) continue project;
        array_add(*deduped_projects, copy_temporary_string(project));
    }

    new_file_contents := tprint("%\n%\n", RECENT_PROJECTS_HEADER, join(..deduped_projects, "\n",, temp));
    target_file := get_recent_projects_file_path();
    success = write_entire_file(target_file, new_file_contents);
    if !success { log_error("Couldn't write to file %", target_file); return; }

    update_cached_projects(deduped_projects);
}

#scope_file

load_recent_projects_from_file :: () -> [] string /* temp */ {
    results: [..] string;
    results.allocator = temp;

    file_path := get_recent_projects_file_path();
    if !file_exists(file_path) return results;

    file_data, success := read_entire_file(file_path,, temp);
    if !success {
        log_error("Couldn't read file '%'", file_path);
        return results;
    }

    file_data = trim_left(file_data, " \t\n\r");  // skip empty lines, otherwise the handler will crash!
    start_from_memory(*handler, file_path, file_path, file_data);
    if handler.failed {
        log_error("Couldn't parse file '%'", file_path);
        return results;
    }

    while true {
        path, found := consume_next_line(*handler);
        if !found break;

        if !ends_with_nocase(path, ".focus-config") || !file_exists(path) continue;
        path_overwrite_separators(path, #char "/");
        array_add(*results, path);
    }

    return results;
}

update_cached_projects :: (projects: [] string) {
    push_allocator(focus_allocator);

    for cached_projects  free(it);
    array_reset_keeping_memory(*cached_projects);

    for projects {
        if !file_exists(it) {
            log_error("Project file '%' doesn't exist, so it's been removed from most recent projects.");
            continue;
        }
        array_add(*cached_projects, copy_string(it));
    }
}

get_recent_projects_file_path :: inline () -> string /* temp */ {
    return tprint("%/recent-projects", temp_dir);
}

cached_projects: [..] string;
projects_loaded_from_file := false;

RECENT_PROJECTS_HEADER :: #string DONE
[1]
# This is an automatically generated file, please do not edit it.
DONE

handler: Text_File_Handler;
