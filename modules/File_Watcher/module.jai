// At startup, call init() to create one or more watchers.
// Start watching directories by calling add_directories(). This will watch this directory and (and all subdirectories).
// Call deinit() to stop watching.

// Periodically call process_changes to get notified of any changes that have happened since the last call.
// Your callback will be called for every change.

File_Change :: struct {
    full_path:  string;   // The fully-pathed filename.
	events: File_Change_Event;
    // @ToDo: We should probably replace this with Apollo_Time
    time_of_last_change := 0.0;  // What time it last changed. It's a bad idea to use floating-point numbers for time, but, we did that here. This time is computed by Basic.get_time(). Maybe we should let you override this.
}

File_Change_Event :: enum_flags {
    ADDED;
    MODIFIED;

    // You might get two MOVED events if a file gets renamed, one for the old path and one for the new path.
    // File_Watcher will add the modifiers MOVED_FROM or MOVED_TO to a MOVED event if it knows that this event is for the old path or new path, respectively.
    // But for example on macOS you might get just two MOVED events and have to check the full_path and see if that file still exists to know which part of the move the event belongs to.
    // Also, you might only get events for part of the move if the file gets moved from an unwatched folder into a watched folder or vice versa.
    MOVED;
    MOVED_FROM; // Will be combined with MOVED if we know that the MOVED event is for the old path.
    MOVED_TO;   // Will be combined with MOVED if we know that the MOVED event is for the new path.

    ATTRIBUTES_CHANGED;
    REMOVED;

    SCAN_CHILDREN; // Indicates that you might need to check all children of this directory for changes. If a directory gets added/moved we don't automatically get change notifications for all of its children.

    ALL_EVENTS :: ADDED | MODIFIED | MOVED | ATTRIBUTES_CHANGED | REMOVED;
}

DEFAULT_BUFFER_SIZE :: 8000;

File_Watcher :: struct (User_Data: Type = void) {
    File_Watcher_Callback :: #type (watcher: *File_Watcher(User_Data), change: *File_Change, user_data: *User_Data);

    callback: File_Watcher_Callback;
    user_data: *User_Data;
    events_to_watch: File_Change_Event;
	merge_window_seconds: float;
    watch_recursively: bool;
	verbose: bool;
    buffer_size: s32;

    // @Stability: pool needs to be dynamically allocated since we don't control the lifetime of File_Watcher.
    // If pool were a direct member of File_Watcher and that gets copied and discarded (eg by adding it to an array), then arrays like "changes" could still point to the old copy of Pool.
    //   -rluba, 2022-06-06
    pool: *Pool;
	changes: [..] File_Change;

    #if OS == .WINDOWS {
        directories: [..] *Directory_Info;
    } else #if OS == .LINUX {
        inotify_instance: s32 = -1;
        inotify_data: *void;
        inotify_bytes_read: ssize_t;
        inotify_cursor: s32;
        path_pool: *Pool; // A second pool to avoid one allocation per directory in the tree we watch
        watch_paths: Table(s32, string);
    } else #if OS == .MACOS {
        event_streams: [..] FSEventStreamRef;
    } else #if OS == .PS5 {
    } else {
        #assert(false);
    }
}

