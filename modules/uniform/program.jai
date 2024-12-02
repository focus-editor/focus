#scope_module

// Opcodes for Inst
InstOp :: enum u32 {
	kInstAlt :: 0;      // choose between out_ and out1_
	kInstAltMatch;     // Alt: out_ is [00-FF] and back, out1_ is match; or vice versa.
	kInstByteRange;    // next (possible case-folded) byte must be in [lo_, hi_]
	kInstCapture;      // capturing parenthesis number cap_
	kInstEmptyWidth;   // empty-width special (^ $ ...); bit(s) set in empty_
	kInstMatch;        // found a match!
	kInstNop;          // no-op; occasionally unavoidable
	kInstFail;         // never match; occasionally unavoidable
}

// Bit flags for empty-width specials
EmptyOp :: enum_flags {
	kEmptyBeginLine        :: 1<<0;      // ^ - beginning of line
	kEmptyEndLine          :: 1<<1;      // $ - end of line
	kEmptyBeginText        :: 1<<2;      // \A - beginning of text
	kEmptyEndText          :: 1<<3;      // \z - end of text
	kEmptyWordBoundary     :: 1<<4;      // \b - word boundary
	kEmptyNonWordBoundary  :: 1<<5;      // \B - not \b
	kEmptyAllFlags         :: (1<<6)-1;
}

// Single instruction in regexp program.
Inst :: struct  {
	//     // Getters
	//     int id(Prog* p) { return static_cast<int>(this - p->inst_.data()); }
	//     int out1()      { DCHECK(opcode() == kInstAlt || opcode() == kInstAltMatch); return out1_; }
	//     int cap()       { DCHECK_EQ(opcode(), kInstCapture); return cap_; }
	//     int lo()        { DCHECK_EQ(opcode(), kInstByteRange); return lo_; }
	//     int hi()        { DCHECK_EQ(opcode(), kInstByteRange); return hi_; }
	//     int foldcase()  { DCHECK_EQ(opcode(), kInstByteRange); return hint_foldcase_&1; }
	//     int hint()      { DCHECK_EQ(opcode(), kInstByteRange); return hint_foldcase_>>1; }
	//     int match_id()  { DCHECK_EQ(opcode(), kInstMatch); return match_id_; }
	//     EmptyOp empty() { DCHECK_EQ(opcode(), kInstEmptyWidth); return empty_; }

	// Maximum instruction id.
	// (Must fit in out_opcode_. PatchList/last steal another bit.)
	MAX_INST :: (1<<28) - 1;

	out_opcode: u32;  // 28 bits: out, 1 bit: last, 3 (low) bits: opcode
	union {                // additional instruction arguments:
		out1: u32;      // opcode == kInstAlt
						//   alternate next instruction
		cap: s32;       // opcode == kInstCapture
						//   Index of capture register (holds text
						//   position recorded by capturing parentheses).
						//   For \n (the submatch for the nth parentheses),
						//   the left parenthesis captures into register 2*n
						//   and the right one captures into register 2*n+1.

		match_id: s32;  // opcode == kInstMatch
						//   Match ID to identify this match (for re2::Set).

		struct {        // opcode == kInstByteRange
			lo: u8;			//   byte range is lo_-hi_ inclusive
			hi: u8;       //
			hint_foldcase: u16;  // 15 bits: hint, 1 (low) bit: foldcase
							//   hint to execution engines: the delta to the
							//   next instruction (in the current list) worth
							//   exploring iff this instruction matched; 0
							//   means there are no remaining possibilities,
							//   which is most likely for character classes.
							//   foldcase: A-Z -> a-z before checking range.
		}

		empty: EmptyOp;       // opcode == kInstEmptyWidth
							//   empty_ is bitwise OR of kEmpty* flags above.
	};
}

get_opcode :: (using inst: Inst) -> InstOp {
	return cast(InstOp) (out_opcode & 7);
}

get_last :: (using inst: Inst) -> bool {
	return cast(bool)((out_opcode >> 3) & 1);
}

get_out :: (using inst: Inst) -> u32 {
	return out_opcode >> 4;
}

set_opcode :: (using inst: *Inst, opcode: InstOp) {
	out_opcode = out_opcode & 0xFFFF_FFF8 | cast(u32)opcode;
}

set_last :: (using inst: *Inst) {
	out_opcode = out_opcode & 0xFFFF_FFF7 | cast(u32)(1 << 3);
}

set_out :: (using inst: *Inst, out: int) {
	out_opcode = out_opcode & 0x0F | cast(u32)(out << 4);
}

set_out_opcode :: (using inst: *Inst, out: int, opcode: InstOp) {
	out_opcode = out_opcode & 0x08 | cast(u32)(out << 4) | cast(u32)opcode;
}


get_foldcase :: (using inst: Inst) -> bool {
	assert(get_opcode(inst) == .kInstByteRange);
	return cast(bool) (hint_foldcase & 1);
}

get_hint :: (using inst: Inst) -> int {
	assert(get_opcode(inst) == .kInstByteRange);
	return hint_foldcase >> 1;
}

