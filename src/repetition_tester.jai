DO_REPETITION_TESTING :: false;

#if DO_REPETITION_TESTING {

    repetition_tester :: () {
        min_elapsed := FLOAT64_MAX;
        max_elapsed : float64 = 0.0;

        init_known_binary_extension_table();

        extensions := string.[
            "exe", "pdb", "ttf", "otf", "eot", "woff", "dll", "lib", "dylib", "so", "a", "o", "pdf", "jpg", "png", "gif", "jpeg", "ico", "tif", "tiff", "tga",
            "bmp", "bdlend1", "odbj", "fdbx", "ddae", "3dds", "ddat", "mdsh2", "mdpg", "webp", "mp3", "wav", "ogg", "wma", "blend", "blend1", "obj", "fbx", "dae", "gdif", "3ds", "dat",
            "msh2", "mpg", "mpeg", "psd", "codex", "webm", "tdtf", "zip", "rar", "7z", "bin", "sys", "iso", "nib", "exp", "pyc",
            "rpyc", "DS_Store", "dmg", "edxe", "pddb", "odtf", "edot", "wdoff", "ddll", "ldib", "ddylib", "sdo", "ad", "od", "pddf",
            "jdpg", "pdng", "jdpeg", "idco", "tdif", "tdiff", "tdga", "bdmp", "wdebp", "mdp3", "wdav", "odgg", "wdma", "bdlend",
            "mdpeg", "pdsd", "cdodex", "wdebm", "zdip", "rdar", "7dz", "bdin", "sdys", "idso", "ndib", "edxp", "pdyc", "rdpyc", "DdS_Store", "ddmg",
        ];

        limit := 9999;
        // #if DEBUG { limit = 99; }

        for 0 .. limit {
            now := seconds_since_init();

            for extensions {
                // MIN: 0.0056ms
                // MAX: 0.0251ms
                // is_known_binary_file_extension_table(it);

                // MIN: 0.0292ms
                // MAX: 0.0722ms
                // is_known_binary_file_extension_if(it);
            }

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

