DO_REPETITION_TESTING :: false;

#if DO_REPETITION_TESTING {

    repetition_tester :: () {
        // buffer_id := find_or_create_buffer("W:/expenses/libs/sqlite3.c");
        buffer_id := find_or_create_buffer("W:/focus_test_debug1.1/src/editors.jai");
        assert(buffer_id >= 0);
        print("Opened buffer %\n", buffer_id);
        buffer := *open_buffers[buffer_id];

        min_elapsed := FLOAT64_MAX;
        max_elapsed : float64 = 0.0;

        limit := 99;
        #if DEBUG { limit = 9; }

        for 0 .. limit {
            now := seconds_since_init();

            // tokenize_cpp(buffer);
            tokenize_jai(buffer);

            elapsed := seconds_since_init() - now;
            if elapsed < min_elapsed then min_elapsed = elapsed;
            if elapsed > max_elapsed then max_elapsed = elapsed;

            reset_temporary_storage();
        }

        print("MIN: %ms\n", min_elapsed * 1000);
        print("MAX: %ms\n", max_elapsed * 1000);
    }

} else {

    repetition_tester :: () {}

}