greedy :: (using inst: Inst, p: *Prog) -> bool {
	assert(get_opcode(inst) == .kInstAltMatch);
	out_inst := p.inst[get_out(inst)];
	return get_opcode(out_inst) == .kInstByteRange ||
		(get_opcode(out_inst) == .kInstNop && get_opcode(p.inst[get_out(out_inst)]) == .kInstByteRange);
}

// Does this inst (an kInstByteRange) match c?
// @ToDo: should this int be Rune?
matches :: (using inst: Inst, c: int) -> bool {
	assert(get_opcode(inst) == .kInstByteRange);
	if (get_foldcase(inst) && #char "A" <= c && c <= #char "Z") {
		c += #char "a" - #char "A";
	}
	return lo <= c && c <= hi;
}


// Returns whether byte c is a word character: ASCII only.
// Used by the implementation of \b and \B.
// This is not right for Unicode, but:
//   - it's hard to get right in a byte-at-a-time matching world
//     (the DFA has only one-byte lookahead).
//   - even if the lookahead were possible, the Progs would be huge.
// This crude approximation is the same one PCRE uses.
is_word_char :: (c: u8) -> bool {
	return (#char "A" <= c && c <= #char "Z") ||
		(#char "a" <= c && c <= #char "z") ||
		(#char "0" <= c && c <= #char "9") ||
		c == #char "_";
}

// Compiled form of regexp program.
Prog :: struct {
	// Whether to anchor the search.
	Anchor :: enum {
		UNANCHORED;  // match anywhere
		ANCHORED;    // match only starting at beginning of text
	}

	// Kind of match to look for (for anchor != kFullMatch)
	//
	// kLongestMatch mode finds the overall longest
	// match but still makes its submatch choices the way
	// Perl would, not in the way prescribed by POSIX.
	// The POSIX rules are much more expensive to implement,
	// and no one has needed them.
	//
	// kFullMatch is not strictly necessary -- we could use
	// kLongestMatch and then check the length of the match -- but
	// the matching code can run faster if it knows to consider only
	// full matches.
	MatchKind :: enum {
		kFirstMatch;     // like Perl, PCRE
		kLongestMatch;   // like egrep or POSIX
		kFullMatch;      // match only entire text; implies anchor==ANCHORED
		kManyMatch;      // for SearchDFA, records set of matches
	};

	anchor_start: bool;       // regexp has explicit start anchor
	anchor_end: bool;         // regexp has explicit end anchor
	reversed: bool;           // whether program runs backward over input
	did_flatten: bool;        // has Flatten been called?
	did_onepass: bool;        // has IsOnePass been called?

	start: int;               // entry point for program
	start_unanchored: int;    // unanchored entry point for program
	bytemap_range: int;       // bytemap_[x] < bytemap_range_
	prefix_size: int;		// size of prefix (0 if no prefix)
	prefix_front: s16 = -1;        // first byte of prefix (-1 if no prefix)
	prefix_back: s16 = -1;         // last byte of prefix (-1 if no prefix)

	list_count: int;                 // count of lists (see above)
	inst_count: [#run enum_highest_value(InstOp) + 1] int;       // count of instructions by opcode
	list_heads: [..] u16;  // sparse array enumerating list heads
	// not populated if size_ is overly large

	inst: [..] Inst;              // pointer to instruction array
	onepass_nodes: [..] u8;  // data for OnePass nodes

	dfa_mem: s64;         // Maximum memory for DFAs.
	// dfa_first: *DFA;          // DFA cached for kFirstMatch/kManyMatch
	// dfa_longest: *DFA;        // DFA cached for kLongestMatch/kFullMatch

	bytemap: [256] u8;    // map from input bytes to byte classes

	// std::once_flag dfa_first_once_;
	// std::once_flag dfa_longest_once_;
}

  // Inst *inst(int id) { return &inst_[id]; }
  // int start() { return start_; }
  // void set_start(int start) { start_ = start; }
  // int start_unanchored() { return start_unanchored_; }
  // void set_start_unanchored(int start) { start_unanchored_ = start; }
  // int size() { return size_; }
  // bool reversed() { return reversed_; }
  // void set_reversed(bool reversed) { reversed_ = reversed; }
  // int list_count() { return list_count_; }
  // int inst_count(InstOp op) { return inst_count_[op]; }
  // uint16_t* list_heads() { return list_heads_.data(); }
  // int64_t dfa_mem() { return dfa_mem_; }
  // void set_dfa_mem(int64_t dfa_mem) { dfa_mem_ = dfa_mem; }
  // bool anchor_start() { return anchor_start_; }
  // void set_anchor_start(bool b) { anchor_start_ = b; }
  // bool anchor_end() { return anchor_end_; }
  // void set_anchor_end(bool b) { anchor_end_ = b; }
  // int bytemap_range() { return bytemap_range_; }
  // const uint8_t* bytemap() { return bytemap_; }
  // bool can_prefix_accel() { return prefix_size_ != 0; }

  // // Accelerates to the first likely occurrence of the prefix.
  // // Returns a pointer to the first byte or NULL if not found.
  // const void* PrefixAccel(const void* data, size_t size) {
  //   DCHECK_GE(prefix_size_, 1);
  //   return prefix_size_ == 1 ? memchr(data, prefix_front_, size)
  //                            : PrefixAccel_FrontAndBack(data, size);
  // }



can_bit_state :: (using prog: *Prog) -> bool {
	return list_heads.count > 0;
}

init_alt :: (inst: *Inst, out: u32, out1: u32) {
	assert(inst.out_opcode == 0);
	set_out_opcode(inst, out, .kInstAlt);
	inst.out1 = out1;
}

init_byte_range :: (inst: *Inst, lo: u8, hi: u8, foldcase: bool, out: int) {
	assert(inst.out_opcode == 0);
	set_out_opcode(inst, out, .kInstByteRange);
	inst.lo = lo;
	inst.hi = hi;
	inst.hint_foldcase = (cast(u16)foldcase)&1;
}

init_capture :: (inst: *Inst, cap: s32, out: u32) {
	assert(inst.out_opcode == 0);
	set_out_opcode(inst, out, .kInstCapture);
	inst.cap = cap;
}

init_empty_width :: (inst: *Inst, empty: EmptyOp, out: u32) {
	assert(inst.out_opcode == 0);
	set_out_opcode(inst, out, .kInstEmptyWidth);
	inst.empty = empty;
}

init_match :: (inst: *Inst, id: s32) {
	assert(inst.out_opcode == 0);
	set_opcode(inst, .kInstMatch);
	inst.match_id = id;
}

init_nop :: (inst: *Inst) {
	assert(inst.out_opcode == 0);
	set_opcode(inst, .kInstNop);
}

init_fail :: (inst: *Inst) {
	assert(inst.out_opcode == 0);
	set_opcode(inst, .kInstFail);
}

// Peep-hole optimizer.
optimize :: (using prog: *Prog) {
	q: Sparse_Set;
	init(*q, inst.count);

	// Eliminate nops.  Most are taken out during compilation
	// but a few are hard to avoid.
	q.count = 0;
	add_if_nonzero(*q, start);
	for id: q {
		ip := *inst[id];
		j := get_out(<<ip);
		// ToDo: Why is this a pointer????
		jp: *Inst;
		while true {
			if j == 0	break;
			jp = *inst[j];
			if get_opcode(<<jp) != .kInstNop	break;
			j = get_out(<<jp);
		}
		set_out(ip, j);
		add_if_nonzero(*q, j);
		if get_opcode(<<ip) == .kInstAlt {
			j = ip.out1;
			while true {
				if j == 0	break;
				jp = *inst[j];
				if get_opcode(<<jp) != .kInstNop	break;
				j = get_out(<<jp);
			}
			ip.out1 = j;
			add_if_nonzero(*q, j);
		}
	}

	// Insert kInstAltMatch instructions
	// Look for
	//   ip: Alt -> j | k
	//	  j: ByteRange [00-FF] -> ip
	//    k: Match
	// or the reverse (the above is the greedy one).
	// Rewrite Alt to AltMatch.
	q.count = 0;
	add_if_nonzero(*q, start);
	for id: q {
		ip := *inst[id];
		add_if_nonzero(*q, get_out(<<ip));
		if get_opcode(<<ip) == .kInstAlt {
			add_if_nonzero(*q, ip.out1);

			// ToDo: Why are these pointers????
			j := inst[get_out(<<ip)];
			k := inst[ip.out1];
			if get_opcode(j) == .kInstByteRange && get_out(j) == id && j.lo == 0x00 && j.hi == 0xFF && is_match(prog, k) {
				set_opcode(ip, .kInstAltMatch);
				continue;
			}
			if is_match(prog, j) && get_opcode(k) == .kInstByteRange && get_out(k) == id && k.lo == 0x00 && k.hi == 0xFF {
				set_opcode(ip, .kInstAltMatch);
			}
		}
	}
}

add_if_nonzero :: (set: *Sparse_Set, i: int) {
	if i != 0 {
		add(set, i);
	}
}

// Is ip a guaranteed match at end of text, perhaps after some capturing?
is_match :: (prog: *Prog, i_in: Inst) -> bool {
	i := i_in;
	while true {
		if #complete get_opcode(i) == {
			case .kInstAlt; #through;
			case .kInstAltMatch; #through;
			case .kInstByteRange; #through;
			case .kInstFail; #through;
			case .kInstEmptyWidth;
				return false;

			case .kInstCapture; #through;
			case .kInstNop;
				i = prog.inst[get_out(i)];

			case .kInstMatch;
				return true;
		}
	}
	// Should not be needed
	assert(false);
	return false;
}

empty_flags :: (text: string, pos: int) -> EmptyOp {
	flags: EmptyOp;

	// ^ and \A
	if pos == 0 {
		flags |= EmptyOp.kEmptyBeginText | .kEmptyBeginLine;
	} else if text[pos - 1] == #char "\n" {
		flags |= .kEmptyBeginLine;
	}

	// $ and \z
	if pos == text.count {
		flags |= EmptyOp.kEmptyEndText | .kEmptyEndLine;
	} else if text[pos] == #char "\n" { // @ToDo: I removed a pos < count check here. Can pos ever be greater than count??
		flags |= .kEmptyEndLine;
	}

	// \b and \B
	if pos == 0 && text.count == 0 {
		// no word boundary here
	} else if pos == 0 {
		if is_word_char(text[pos]) {
			flags |= .kEmptyWordBoundary;
		}
	} else if pos == text.count {
		if is_word_char(text[pos-1]) {
			flags |= .kEmptyWordBoundary;
		}
	} else {
		if (is_word_char(text[pos-1]) != is_word_char(text[pos])) {
			flags |= .kEmptyWordBoundary;
		}
	}
	if !(flags & .kEmptyWordBoundary) {
		flags |= .kEmptyNonWordBoundary;
	}

	return flags;
}

compute_byte_map :: (using prog: *Prog) {
	// Fill in bytemap with byte classes for the program.
	// Ranges of bytes that are treated indistinguishably
	// will be mapped to a single byte class.
	builder: ByteMapBuilder;
	init(*builder);

	// Don't repeat the work for ^ and $.
	marked_line_boundaries := false;
	// Don't repeat the work for \b and \B.
	marked_word_boundaries := false;

	for id: 0..inst.count - 1 {
		ip := *inst[id];
		if get_opcode(<<ip) == .kInstByteRange {
            lo: s32 = ip.lo;
            hi: s32 = ip.hi;
			mark(*builder, lo, hi);
			if get_foldcase(<<ip) && lo <= #char "z" && hi >= #char "a" {
				foldlo := lo;
				foldhi := hi;
				if foldlo < #char "a" {
					foldlo = #char "a";
				}
				if foldhi > #char "z" {
					foldhi = #char "z";
				}
				if (foldlo <= foldhi) {
					foldlo += #char "A" - #char "a";
					foldhi += #char "A" - #char "a";
					mark(*builder, foldlo, foldhi);
				}
			}
			// If this Inst is not the last Inst in its list AND the next Inst is
			// also a ByteRange AND the Insts have the same out, defer the merge.
			if !get_last(<<ip) && get_opcode(inst[id + 1]) == .kInstByteRange && get_out(<<ip) == get_out(inst[id+1]) {
				continue;
			}
			merge(*builder);
		} else if get_opcode(<<ip) == .kInstEmptyWidth {
			if ip.empty & (EmptyOp.kEmptyBeginLine|.kEmptyEndLine) && !marked_line_boundaries {
				mark(*builder, #char "\n", #char "\n");
				merge(*builder);
				marked_line_boundaries = true;
			}
			if ip.empty & (EmptyOp.kEmptyWordBoundary|.kEmptyNonWordBoundary) && !marked_word_boundaries {
				// We require two batches here: the first for ranges that are word
				// characters, the second for ranges that are not word characters.
				for isword: bool.[true, false] {
					i := 0;
					j: int;
					while i < 256 {
						j = i + 1;
						while j < 256 && is_word_char(cast(u8)i) == is_word_char(cast(u8)j) {
							j += 1;
						}
						if is_word_char(cast(u8)i) == isword {
							mark(*builder, cast(u8)i, cast(u8)(j - 1));
						}
						i = j;
					}
					merge(*builder);
				}
				marked_word_boundaries = true;
			}
		}
	}

	bytemap, bytemap_range = build(*builder);
}

