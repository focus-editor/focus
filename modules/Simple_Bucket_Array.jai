// A simple bucket array which doesn't support replacing deleted items,
// but uses a single index as a locator and supports ranges.

// Right now it doesn't even support deleting items, but even if it does in the future
// it's expected that you won't be deleting items from this array often.

// NOTE: this is an array with a FIXED SIZE LIMIT - to avoid having to deal with
// the reallocations of the array of bucket pointers when writing multithreaded code.

Simple_Bucket_Array :: struct (type: Type, items_per_bucket: int, max_buckets: int) {
    Bucket :: Bucket_Type(type, items_per_bucket);
    
    allocator: Allocator;
    
    buckets: [max_buckets] *Bucket;
    last_bucket_index := -1;
    
    count: s64;
}

Bucket_Type :: struct (type: Type, items_per_bucket: int) {
    data: [items_per_bucket] type = ---;
    // the data about occupied slots would go here if we need it
}

bucket_array_add :: (using array: *Simple_Bucket_Array) -> ptr: *array.type, index: s64 {
    if last_bucket_index < 0 {
        allocator = context.allocator;
    }
    
    next_index_in_bucket := count % items_per_bucket;
    if next_index_in_bucket == 0 {
        last_bucket_index += 1;
        buckets[last_bucket_index] = New(Bucket, allocator = allocator);
    }
    
    index := count;
    ptr := *buckets[last_bucket_index].data[next_index_in_bucket];    
    count += 1;
    
    return ptr, index;
}

bucket_array_add :: (using array: *Simple_Bucket_Array, item: array.type) {
    item_ptr := bucket_array_add(array);
    << item_ptr = item;
}

for_expansion :: (array: *$T/Simple_Bucket_Array, body: Code, flags: For_Flags) #expand {
    #assert(!(flags & .REVERSE)); // We don't handle the reverse flag.
    DO_POINTER :: cast(bool)(flags & .POINTER);
    
    `it_index := -1;
    
    for bucket : array.buckets {
        for *=DO_POINTER  `it : bucket.data {
            it_index += 1;

            #insert (break=break bucket, remove=#assert(false)) body;
        }
    }
}

operator *[] :: (using array: *Simple_Bucket_Array, index: int) -> *array.type {
    assert(0 <= index && index < count, "Simple_Bucket_Array index outside of range");
    
    bucket_index := index / items_per_bucket;
    item_index   := index % items_per_bucket;

    bucket := buckets[bucket_index];  // this operation is sadly not atomic
    
    return *bucket.data[item_index];
}


#import "Basic";
