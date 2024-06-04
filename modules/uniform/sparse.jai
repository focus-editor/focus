#scope_module

Sparse_Set :: struct {
	count: u32;
	sparse: [..] u32;
	dense: [..] u32;
}

init :: (set: *Sparse_Set, size: int) {
	array_resize(*set.sparse, size, false);
	array_resize(*set.dense, size, false);
}

add :: (set: *Sparse_Set, i: int) {
	if !contains(<<set, i) {
        add_unchecked(set, i);
	}
}

add_unchecked :: (using set: *Sparse_Set, i: int) {
  assert(!contains(<<set, i));
  assert(count < dense.count);
  sparse[i] = count;
  dense[count] = cast(u32)i;
  count += 1;
}

contains :: (using set: Sparse_Set, i: int) -> bool {
	assert(i >= 0);
	assert(i < dense.count);
	return sparse[i] < count && dense[sparse[i]] == i;
}

for_expansion :: (set: *Sparse_Set, body: Code, flags: For_Flags) #expand {
	assert(!flags, "reverse/pointer are not yet supported");
	i := 0;
	while i < set.count {
		`it := set.dense[i];
		`it_index := i;
		defer i += 1;
        #insert body;
	}
}


Sparse_Array :: struct(Value: Type) {
	count: u32;
	sparse: [..] u32;
	dense: [..] Index_Value;

	Index_Value :: struct {
		index: u32;
		value: Value;
	}
}

init :: (array: *Sparse_Array, size: int) {
	array_resize(*array.sparse, size, false);
	array_resize(*array.dense, size, false);
}

add_or_set :: (array: *Sparse_Array($T), i: int, value: T) {
	if !contains(array, i) {
        add_unchecked(array, i, value);
	} else {
		set(array, i, value);
	}
}

add_unchecked :: (using array: *Sparse_Array($T), i: int, value: T) {
  assert(!contains(<<array, i));
  assert(count < dense.count);
  sparse[i] = count;
  dense[count].index = cast(u32)i;
  dense[count].value = value;
  count += 1;
}

set :: (using array: *Sparse_Array($T), i: int, value: T) {
	assert(contains(<<array, i));
	dense[sparse[i]].value = value;
}

contains :: (using array: Sparse_Array, i: int) -> bool {
	assert(i >= 0);
	assert(i < dense.count);
	return sparse[i] < count && dense[sparse[i]].index == i;
}

get :: (using array: Sparse_Array($T), i: int) -> T {
	assert(contains(array, i));
	return dense[sparse[i]].value;
}

for_expansion :: (array: *$T/Sparse_Array, body: Code, flags: For_Flags) #expand {
	assert(!flags, "reverse/pointer are not yet supported");
	i := 0;
	while i < array.count {
		`it := array.dense[i];
		`it_index := i;
		defer i += 1;
        #insert body;
	}
}