// ByteMapBuilder implements a coloring algorithm.
//
// The first phase is a series of "mark and merge" batches: we mark one or more
// [lo-hi] ranges, then merge them into our internal state. Batching is not for
// performance; rather, it means that the ranges are treated indistinguishably.
//
// Internally, the ranges are represented using a bitmap that stores the splits
// and a vector that stores the colors; both of them are indexed by the ranges'
// last bytes. Thus, in order to merge a [lo-hi] range, we split at lo-1 and at
// hi (if not already split), then recolor each range in between. The color map
// (i.e. from the old color to the new color) is maintained for the lifetime of
// the batch and so underpins this somewhat obscure approach to set operations.
//
// The second phase builds the bytemap from our internal state: we recolor each
// range, then store the new color (which is now the byte class) in each of the
// corresponding array elements. Finally, we output the number of byte classes.
ByteMapBuilder :: struct {
	splits: Bit_Array;
	colors: [256] int;
	nextcolor: int;
	colormap: [..] Color_Pair;
	ranges: [..] Range;

	Range :: struct {
		lo: u8;
		hi: u8;
	}
	Color_Pair :: struct {
		a: int;
		b: int;
	}
}

// Initial state: the [0-255] range has color 256.
// This will avoid problems during the second phase,
// in which we assign byte classes numbered from 0.
init :: (using b: *ByteMapBuilder) {
	init_bit_array(*splits, 256);
	set_bit(*splits, 255);
	colors[255] = 256;
	nextcolor = 257;
}