// Use events_to_watch to specify what kinds of events you're interested in. (But you might still get events from categories you didn't ask for, depending on the platform.)
// event_buffer_size is allocated _once_ on Linux but _once per directory_ on Windows. (It’s not used at all on macOS.) Therefore, using the same value on Linux and Windows might result in very different total memory usage.
init :: (watcher: *$T/File_Watcher, callback: T.File_Watcher_Callback, user_data: *T.User_Data = null, events_to_watch: File_Change_Event = .ALL_EVENTS, merge_window_seconds: float = 0.1, watch_recursively := true, verbose := false, event_buffer_size: s32 = DEFAULT_BUFFER_SIZE) -> success: bool {
    watcher.callback = callback;
    watcher.user_data = user_data;
    watcher.events_to_watch = events_to_watch;
	watcher.merge_window_seconds = merge_window_seconds;
    watcher.watch_recursively = watch_recursively;
	watcher.verbose = verbose;
    watcher.buffer_size = event_buffer_size;

    watcher.pool = New(Pool);
    set_allocators(watcher.pool);
    // watcher.pool.overwrite_memory = true;  // Enable this for basic memory debugging.

    watcher.changes.allocator.proc = pool_allocator_proc;
    watcher.changes.allocator.data = watcher.pool;

    #if OS == .LINUX {
        watcher.inotify_instance = inotify_init(IN_NONBLOCK);
        if watcher.inotify_instance == -1 {
            log_error("Could not init inotify: %", errno());
            free(watcher.pool);
            return false;
        }

        watcher.inotify_data = alloc(event_buffer_size);
        watcher.path_pool = New(Pool);
        set_allocators(watcher.path_pool);
        init(*watcher.watch_paths);
    }
    #if OS == .MACOS {
        if !watch_recursively {
            log_error("Ignoring \"watch_recursively = false\" flag since macOS always watches directories recursively.");
        }
    }
	return true;
}

add_directories :: (using watcher: *$T/File_Watcher, dir_paths: ..string) -> bool {
    assert(callback != null, "You must call init() on the File_Watcher before add_directories()!");
    #if OS == .WINDOWS {
        return add_directories_windows(watcher, ..dir_paths);
    } else #if OS == .LINUX {
        return add_directories_linux(watcher, ..dir_paths);
    } else #if OS == .MACOS {
        return add_directories_macos(watcher, ..dir_paths);
    } else #if OS == .PS5 {
        return false;
    } else {
        assert(false);
    }
}

add_single_directory :: (using watcher: *$T/File_Watcher, path: string, recursive := false) -> bool {
    assert(callback != null, "You must call init() on the File_Watcher before add_directories()!");
    #if OS == .WINDOWS {
        return add_directories_windows(watcher, path);
    } else #if OS == .LINUX {
        if recursive then return add_directories_linux(watcher, path);
        else              return add_single_directory_linux(watcher, path);
    } else #if OS == .MACOS {
        return add_directories_macos(watcher, path);
    } else #if OS == .PS5 {
        return false;
    } else {
        assert(false);
    }
}

deinit :: (using watcher: $T/File_Watcher) {
    #if OS == .WINDOWS {
        for directories {
            success := CancelIo(it.handle);
            if !success {
                System :: #import "System";
                error, error_string := System.get_error_value_and_string();
                log_error("Couldn't cancel the async io on %: error % (%)", it.name, error, error_string);
            }
            release(<<it);
            free(it);
        }
        array_free(directories);
    } else #if OS == .LINUX {
        close(inotify_instance);
        free(inotify_data);

        deinit(*watch_paths);
        release(path_pool);
        free(path_pool);
    } else #if OS == .MACOS {
        for event_streams {
            FSEventStreamStop(it);
            FSEventStreamInvalidate(it); // Remove stream from all run loops
            FSEventStreamRelease(it);
        }
        array_free(event_streams);
    } else {
        assert(false);
    }

    release(pool);
    free(pool);
}

// Process changes of any of the watched files.
// If you call this periodically, you can ignore the needs_wait and wait_seconds return values.
// But you can use POSIX poll(…) on the watcher’s inotify_instance to wait until changes are pending.
// In that case, you should check needs_wait. If it’s true you should call this function again after
// wait_seconds have elapsed, even if no further poll changes have happened.
process_changes :: (using watcher: *File_Watcher) -> changed: bool, needs_wait: bool, wait_seconds: float64 {
    assert(callback != null, "You must call init() on the File_Watcher before process_changes()!");
    #if OS == .WINDOWS {
        changed, needs_wait, wait_seconds := process_changes_windows(watcher);
    } else #if OS == .LINUX {
        changed, needs_wait, wait_seconds := process_changes_linux(watcher);
    } else #if OS == .MACOS {
        changed, needs_wait, wait_seconds := process_changes_macos(watcher);
    } else #if OS == .PS5 {
        changed := false;
        needs_wait := false;
        wait_seconds := 0.0;
        assert(!watcher.changes);
    } else {
        changed := false;
        needs_wait := false;
        wait_seconds := 0.0;
        assert(false);
    }
    return changed, needs_wait, wait_seconds;
}

