#import "File_Async";
#import "Basic";
#import "Bit_Operations";

main :: () {
    queue := initialize_queue(u64);
    defer destroy_queue(queue);

    large := open_file(queue, "very_large_file.dat", false);
    large2 := open_file(queue, "very_large_file2.dat", false);

    tiny_bit_of_data := u8.[1, 2, 3, 4, 5, 6, 7, 8];
    write_file(queue, large, 1 << 33, tiny_bit_of_data, 11);
    tiny_bit_of_data2 := u8.[2, 3, 4, 5, 6, 7, 8, 9];
    write_file(queue, large2, 1 << 33, tiny_bit_of_data2, 22);

    close_file(queue, large);
    close_file(queue, large2);

    print("Proving that this is async!\n");

    val0, submitted_data := wait_for_completion(queue);
    print("Done writing!\n");
    val02, submitted_data2 := wait_for_completion(queue);
    assert((val0 == 11 && val02 == 22) || (val0 == 22 && val02 == 11), "Was: % %\n", val0, val02);
    print("Done writing2!\n");


    read_entire_file(queue, "very_large_file.dat", 15);
    read_entire_file(queue, "very_large_file2.dat", 30);

    print("Proving that this is async!\n");

    val1, recieved_data := wait_for_completion(queue);
    print("Done reading!\n");
    val12, recieved_data2 := wait_for_completion(queue);
    assert((val1 == 15 && val12 == 30) || (val1 == 30 && val12 == 15), "Was: % %\n", val0, val02);
    print("Done reading2!\n");

    assert((recieved_data[(1 << 33) + 6] == 7 && recieved_data2[(1 << 33) + 6] == 8) ||
           (recieved_data[(1 << 33) + 6] == 8 && recieved_data2[(1 << 33) + 6] == 7),
           "Was: % %\n", recieved_data[(1 << 33) + 6], recieved_data2[(1 << 33) + 6]);
}