mark :: (using builder: *ByteMapBuilder, lo: s32, hi: s32) {
	assert(lo <= hi);

	// Ignore any [0-255] ranges. They cause us to recolor every range, which
	// has no effect on the eventual result and is therefore a waste of time.
	if lo == 0 && hi == 255		return;

	r: Range;
	r.lo = cast(u8) lo;
	r.hi = cast(u8) hi;
	array_add(*ranges, r);
}

find_next_set_bit :: (using set: Bit_Array, start: int) -> s16 {
	i := start >> 6;
	// Mask out everything below start
	word := slots[i] & (0xFFFF_FFFF_FFFF_FFFF << (start & 63));
	if word {
		return cast(u8)((i << 6) + bit_scan_forward(word) - 1);
	}

	i += 1;
	while i < slots.count {
		if slots[i]	{
			return cast(u8)((i << 6) + bit_scan_forward(slots[i]) - 1);
		}
		i += 1;
	}
	return -1;
}

merge :: (using builder: *ByteMapBuilder) {
	for r: ranges {
		lo := (cast(s16)r.lo) - 1;
		hi: s16 = r.hi;

		if lo >= 0 && !splits[lo] {
			set_bit(*splits, lo);
			next := find_next_set_bit(splits, lo + 1);
			colors[lo] = colors[next];
		}

		if !splits[hi] {
			set_bit(*splits, hi);
			next := find_next_set_bit(splits, hi + 1);
			colors[hi] = colors[next];
		}

		c := lo + 1;
		while c < 256 {
			next := find_next_set_bit(splits, c);
			colors[next] = recolor(builder, colors[next]);
			if next == hi	break;

			c = next + 1;
		}
	}
	colormap.count = 0;
	ranges.count = 0;
}