#scope_file

add_change :: (using watcher: *File_Watcher, full_path: string, events: File_Change_Event) {
    push_allocator(pool_allocator_proc, pool);

    now := get_time();

    for * change: changes {
        if change.full_path == full_path {
			if watcher.verbose	 log("Deduplicating changes for %: % + %", full_path, change.events, events);
			change.events |= events;
            change.time_of_last_change = xx now;
            return;
        }
    }

    change: File_Change;
    change.full_path  = copy_string(full_path);
	change.events = events;
    change.time_of_last_change = xx now;

    array_add(*changes, change);

    if watcher.verbose  log("Change for '%' issued at time %.", full_path, now);
}

emit_changes :: (using watcher: *$T/File_Watcher) -> changed: bool, needs_wait: bool, wait_seconds: float64 {
    if !changes.count  return false, false, 0;

    now := get_time();

	notified := false;
	earliest_wait_time: float64 = merge_window_seconds;
    for * change: changes {
        #if OS == .MACOS {
            wait_time : float64 = 0; // The FSEventStream already batches up events for us
        } else {
            delta := now - change.time_of_last_change;
            wait_time := merge_window_seconds - delta;
        }

		// if watcher.verbose  log("Wait time for %: %", <<change, wait_time);
        if wait_time <= 0 {
			if callback  callback(watcher, change, user_data);
			remove change;
			notified = true;
		} else if wait_time < earliest_wait_time {
			earliest_wait_time = wait_time;
		}
    }

    if changes.count == 0 {
        // Nothing to handle, so, we can reset our memory. Note that right now we could in theory grow without bounds if someone keeps throwing
        // changes at us such that there is always something < RELOAD_DELAY. We could fix this
        // by having two pools and swapping between them every once in a while, but it doesn't
        // seem worth it right now as this is meant for friendly production environments.   -jblow, 1 March 2021.
        array_reset(*changes);
        reset(pool);
    }

	return notified, (changes.count > 0), earliest_wait_time;
}

