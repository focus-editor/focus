// DO_REPETITION_TESTING :: false;

// #if DO_REPETITION_TESTING {

//     repetition_tester :: () {
//         jai_files: [..] string;

//         visitor :: (info: *File_Visit_Info, files: *[..] string) {
//             full_path := info.full_name;
//             path, basename, extension, name := path_decomp(full_path);
//             if extension != "jai" return;
//             array_add(files, copy_string(full_path));
//         }
//         visit_files("W:/focus_test_debug1.1", recursive = true, *jai_files, visitor, visit_files = true, visit_directories = false);

//         for jai_files {
//             buffer_id := find_or_create_buffer(it);
//             assert(buffer_id >= 0);
//             print("Opened buffer %\n", buffer_id);
//         }

//         min_elapsed := FLOAT64_MAX;
//         max_elapsed : float64 = 0.0;

//         for 0 .. 1 {
//             now := seconds_since_init();

//             for * open_buffers {
//                 if it.lang != .Jai continue;
//                 tokenize_jai(it);
//             }

//             elapsed := seconds_since_init() - now;
//             if elapsed < min_elapsed then min_elapsed = elapsed;
//             if elapsed > max_elapsed then max_elapsed = elapsed;

//             reset_temporary_storage();
//         }

//         print("MIN: %ms\n", min_elapsed * 1000);
//         print("MAX: %ms\n", max_elapsed * 1000);
//     }

// } else {

//     repetition_tester :: () {}

// }

// // Optimized - start (before optimising get_next_token)
// // MIN: 585.7498ms
// // MAX: 587.0272ms


repetition_tester :: () {
    buffer_id := find_or_create_buffer("W:/focus_test_debug1.1/src/editors.jai");
    assert(buffer_id >= 0);
    print("Opened buffer %\n", buffer_id);
    buffer := *open_buffers[buffer_id];

    min_elapsed := FLOAT64_MAX;
    max_elapsed : float64 = 0.0;

    for 0 .. 999 {
        now := seconds_since_init();

        tokenize_jai(buffer);

        elapsed := seconds_since_init() - now;
        if elapsed < min_elapsed then min_elapsed = elapsed;
        if elapsed > max_elapsed then max_elapsed = elapsed;

        reset_temporary_storage();
    }

    print("MIN: %ms\n", min_elapsed * 1000);
    print("MAX: %ms\n", max_elapsed * 1000);
}

// ====== Before changes =======

//  Unoptimized
// MIN: 56.0239ms
// MAX: 57.454ms

// Optimized
// MIN: 10.2867ms
// MAX: 14.3585ms

// ====== After char table =======

// Unoptimized
// MIN: 39.5416ms
// MAX: 43.5766ms

// Optimized
// MIN: 8.9395ms
// MAX: 9.3362ms

// ====== After read_identifier_string =======

// Unoptimised
// MIN: 28.4963ms
// MAX: 38.6615ms

// Optimised
// MIN: 5.3117ms
// MAX: 6.6804ms