build :: (using builder: *ByteMapBuilder) -> [256] u8, bytemap_range: int {
	// Assign byte classes numbered from 0.
	nextcolor = 0;

	bytemap: [256] u8;
	c := 0;
	while c < 256 {
		next := find_next_set_bit(splits, c);
		b := cast(u8) recolor(builder, colors[next]);
		while c <= next {
			bytemap[c] = b;
			c += 1;
		}
	}

	return bytemap, nextcolor;
}

recolor :: (using builder: *ByteMapBuilder, oldcolor: int) -> int {
	// Yes, this is a linear search. There can be at most 256
	// colors and there will typically be far fewer than that.
	// Also, we need to consider keys *and* values in order to
	// avoid recoloring a given range more than once per batch.
	for colormap {
		if it.a == oldcolor || it.b == oldcolor	return it.b;
	}

	newcolor := nextcolor;
	nextcolor += 1;
	p: Color_Pair;
	p.a = oldcolor;
	p.b = newcolor;
	array_add(*colormap, p);
	return newcolor;
}


// Prog::Flatten() implements a graph rewriting algorithm.
//
// The overall process is similar to epsilon removal, but retains some epsilon
// transitions: those from Capture and EmptyWidth instructions; and those from
// nullable subexpressions. (The latter avoids quadratic blowup in transitions
// in the worst case.) It might be best thought of as Alt instruction elision.
//
// In conceptual terms, it divides the Prog into "trees" of instructions, then
// traverses the "trees" in order to produce "lists" of instructions. A "tree"
// is one or more instructions that grow from one "root" instruction to one or
// more "leaf" instructions; if a "tree" has exactly one instruction, then the
// "root" is also the "leaf". In most cases, a "root" is the successor of some
// "leaf" (i.e. the "leaf" instruction's out() returns the "root" instruction)
// and is considered a "successor root". A "leaf" can be a ByteRange, Capture,
// EmptyWidth or Match instruction. However, this is insufficient for handling
// nested nullable subexpressions correctly, so in some cases, a "root" is the
// dominator of the instructions reachable from some "successor root" (i.e. it
// has an unreachable predecessor) and is considered a "dominator root". Since
// only Alt instructions can be "dominator roots" (other instructions would be
// "leaves"), only Alt instructions are required to be marked as predecessors.
//
// Dividing the Prog into "trees" comprises two passes: marking the "successor
// roots" and the predecessors; and marking the "dominator roots". Sorting the
// "successor roots" by their bytecode offsets enables iteration in order from
// greatest to least during the second pass; by working backwards in this case
// and flooding the graph no further than "leaves" and already marked "roots",
// it becomes possible to mark "dominator roots" without doing excessive work.
//
// Traversing the "trees" is just iterating over the "roots" in order of their
// marking and flooding the graph no further than "leaves" and "roots". When a
// "leaf" is reached, the instruction is copied with its successor remapped to
// its "root" number. When a "root" is reached, a Nop instruction is generated
// with its successor remapped similarly. As each "list" is produced, its last
// instruction is marked as such. After all of the "lists" have been produced,
// a pass over their instructions remaps their successors to bytecode offsets.
flatten :: (using prog: *Prog) {
	if did_flatten {
		return;
	}
	did_flatten = true;

	// Scratch structures. It's important that these are reused by functions
	// that we call in loops because they would thrash the heap otherwise.
	reachable: Sparse_Set;
	stk: [..] int;
	init(*reachable, inst.count);
	array_reserve(*stk, inst.count);

	// First pass: Marks "successor roots" and predecessors.
	// Builds the mapping from inst-ids to root-ids.
	rootmap, predmap, preds_list := mark_successors(prog, *reachable, *stk);

	// Second pass: Marks "dominator roots".
	sorted := array_copy(rootmap.dense);
	sorted.count = rootmap.count;
	intro_sort(sorted, (a: $T, b: T) -> int {
		if a.index < b.index {
			return -1;
		} else {
			return 1;
		}
	});

	for < sorted {
		if it.index != start_unanchored && it.index != start {
			mark_dominator(prog, it.index, *rootmap, predmap, preds_list, *reachable, *stk);
		}
	}

	// Third pass: Emits "lists". Remaps outs to root-ids.
	// Builds the mapping from root-ids to flat-ids.
	flatmap: [..] int;
	flat: [..] Inst;
	array_resize(*flatmap, rootmap.count, false);
	array_reserve(*flat, inst.count);

	for rootmap {
		flatmap[it.value] = flat.count;
		emit_list(prog, it.index, *rootmap, *flat, *reachable, *stk);
		set_last(*flat[flat.count - 1]);
		// We have the bounds of the "list", so this is the
		// most convenient point at which to compute hints.
		compute_hints(prog, *flat, flatmap[it.value], flat.count);
	}

	list_count = flatmap.count;
	memset(inst_count.data, 0, inst_count.count * size_of(type_of(inst_count[0])));
	// Fourth pass: Remaps outs to flat-ids.
	// Counts instructions by opcode.
	for * flat {
		if (get_opcode(<<it) != .kInstAltMatch) { // handled in EmitList()
			set_out(it, flatmap[get_out(<<it)]);
		}
		inst_count[get_opcode(<<it)] += 1;
	}

	total := 0;
	for inst_count {
		total += it;
	}
	assert(total == flat.count);

	// Remap start_unanchored and start.
	if start_unanchored == 0 {
		assert(start == 0);
	} else if (start_unanchored == start) {
		start_unanchored = flatmap[1];
		start = flatmap[1];
	} else {
		start_unanchored = flatmap[1];
		start = flatmap[2];
	}

	// Finally, replace the old instructions with the new instructions.
	inst = flat;

	// Populate the list heads for BitState.
	// 512 instructions limits the memory footprint to 1KiB.
	if inst.count <= 512 {
		array_resize(*list_heads, inst.count, false);
		// 0xFF makes it more obvious if we try to look up a non-head.
		memset(list_heads.data, 0xFF, inst.count * size_of(type_of(list_heads[0])));
		for 0..list_count - 1 {
			list_heads[flatmap[it]] = cast(u16)it;
		}
	}
}

