#import "File_Async";
#import "Basic";
#import "Bit_Operations";

main :: () {
    queue := initialize_queue(u64);
    defer destroy_queue(queue);

    read_entire_file(queue, "example.jai", 0);

    val0, proc_data := wait_for_completion(queue);
    assert(val0 == 0, "Was: %\n", val0);

    write_entire_file(queue, "new.jai", proc_data, 2);

    val1 := wait_for_completion(queue);
    assert(val1 == 2, "Was: %\n", val1);

    read_entire_file(queue, "new.jai", 3);
    read_entire_file(queue, "example.jai", 4);

    some, new_data := wait_for_completion(queue);
    some2, old_data := wait_for_completion(queue);

    if some == 3 && some2 == 4 print("3 first\n");
    else if some == 4 && some2 == 3 print("4 first\n");
    else assert(false, "some and some2 are wrong: % %\n", some, some2);

    assert(new_data.count == old_data.count, "%, %\n", new_data.count, old_data.count);
    assert(my_bits_equal(new_data.data, old_data.data, new_data.count));
    //print("%\n\n%\n", cast(string)new_data, cast(string)old_data);

    proc := open_file(queue, "example.jai");
    defer close_file(queue, proc);

    other := open_file(queue, "new.jai");
    defer close_file(queue, other);

    f6: [6] u8;
    f6n := cast([] u8)"noport";
    read_file(queue, proc, 1, f6, 10);
    write_file(queue, other, 1, f6n, 11);

    wait_for_completion(queue);
    wait_for_completion(queue);

    assert(cast(string)f6 == "import", "%", cast(string)f6);

    read_file(queue, other, 1, f6, 12);

    wait_for_completion(queue);
    assert(cast(string)f6 == "noport");
}

my_bits_equal :: inline (a: *void, b: *void, length_in_bytes: s64) -> bool {
    return !memcmp(a, b, length_in_bytes);
}
