
#import "Basic";
#import "File";


main :: () {

    // make a directory to store our files in
     make_directory_if_it_does_not_exist("temp_dir");

    BLOCK_OF_TEXT :: #string DONE
Line 0
   Line 1
Line 2
 Line 3
Line 4
 Line 5
    DONE

    // convinient functions to write/read data to named-files
     write_entire_file("temp_dir/file1.txt", BLOCK_OF_TEXT);
     write_entire_file("temp_dir/file2.txt", BLOCK_OF_TEXT.data, 6);
    {
        builder: String_Builder;
        print_to_builder(*builder, "BLOCK_OF_TEXT length: %\n", BLOCK_OF_TEXT.count);
        write_entire_file("temp_dir/file3.txt", *builder);
    }

    text_in_file2 :=  read_entire_file("temp_dir/file2.txt");
    print("Contents of temp_dir/file2.txt:\n\"%\"\n", text_in_file2);


    // open, read/write, close API, similar to what one would expect from POSIX file functions
    {
        file, success :=  file_open("temp_dir/file1.txt", for_writing=true, keep_existing_content=true);
        if !success {
            print("Could not open file temp_dir/file1.txt for writing.\n");
            return;
        }

        // advance the file pointer to ensure we append to the file instead of overwrite!
        advance :=  file_length(file);
         file_set_position(file, advance);

        // like above, we are able to pass in a string, a pointer and a length, or a String_Builder struct.
        success =  file_write(*file, BLOCK_OF_TEXT);
        if !success {
            print("Could not write to file temp_dir/file1.txt.\n");
            return;
        }

         file_close(*file);

        // open for reading this time
        file, success =  file_open("temp_dir/file1.txt");
        if !success {
            print("Could not open file temp_dir/file1.txt for writing.\n");
            return;
        }

        length :=  file_length(file);
        buffer := cast(*u8) alloc(length);

        success =  file_read(file, buffer, length);
        if !success {
            print("Could not read from temp_dir/file1.txt.\n");
            return;
        }

        data: string;
        data.data = buffer;
        data.count = length;

        print("Contents of temp_dir/file1.txt:\n\"%\"\n", data);
        free(buffer);

         file_close(*file);
    }

    // move, delete, link

     file_move("temp_dir/file1.txt", "temp_dir/file4.txt");
     file_delete("temp_dir/file2.txt");
     file_link("temp_dir/link_file3.txt", "temp_dir/file3.txt");
}