mark_successors :: (using prog: *Prog, reachable: *Sparse_Set, stk: *[..] int) -> rootmap: Sparse_Array(int), predmap: Sparse_Array(int), preds_list: [..] [..] int {
	get_or_add_preds :: (preds_list: *[..] [..] int, predmap: *Sparse_Array(int), id: int) -> *[..] int {
		preds: * [..] int;
		if !contains(<<predmap, id) {
			add_unchecked(predmap, id, preds_list.count);
			array_reserve(preds_list, preds_list.count + 1);
			memset(preds_list.data + preds_list.count, 0, size_of(type_of(preds_list[0])));
			preds_list.count += 1;
			preds = *(<<preds_list)[preds_list.count - 1];
			preds.data = null;
			preds.count = 0;
		} else {
			preds = *(<<preds_list)[get(<<predmap, id)];
		}
		return preds;
	}

	rootmap: Sparse_Array(int);
	predmap: Sparse_Array(int);
	init(*rootmap, inst.count);
	init(*predmap, inst.count);
	preds_list: [..] [..] int;

	// Mark the kInstFail instruction.
	add_unchecked(*rootmap, 0, rootmap.count);

	// Mark the start_unanchored and start instructions.
	if !contains(rootmap, start_unanchored) {
		add_unchecked(*rootmap, start_unanchored, rootmap.count);
	}
	if !contains(rootmap, start) {
		add_unchecked(*rootmap, start, rootmap.count);
	}

	reachable.count = 0;
	stk.count = 0;
	array_add(stk, start_unanchored);
	while stk.count {
		id := pop(stk);
		if contains(<<reachable, id)	 continue;
		add_unchecked(reachable, id);

		i := inst[id];
		if get_opcode(i) == {
			case .kInstAltMatch; #through;
			case .kInstAlt;
				// Mark this instruction as a predecessor of each out.
				preds := get_or_add_preds(*preds_list, *predmap, get_out(i));
				array_add(preds, id);
				preds = get_or_add_preds(*preds_list, *predmap, i.out1);
				array_add(preds, id);
				array_add(stk, i.out1);
				array_add(stk, get_out(i));

			case .kInstByteRange; #through;
			case .kInstCapture; #through;
			case .kInstEmptyWidth;
				// Mark the out of this instruction as a "root".
				if !contains(rootmap, get_out(i)) {
					add_unchecked(*rootmap, get_out(i), rootmap.count);
				}
				array_add(stk, get_out(i));

			case .kInstNop;
				array_add(stk, get_out(i));

			case .kInstMatch; #through;
			case .kInstFail;

			case;
				assert(false, "Unhandled opcode: %", get_opcode(i));
		}
	}

	return rootmap, predmap, preds_list;
}