#if OS == .WINDOWS {
    TRUE :: 1;
    FALSE :: 0;

    Directory_Info :: struct {
        name: string;
        bytes_returned: s32;
        overlapped: OVERLAPPED;
        handle: HANDLE;

        notify_information: *void;

        read_issue_failed := false;
    }

    release :: (info: Directory_Info) {
        CloseHandle(info.overlapped.hEvent);
        CloseHandle(info.handle);
        free(info.name);
        free(info.notify_information);
    }

    add_directories_windows :: (using watcher: *File_Watcher, dir_paths: ..string) -> bool {
        for dir_path: dir_paths {
            // Init and allocate. We allocate one buffer of File_Watcher.buffer_size size for each directory,
            // which might become big if there are many many directories. This may be something you'd want to tune.
            event := CreateEventW(null, FALSE, FALSE, null);
            if event == null    return false;

            handle := CreateFileW(utf8_to_wide(dir_path), FILE_LIST_DIRECTORY,
                                  FILE_SHARE_READ|FILE_SHARE_DELETE|FILE_SHARE_WRITE,
                                  null,
                                  OPEN_EXISTING,
                                  FILE_FLAG_BACKUP_SEMANTICS|FILE_FLAG_OVERLAPPED,
                                  null);

            if handle == INVALID_HANDLE_VALUE {
                System :: #import "System";
                error_code, description := System.get_error_value_and_string();
                log_error("os_create_directory_notification encountered an error in CreateFileW: %, %\n", error_code, description);

                CloseHandle(event);
                return false;
            }

            info := New(Directory_Info);
            info.overlapped.hEvent = event;
            info.overlapped.Offset = 0;
            info.read_issue_failed = false;
            info.handle = handle;
            info.name = copy_string(dir_path);  // Allocated on the global heap.
            path_overwrite_separators(info.name, #char "/");
            info.notify_information = alloc(watcher.buffer_size);

            issue_one_read(watcher, info); // Start the first async read right away

            array_add(*directories, info);
        }

        return true;
    }

    issue_one_read :: (using watcher: *File_Watcher, info: *Directory_Info) {
        assert(info.handle != INVALID_HANDLE_VALUE);

        notify_filter: s32;
        if (events_to_watch & (.ADDED | .MOVED | .REMOVED)) {
            notify_filter |= FILE_NOTIFY_CHANGE_FILE_NAME | FILE_NOTIFY_CHANGE_DIR_NAME | FILE_NOTIFY_CHANGE_CREATION;
        }
        if (events_to_watch & .MODIFIED) {
            notify_filter |= FILE_NOTIFY_CHANGE_SIZE | FILE_NOTIFY_CHANGE_LAST_WRITE;
        }
        if (events_to_watch & .ATTRIBUTES_CHANGED) {
            notify_filter |= FILE_NOTIFY_CHANGE_SECURITY | FILE_NOTIFY_CHANGE_ATTRIBUTES;
        }

        info.bytes_returned = 0;

        success := ReadDirectoryChangesW(info.handle, info.notify_information, watcher.buffer_size, cast(s32) watcher.watch_recursively, notify_filter, null, *info.overlapped, null);

        if !success {
            // Probably I need to mark something here and prime it again next frame.
            log_error("ReadDirectoryChangesW failed for directory %: %\n", info.name, GetLastError());
            info.read_issue_failed = true;
        }
    }

    process_changes_windows :: (using watcher: *File_Watcher) -> changed: bool, needs_wait: bool, wait_seconds: float64 {
        for info: directories {
            if info.read_issue_failed {
                info.read_issue_failed = false;
                issue_one_read(watcher, info);
                if info.read_issue_failed   continue;
            }

            handle := info.handle;
            assert(handle != INVALID_HANDLE_VALUE);

            if !HasOverlappedIoCompleted(info.overlapped) continue;

            // Handle the change....
            bytes_transferred: s32;
            success := GetOverlappedResult(handle, *info.overlapped, *bytes_transferred, FALSE);
            if success && verbose  log("%: bytes_transferred == % (struct size %)\n", info.name, bytes_transferred, size_of(FILE_NOTIFY_INFORMATION));

            // Issue the next read once we're done processing this one
            defer issue_one_read(watcher, info);

            if !success {
                break;
            }

            if bytes_transferred == 0 {
                // Buffer has overflowed and we lost all the events. Add event for the whole directory and set SCAN_CHILDREN.
                add_change(watcher, info.name, File_Change_Event.MODIFIED | .SCAN_CHILDREN);
                continue;
            }

            notify := cast(*FILE_NOTIFY_INFORMATION) info.notify_information;  // This is actually a list of events...
            while notify != null {
                defer notify = move_info_forward(notify);

                events: File_Change_Event;
                if notify.Action == {
                    case FILE_ACTION_ADDED;             events = .ADDED;
                    case FILE_ACTION_MODIFIED;          events = .MODIFIED;
                    case FILE_ACTION_RENAMED_OLD_NAME;  events = File_Change_Event.MOVED | .MOVED_FROM;
                    case FILE_ACTION_RENAMED_NEW_NAME;  events = File_Change_Event.MOVED | .MOVED_TO;
                    case FILE_ACTION_REMOVED;           events = .REMOVED;
                    case;
                        if verbose  log("discarded case %\n", notify.Action);
                        // Ignore RENAMED_OLD_NAME file actions.
                        continue;
                }

                name, success := wide_to_utf8(cast(*u16) notify.FileName.data, notify.FileNameLength / 2);
                if !name {
                    if verbose log_error("WideCharToMultiByte returned empty string.\n");
                    continue;
                }

                path_overwrite_separators(name, #char "/");
                full_path := tprint("%/%", info.name, name);

                if watch_recursively && events & .MODIFIED && is_directory(full_path) {
                    // Window's doesn't seem to issue the right events when things are renamed or moved.
                    // Instead it issues a "MODIFIED" event for the parent directory that the change occurred in.

                    // Tell the callback that he has missed events for the children of this directory.
                    events |= .SCAN_CHILDREN;
                }

                add_change(watcher, full_path, events);
            }
        }

        changed, needs_wait, wait_seconds := emit_changes(watcher);
        return changed, needs_wait, wait_seconds;
    }

    move_info_forward :: (info: *FILE_NOTIFY_INFORMATION) -> *FILE_NOTIFY_INFORMATION {
        if info.NextEntryOffset == 0  return null;
        return cast(*FILE_NOTIFY_INFORMATION)((cast(*u8) info) + info.NextEntryOffset);
    }
}

#if OS == .LINUX {
    add_directories_linux :: (using watcher: *$T/File_Watcher, dir_paths: .. string) -> bool {
        for dir_paths {
            if !add_single_directory_linux(watcher, it)     return false;
        }

        if watcher.watch_recursively {
            Data :: struct {
                watcher: *T;
                success: bool;
            }
            data: Data;
            data.watcher = watcher;
            data.success = true;

            for path: dir_paths {
                is_dir, success := is_directory(path);
                if !success {
                    if watcher.verbose log("Couldn’t check if \"%\" is a directory", path);
                    continue;
                }

                if is_dir {
                    success := visit_files(path, true, *data, (info: *File_Visit_Info, data: *Data) {
                        if !add_single_directory_linux(data.watcher, info.full_name) {
                            data.success = false;
                        }
                    }, visit_files = false, visit_directories = true, follow_symlinks = false);

                    if !success || !data.success {
                        log_error("Couldn’t enumerate dirs in \"%\"", path);
                        return false;
                    }
                }
            }
        }

        return true;
    }

    add_single_directory_linux :: (using watcher: *File_Watcher, dir_path: string) -> bool {
        push_allocator(pool_allocator_proc, path_pool);
        c_path := temp_c_string(dir_path);
        flags: u32;
        if (events_to_watch & .ADDED) {
            flags |= IN_CREATE;
        }
        if (events_to_watch & .MODIFIED) {
            flags |= IN_MODIFY | IN_CLOSE_WRITE;
        }
        if (events_to_watch & .MOVED) {
            flags |= IN_MOVED_TO | IN_MOVE_SELF;
        }
        if (events_to_watch & .ATTRIBUTES_CHANGED) {
            flags |= IN_ATTRIB;
        }
        if (events_to_watch & .REMOVED) {
            flags |= IN_DELETE | IN_DELETE_SELF | IN_MOVED_FROM;
        }

        watch := inotify_add_watch(inotify_instance, c_path, flags);
        if watch == -1 {
            log_error("Could not watch path \"%\": %", dir_path, errno());
            return false;
        }
        previous_watch_path := table_find_pointer(*watch_paths, watch);
        if previous_watch_path {
            if watcher.verbose	 log("Watch % for \"%\" already exists", watch, <<previous_watch_path);
            if compare(<<previous_watch_path, dir_path) != 0 {
                if watcher.verbose	 log("Replacing path for watch %: \"%\" -> \"%\"", watch, <<previous_watch_path, dir_path);
                free(<<previous_watch_path);
                <<previous_watch_path = copy_string(dir_path);
            }
        } else {
            if watcher.verbose	 log("Adding watch % for \"%\"", watch, dir_path);
            table_add(*watch_paths, watch, copy_string(dir_path));
        }

        return true;
    }

    process_changes_linux :: (using watcher: *File_Watcher) -> changed: bool, needs_wait: bool, wait_seconds: float64 {
        assert(inotify_instance != -1);

        inotify_bytes_read = read(inotify_instance, inotify_data, cast(u64) watcher.buffer_size);
        if inotify_bytes_read == -1 {
            if errno() != EAGAIN {
                log_error("Could not read inotify events: %", errno());
            }
        } else if inotify_bytes_read >= 0 {
            inotify_cursor = 0;
            notify := cast(*inotify_event) inotify_data;  // This is actually a list of events...
            while notify != null {
                defer notify = move_data_forward(watcher, notify);
                if watcher.verbose	log("Received notify: % (mask: 0x%)", <<notify, formatInt(notify.mask, base = 16));

                c_name := notify.name.data;

                // we cant just do this because notify.name can be null padded arbitrarily
                // and notify.len includes these pads. Thanks Linux... -josh Feb 22, 2017
                // length_in_bytes := notify.len;
                name: string;
                name.data = c_name;
                if notify.len {
                    name.count = c_style_strlen(c_name);
                } else {
                    name.count = 0;
                }

                events: File_Change_Event;
                if notify.mask & IN_CREATE                                     events |= .ADDED;
                if notify.mask & (IN_MODIFY | IN_CLOSE_WRITE)                  events |= .MODIFIED;
                if notify.mask & (IN_MOVED_FROM)                               events |= File_Change_Event.MOVED | .MOVED_FROM;
                if notify.mask & (IN_MOVED_TO | IN_MOVE_SELF)                  events |= File_Change_Event.MOVED | .MOVED_TO;
                if notify.mask & IN_ATTRIB                                     events |= .ATTRIBUTES_CHANGED;
                if notify.mask & (IN_DELETE | IN_DELETE_SELF)                  events |= .REMOVED;

                if !events {
                    if watcher.verbose  log("discarded mask % for \"%\"", notify.mask, name);
                    continue;
                }

                if watcher.verbose  log("Action '%' on name '%':", events, name);

                full_path, success := get_full_name(watcher, notify.wd, name);
                if !success {
                    log_error("Could not assemble full name for \"%\" from event %", name, <<notify);
                    continue;
                }

                was_created_or_moved := events & (File_Change_Event.ADDED | File_Change_Event.MOVED);
                if watch_recursively && was_created_or_moved && is_directory(full_path) {
                    add_directories(watcher, full_path);
                    // Tell the callback that he has missed events for the children of this directory.
                    events |= .SCAN_CHILDREN;
                }

                add_change(watcher, full_path, events);
            }
        }

        changed, needs_wait, wait_seconds := emit_changes(watcher);
        return changed, needs_wait, wait_seconds;
    }

    move_data_forward :: (using watcher: *File_Watcher, event: *inotify_event) -> *inotify_event {
        // Our inotify_event struct is too large because the "name" array has non-zero size.
        INOTIFY_EVENT_OVERSIZE :: 4;
        step: s32 = cast(s32) (size_of(inotify_event) - INOTIFY_EVENT_OVERSIZE + event.len);
        if (inotify_cursor + step) >= inotify_bytes_read return null;
        inotify_cursor += step;
        return cast(*inotify_event) ((cast(*u8) inotify_data) + inotify_cursor);
    }

    get_full_name :: (using watcher: *File_Watcher, watch: s32, name: string) -> string, success: bool  {
        dir_path := table_find_pointer(*watch_paths, watch);
        if !dir_path	return "", false;

        if name	{
            return tprint("%/%", <<dir_path, name), true;
        } else {
            return <<dir_path, true;
        }
    }
}

