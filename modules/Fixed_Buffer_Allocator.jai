Fixed_Buffer_Allocator :: #type,isa Allocator;

Fixed_Buffer :: struct {
    allocated: s64;
    max_size: s64;
}

#assert size_of(Fixed_Buffer) % ALIGNMENT == 0;  // so we don't have to align the memory block pointer

get_fixed_buffer_allocator :: (max_size: s64) -> Fixed_Buffer_Allocator {
    // Add some space for the control structure at the beginning
    total_size := size_of(Fixed_Buffer) + max_size;

    allocator: Fixed_Buffer_Allocator = ---;
    allocator.proc = fixed_buffer_allocator_proc;
    allocator.data = alloc(total_size);

    buffer: *Fixed_Buffer = cast(*Fixed_Buffer) allocator.data;
    buffer.allocated = 0;
    buffer.max_size  = max_size;

    return allocator;
}

fixed_buffer_allocator_proc :: (mode: Allocator_Mode, size: s64, old_size: s64, old_memory: *void, allocator_data: *void) -> *void {
    if #complete mode == {
      case .FREE;   return null;
      case .RESIZE; #through;
      case .ALLOCATE;
        assert(allocator_data != null);

        using buffer := cast(*Fixed_Buffer) allocator_data;
        memory := allocator_data + size_of(Fixed_Buffer);

        if size <= 0 return null;
        new_allocated := align_forward(allocated + size, ALIGNMENT);
        assert(new_allocated < max_size, "Fixed buffer allocator is out of memory");
        result := memory + allocated;
        allocated = new_allocated;  // bump

        if mode == .RESIZE {
            size_to_copy := ifx old_size < size then old_size else size;
            if result && size_to_copy  memcpy(result, old_memory, size_to_copy);
        }

        return result;
    }
}

#scope_module

#import "Basic";

ALIGNMENT :: 8;