mark_dominator :: (using prog: *Prog, root: int, rootmap: *Sparse_Array(int), predmap: Sparse_Array(int), preds_list: [..] [..] int, reachable: *Sparse_Set, stk: *[..] int) {
	reachable.count = 0;
	stk.count = 0;
	array_add(stk, root);

	while stk.count {
		id := pop(stk);
		if contains(<<reachable, id) continue;
		add_unchecked(reachable, id);

		if id != root && contains(<<rootmap, id) {
			// We reached another "tree" via epsilon transition.
			continue;
		}

		i := inst[id];
		if #complete get_opcode(i) == {
			case .kInstAltMatch; #through;
			case .kInstAlt;
				array_add(stk, i.out1);
				array_add(stk, get_out(i));

			case .kInstByteRange; #through;
			case .kInstCapture; #through;
			case .kInstEmptyWidth;

			case .kInstNop;
				array_add(stk, get_out(i));

			case .kInstMatch; #through;
			case .kInstFail;
		}
	}

	for id: reachable {
		if contains(predmap, id) {
			for pred: preds_list[get(predmap, id)] {
				if !contains(<<reachable, pred) {
					// id has a predecessor that cannot be reached from root!
					// Therefore, id must be a "root" too - mark it as such.
					if !contains(<<rootmap, id) {
						add_unchecked(rootmap, id, rootmap.count);
					}
				}
			}
		}
	}
}

emit_list :: (using prog: *Prog, root: int, rootmap: *Sparse_Array(int), flat: *[..] Inst, reachable: *Sparse_Set, stk: *[..] int) {
	reachable.count = 0;
	stk.count = 0;
	array_add(stk, root);
	while stk.count {
		id := pop(stk);
		if contains(<<reachable, id) continue;
		add_unchecked(reachable, id);

		if id != root && contains(<<rootmap, id) {
			// We reached another "tree" via epsilon transition. Emit a kInstNop
			// instruction so that the Prog does not become quadratically larger.
			i: Inst;
			set_opcode(*i, .kInstNop);
			set_out(*i, get(<<rootmap, id));
			array_add(flat, i);
			continue;
		}

		i := inst[id];
		if get_opcode(i) == {
			case .kInstAltMatch;
				newi: Inst;
				set_opcode(*newi, .kInstAltMatch);
				set_out(*newi, flat.count + 1);
				newi.out1 = cast(u32)flat.count + 2;
				array_add(flat, newi);
				array_add(stk, i.out1);
				array_add(stk, get_out(i));

			case .kInstAlt;
				array_add(stk, i.out1);
				array_add(stk, get_out(i));

			case .kInstByteRange; #through;
			case .kInstCapture; #through;
			case .kInstEmptyWidth;
				newi := i;
				set_out(*newi, get(<<rootmap, get_out(i)));
				array_add(flat, newi);

			case .kInstNop;
				array_add(stk, get_out(i));

			case .kInstMatch; #through;
			case .kInstFail;
				array_add(flat, i);

			case;
				assert(false, "Unhandled opcode: %", get_opcode(i));
		}
	}
}

// For each ByteRange instruction in [begin, end), computes a hint to execution
// engines: the delta to the next instruction (in flat) worth exploring iff the
// current instruction matched.
//
// Implements a coloring algorithm related to ByteMapBuilder, but in this case,
// colors are instructions and recoloring ranges precisely identifies conflicts
// between instructions. Iterating backwards over [begin, end) is guaranteed to
// identify the nearest conflict (if any) with only linear complexity.
compute_hints :: (using prog: *Prog, flat: *[..] Inst, begin: int, end: int) {
	recolor :: (splits: *Bit_Array, colors: *[256] int, lo_in: int, hi: int, first: *int, id: int) {
		// Like ByteMapBuilder, we split at lo-1 and at hi.
		lo := lo_in - 1;

		if lo >= 0 && !(<<splits)[lo] {
			set_bit(splits, lo);
			next := find_next_set_bit(<<splits, lo + 1);
			(<<colors)[lo] = (<<colors)[next];
		}
		if !(<<splits)[hi] {
			set_bit(splits, hi);
			next := find_next_set_bit(<<splits, hi + 1);
			(<<colors)[hi] = (<<colors)[next];
		}

		c := lo + 1;
		while c < 256 {
			next := find_next_set_bit(<<splits, c);
			// Ratchet backwards...
			(<<first) = min(<<first, (<<colors)[next]);
			// Recolor with id - because it's the new nearest conflict!
			(<<colors)[next] = id;
			if next == hi	break;
			c = next+1;
		}
	}

	splits: Bit_Array;
	init_bit_array(*splits, 256);
	colors: [256] int;

	dirty := false;
	for #v2 < id: begin..end {
		if (id == end || get_opcode((<<flat)[id]) != .kInstByteRange) {
			if (dirty) {
				dirty = false;
				clear_all_bits(*splits);
			}
			set_bit(*splits, 255);
			colors[255] = id;
			// At this point, the [0-255] range is colored with id.
			// Thus, hints cannot point beyond id; and if id == end,
			// hints that would have pointed to id will be 0 instead.
			continue;
		}
		dirty = true;

		// We recolor the [lo-hi] range with id. Note that first ratchets backwards
		// from end to the nearest conflict (if any) during recoloring.
		first := end;

		ip := *(<<flat)[id];
		lo: s32 = ip.lo;
		hi: s32 = ip.hi;
		recolor(*splits, *colors, lo, hi, *first, id);
		if get_foldcase(<<ip) && lo <= #char "z" && hi >= #char "a" {
			foldlo := lo;
			foldhi := hi;
			if (foldlo < #char "a") {
				foldlo = #char "a";
			}
			if (foldhi > #char "z") {
				foldhi = #char "z";
			}
			if (foldlo <= foldhi) {
				foldlo += #char "A" - #char "a";
				foldhi += #char "A" - #char "a";
				recolor(*splits, *colors, foldlo, foldhi, *first, id);
			}
		}

		if first != end {
			hint := cast(u16) min(first - id, 32767);
			ip.hint_foldcase |= hint << 1;
		}
	}
}