#if OS == .MACOS {
    #import "macos";

    add_directories_macos :: (using watcher: *File_Watcher, dir_paths: .. string) -> bool {
        paths_to_watch := create_cfstring_array(dir_paths);
        defer CFRelease(paths_to_watch);

        fsinfo: FSEventStreamContext;
        fsinfo.info = watcher;

        event_stream := FSEventStreamCreate(null, event_stream_callback, _context=*fsinfo, paths_to_watch, kFSEventStreamEventIdSinceNow,
                                      latency=watcher.merge_window_seconds, kFSEventStreamCreateFlagFileEvents);

        FSEventStreamScheduleWithRunLoop(event_stream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
        FSEventStreamStart(event_stream);
        array_add(*event_streams, event_stream);

        return true;
    }

    FS_ATTRIBUTE_CHANGES :: kFSEventStreamEventFlagChangeOwner | kFSEventStreamEventFlagItemInodeMetaMod | kFSEventStreamEventFlagItemFinderInfoMod;
    event_stream_callback :: (streamRef: FSEventStreamRef, clientCallBackInfo: *void, numEvents: size_t, eventPaths: *void, eventFlags: *FSEventStreamEventFlags, eventIds: *FSEventStreamEventId) #c_call {
        using watcher := cast(*File_Watcher) clientCallBackInfo;
        ctx: Context; // @ToDo: Pass the outer context to the callback?
        push_context ctx {
            paths := cast(**u8)eventPaths;
            for 0..numEvents-1 {
                flags := eventFlags[it];
                event_id := eventIds[it];
                full_path := to_string(paths[it]);

                if verbose  log("Received event id % with flags 0x%", event_id, formatInt(flags, base=16));

                events: File_Change_Event;
                if flags & kFSEventStreamEventFlagItemCreated     events |= .ADDED;
                if flags & kFSEventStreamEventFlagItemModified    events |= .MODIFIED;
                if flags & kFSEventStreamEventFlagItemRenamed     events |= .MOVED;
                if flags & kFSEventStreamEventFlagItemRemoved     events |= .REMOVED;
                if flags & kFSEventStreamEventFlagMustScanSubDirs events |= .SCAN_CHILDREN;
                if flags & FS_ATTRIBUTE_CHANGES                   events |= .ATTRIBUTES_CHANGED;

                if !events {
                    if verbose  log("Discarding events % for %", flags, full_path);
                    continue;
                }

                if flags & kFSEventStreamEventFlagItemIsDir && events & (File_Change_Event.ADDED | File_Change_Event.MOVED) {
                    // Tell the callback that he has missed events for the children of this directory.
                    events |= .SCAN_CHILDREN;
                }

                add_change(watcher, full_path, events);
            }
        }
    }

    process_changes_macos :: (using watcher: *File_Watcher) -> changed: bool, needs_wait: bool, wait_seconds: float64 {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0, false);
        changed, needs_wait, wait_seconds := emit_changes(watcher);
        return changed, needs_wait, wait_seconds;
    }

    create_cfstring_array :: (strings: [] string) -> CFArrayRef {
        temp := NewArray(strings.count, CFStringRef);
        defer {
            for temp CFRelease(it);
            array_free(temp);
        }

        for strings {
            cfstring := CFStringCreateWithBytes(null, it.data, it.count, .UTF8, false);
            temp[it_index] = cfstring;
        }

        cfarray := CFArrayCreate(null, cast(**void) temp.data, temp.count, *kCFTypeArrayCallBacks);
        return cfarray;
    }
}

#import "Basic";
#import "File_Utilities";
#import "Hash_Table";
#import "Pool";
#import "String";

#if OS == .WINDOWS {
    #import "Windows";
    #import "Windows_Utf8";
}
#if OS == .LINUX {
    #import "Linux";
    #import "POSIX";
}
#if OS == .MACOS {
    #import "macos";
    #import "POSIX";
}
