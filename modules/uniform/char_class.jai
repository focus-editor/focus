#scope_module

ALPHA_MASK :: (1<<26) - 1;

CharClass :: struct {
	upper: u32;  // bitmap of A-Z
	lower: u32;  // bitmap of a-z
	nrunes: int;
	// @ToDo. @Speed: Do we need a faster data structure?
	// TODO: Clean up the builders properly!!
	ranges: [..] RuneRange;
	folds_ascii: bool;
}

uninit :: (using cc: *CharClass) {
	array_free(ranges);
}

copy :: (using cc: *CharClass) -> *CharClass {
	new_cc := New(CharClass);
	memcpy(new_cc, cc, size_of(CharClass));
	new_ranges: [..] RuneRange;
	array_copy(*new_ranges, cc.ranges);
	new_cc.ranges = new_ranges;
	return new_cc;
}

RuneRange :: struct {
	lo: Rune;
	hi: Rune;
}

less :: (a: RuneRange, b: RuneRange) -> bool {
	return a.hi < b.lo;
}

find_range :: (ranges: [] RuneRange, r: RuneRange) -> RuneRange, index: int, found: bool {
	start := 0;
	end := ranges.count - 1;

	while start <= end {
		middle := (end + start) / 2;
		range := ranges[middle];
		if less(range, r) {
			start = middle + 1;
		} else if less(r, range) {
			end = middle - 1;
		} else {
			return range, middle, true;
		}
	}

	return .{}, start, false;
}

make_range :: (lo: Rune, hi: Rune) -> RuneRange {
	r: RuneRange;
	r.lo = lo;
	r.hi = hi;
	return r;
}

add_range :: (using ccb: *CharClass, lo: Rune, hi: Rune) -> bool {
	if hi < lo	 return false;

	if lo <= #char "z" && hi >= #char "A" {
		// Overlaps some alpha, maybe not all.
		// Update bitmaps telling which ASCII letters are in the set.
		lo1 := max(lo, #char "A");
		hi1 := min(hi, #char "Z");
		if lo1 <= hi1 {
			upper |= cast(u32)(((1 << (hi1 - lo1 + 1)) - 1) << (lo1 - #char "A"));
		}

		lo1 = max(lo, #char "a");
		hi1 = min(hi, #char "z");
		if lo1 <= hi1 {
			lower |= cast(u32)(((1 << (hi1 - lo1 + 1)) - 1) << (lo1 - #char "a"));
		}
	}

	{  // Check whether lo, hi is already in the class.
		range, index, found := find_range(ranges, make_range(lo, lo));
		if found && range.lo <= lo && hi <= range.hi	return false;
	}

	// Look for a range abutting lo on the left.
	// If it exists, take it out and increase our range.
	if lo > 0 {
		range, index, found := find_range(ranges, make_range(lo - 1, lo - 1));
		if found {
			lo = range.lo;
			if (range.hi > hi) {
				hi = range.hi;
			}
			nrunes -= range.hi - range.lo + 1;
			array_ordered_remove_by_index(*ranges, index);
		}
	}

	// Look for a range abutting hi on the right.
	// If it exists, take it out and increase our range.
	if (hi < Runemax) {
		range, index, found := find_range(ranges, make_range(hi + 1, hi + 1));
		if found {
			hi = range.hi;
			nrunes -= range.hi - range.lo + 1;
			array_ordered_remove_by_index(*ranges, index);
		}
	}

	// Look for ranges between lo and hi.  Take them out.
	// This is only safe because the set has no overlapping ranges.
	// We've already removed any ranges abutting lo and hi, so
	// any that overlap [lo, hi] must be contained within it.
	new_range := make_range(lo, hi);
	index: int;
	while true {
		range: RuneRange;
		found: bool;
		range, index, found = find_range(ranges, new_range);
		if !found {
			break;
		}
		nrunes -= range.hi - range.lo + 1;
		array_ordered_remove_by_index(*ranges, index);
	}

	// Finally, add [lo, hi].
	nrunes += hi - lo + 1;
	array_insert_at(*ranges, new_range, index);
	return true;
}

add_char_class :: (using ccb: *CharClass, other: CharClass) {
	for other.ranges {
		add_range(ccb, it.lo, it.hi);
	}
}

contains :: (using ccb: *CharClass, r: Rune) -> bool {
	range, index, found := find_range(ccb.ranges, make_range(r, r));
	return found;
}

// Does the character class behave the same on A-Z as on a-z?
folds_ascii :: (using ccb: *CharClass) -> bool {
  return ((upper ^ lower) & ALPHA_MASK) == 0;
}

// copy :: (using ccb: *CharClass) -> *CharClass {
//   CharClass* cc = new CharClass;
//   for (iterator it = begin(); it != end(); ++it)
//     cc->ranges_.insert(RuneRange(it->lo, it->hi));
//   cc->upper_ = upper_;
//   cc->lower_ = lower_;
//   cc->nrunes_ = nrunes_;
//   return cc;
// }


remove_above :: (using ccb: *CharClass, r: Rune) {
	if r >= Runemax	return;

	if r < #char "z" {
		if r < #char "a" {
			lower = 0;
		} else {
			lower &= cast(u32)(ALPHA_MASK >> (#char "z" - r));
		}
	}

	if r < #char "Z" {
		if r < #char "A" {
			upper = 0;
		} else {
			upper &= cast(u32)(ALPHA_MASK >> (#char "Z" - r));
		}
	}

	while true {
		range, index, found := find_range(ranges, make_range(r + 1, Runemax));
		if !found	break;
		nrunes -= range.hi - range.lo + 1;
		if (range.lo <= r) {
			range.hi = r;
			ranges[index] = range;
			nrunes += range.hi - range.lo + 1;
		} else {
			array_ordered_remove_by_index(*ranges, index);
		}
	}
}

negate :: (using ccb: *CharClass) {
	// In negation, first range begins at 0, unless
	// the current class begins at 0.
	dest := 0;
	src := 0;
	nextlo: Rune;
	if ranges.count && ranges[0].lo == 0 {
		nextlo = ranges[0].hi + 1;
		src = 1;
	}
	while src < ranges.count {
		r := ranges[src];
		ranges[dest].lo = nextlo;
		ranges[dest].hi = r.lo - 1;
		nextlo = r.hi + 1;
		src += 1;
		dest += 1;
	}
	if nextlo <= Runemax {
		if dest == ranges.count {
			array_reserve(*ranges, ranges.count + 1);
			ranges.count = dest + 1;
		}
		ranges[dest].lo = nextlo;
		ranges[dest].hi = Runemax;
	} else {
		ranges.count = dest;
	}

	upper = ALPHA_MASK & ~upper;
	lower = ALPHA_MASK & ~lower;
	nrunes = Runemax+1 - nrunes;
}

finish_char_class :: (using ccb: *CharClass) {
	 // Does the character class behave the same on A-Z as on a-z?
	folds_ascii = (((upper ^ lower) & ALPHA_MASK) == 0);
}

#import "Basic";