// Accelerates to the first likely occurrence of the prefix.
// Returns position of the first byte or -1 if not found.
prefix_accel :: (using prog: *Prog, text: string, pos: int) -> int {
	assert(prefix_size >= 1);
	if prefix_size == 1 {
		result, found := index_of_char_2(text, cast(u8)prefix_front, pos);
		if !found	return -1;

		return result;
	} else {
		return prefix_accel_front_and_back(prog, text, pos);
	}
}

prefix_accel_front_and_back :: (using prog: *Prog, text: string, pos: int) -> int {
	assert(prefix_size >= 2);
	if text.count - pos < prefix_size {
		return -1;
	}

	// Don't bother searching the last prefix_size_-1 bytes for prefix_front_.
	// This also means that probing for prefix_back_ doesn't go out of bounds.
	size := text.count - prefix_size + 1;

	// @ToDo Port AVX2 fast path once jai has intrinsics/assembler

	for i: pos..size-1 {
		if text[i] == prefix_front && text[i + prefix_size - 1] == prefix_back {
			return i;
		}
	}

	return -1;
}

append :: (builder: *String_Builder, inst: Inst) {
	if get_opcode(inst) == {
		case;
			print_to_builder(builder, "opcode %", get_opcode(inst));

		case .kInstAlt;
			print_to_builder(builder, "alt -> % | %", get_out(inst), inst.out1);

		case .kInstAltMatch;
			print_to_builder(builder, "altmatch -> % | %", get_out(inst), inst.out1);

		case .kInstByteRange;
			append(builder, "byte");
			if get_foldcase(inst) {
				append(builder, "/i");
			}
			print_to_builder(builder, " [%-%] % -> %", format_byte(inst.lo), format_byte(inst.hi), get_hint(inst), get_out(inst));

		case .kInstCapture;
			print_to_builder(builder, "capture % -> %", inst.cap, get_out(inst));

		case .kInstEmptyWidth;
			print_to_builder(builder, "emptywidth % -> %", inst.empty, get_out(inst));

		case .kInstMatch;
			print_to_builder(builder, "match! %", inst.match_id);

		case .kInstNop;
			print_to_builder(builder, "nop -> %", get_out(inst));

		case .kInstFail;
			append(builder, "fail");
	}
}

format_byte :: #bake_arguments formatInt(base = 16, minimum_digits = 2);

to_string :: (using prog: Prog) -> string {
	if did_flatten {
		return to_string_flattened(prog);
	} else {
		return to_string_unflattened(prog);
	}
}

to_string_flattened :: (using prog: Prog) -> string {
	builder: String_Builder;
	defer free_buffers(*builder);
	for inst {
		if get_last(it) {
			print_to_builder(*builder, "%. ", it_index);
		} else {
			print_to_builder(*builder, "%1+ ", it_index);
		}
		append(*builder, it);
		append(*builder, #char "\n");
	}
	return builder_to_string(*builder);
}

to_string_unflattened :: (using prog: Prog) -> string {
	builder: String_Builder;
	defer free_buffers(*builder);

	q: Sparse_Set;
	init(*q, prog.inst.count);
	add_if_nonzero(*q, start);
	for q {
		i := inst[it];
		print_to_builder(*builder, "%. ", it);
		append(*builder, i);
		append(*builder, #char "\n");
		add_if_nonzero(*q, get_out(i));
		if get_opcode(i) == .kInstAlt || get_opcode(i) == .kInstAltMatch {
			add_if_nonzero(*q, i.out1);
		}
	}
	return builder_to_string(*builder);
}

#scope_file

#import "Bit_Array";
#import "IntroSort";
#import "Bit_Operations";

// @ToDo: Use assembler replacement for memchr instead, once jai supports it
index_of_char_2 :: (str: string, char: u8, start := 0) -> int, found:bool {
    for start..str.count-1 {
        if str[it] == char return it, true;
    }
    return -1, false;
}
