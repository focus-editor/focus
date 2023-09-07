Regexp :: struct {
	prefix: string;
	prefix_foldcase: bool;
	suffix_regexp: *Regexp_Node;
	prog: *Prog;
	num_capture_groups: int;
	pool: Regexp_Pool;
}

uninit :: (re: *Regexp) {
	uninit(*re.pool);
}

compile :: (pattern: string, parse_flags := ParseFlags.LikePerl) -> Regexp, success: bool {
	regexp: Regexp;
	entire_regexp, status, pool := parse(pattern, parse_flags);

	if status.code != .Success {
		log_error("Could not parse regexp \"%\": % (%)", pattern, status.code, status.error_arg);
		return regexp, false;
	}
	regexp.pool = pool;


	#if REGEXP_DEBUG	print("Parsed: \"%\"\n", to_string(entire_regexp));

	regexp.prefix, regexp.prefix_foldcase, regexp.suffix_regexp = required_prefix(entire_regexp, *regexp.pool);
	#if REGEXP_DEBUG	print("Split: \"%\" (foldcase: %) + \"%\"\n", regexp.prefix, regexp.prefix_foldcase, to_string(regexp.suffix_regexp));

	regexp.prog = compile(regexp.suffix_regexp, *regexp.pool);
	if !regexp.prog {
		log_error("Could not compile regexp \"%\"", pattern);
		return regexp, false;
	}
	#if REGEXP_DEBUG	print("Compiled suffix:\n%\n", to_string(<<regexp.prog));

	regexp.num_capture_groups = compute_num_captures(regexp.suffix_regexp);
// 	// @ToDo: For one-pass NFA
// 	// is_one_pass = compute_is_one_pass(prog);

	return regexp, true;
}

#scope_module

// List of pointers to Inst* that need to be filled in (patched).
// Because the Inst* haven't been filled in yet,
// we can use the Inst* word to hold the list's "next" pointer.
// It's kind of sleazy, but it works well in practice.
// See http://swtch.com/~rsc/regexp/regexp1.html for inspiration.
//
// Because the out and out1 fields in Inst are no longer pointers,
// we can't use pointers directly here either.  Instead, head refers
// to inst_[head>>1].out (head&1 == 0) or inst_[head>>1].out1 (head&1 == 1).
// head == 0 represents the null list.  This is okay because instruction #0
// is always the fail instruction, which never appears on a list.
PatchList :: struct {
	head: u32;
	tail: u32;  // for constant-time append
}

// Returns patch list containing just p.
make_patch_list :: (p: int) -> PatchList {
	l: PatchList;
	l.head = cast(u32)p;
	l.tail = cast(u32)p;
	return l;
}

// Patches all the entries on l to have value p.
patch  :: (inst: *[..] Inst, l: PatchList, p: int) {
	head := l.head;
	while head != 0 {
		ip := *(<<inst)[head>>1];
		if head & 1 {
			head = ip.out1;
			ip.out1 = cast(u32)p;
		} else {
			head = get_out(<<ip);
			set_out(ip, p);
		}
	}
}

// Appends two patch lists and returns result.
append :: (inst: *[..] Inst, l1: PatchList, l2: PatchList) -> PatchList {
	if l1.head == 0		return l2;
	if l2.head == 0		return l1;

	ip := *(<<inst)[l1.tail>>1];
	if l1.tail & 1 {
		ip.out1 = l2.head;
	} else {
		set_out(ip, l2.head);
	}

	l: PatchList;
	l.head = l1.head;
	l.tail = l2.tail;
	return l;
}

NULL_PATCH_LIST :: PatchList.{0, 0};

// Compiled program fragment.
Frag :: struct {
	begin: u32;
	end: PatchList;
}

make_frag :: (begin: int, end: PatchList) -> Frag {
	f: Frag;
	f.begin = cast(u32)begin;
	f.end = end;
	return f;
}

// Input encodings.
// Encoding :: enum {
// 	kEncodingUTF8 = 1,  // UTF-8 (0-10FFFF)
// 	kEncodingLatin1,    // Latin-1 (0-FF)
// }


Compiler :: struct {
	pool: *Regexp_Pool;
	prog: *Prog;         // Program being built.
	failed: bool;        // Did we give up compiling?
	// Encoding encoding_;  // Input encoding
	reversed: bool;      // Should program run backward over text?

	inst: [..] Inst;
	max_ninst: int;      // Maximum number of instructions.

	max_mem: s64;    // Total memory budget.

	// std::unordered_map<uint64_t, int> rune_cache_;
	rune_cache: Table(u64, int);
	rune_range: Frag;
	anchor: Anchor;  // anchor mode for RE2::Set
}

// Compiles re, returning program.
// Caller is responsible for deleting prog_.
// If reversed is true, compiles a program that expects
// to run over the input string backward (reverses all concatenations).
// The reversed flag is also recorded in the returned program.
compile :: (re: *Regexp_Node, pool: *Regexp_Pool, reversed := false, max_mem := 0) -> *Prog {

	push_allocator(pool_allocator_proc, pool.pool);
	// Init compiler
	c: Compiler;
	c.pool = pool;

	c.prog = New(Prog);
	c.reversed = reversed;

	array_reserve(*c.inst, 8);

	inst: Inst;
	set_opcode(*inst, .kInstFail);
	array_add(*c.inst, inst);

	c.max_mem = max_mem;
	if max_mem <= 0 {
		c.max_ninst = 100000;  // more than enough
	} else if (max_mem <= size_of(Prog)) {
		// No room for anything.
		c.max_ninst = 0;
	} else {
		m := (max_mem - size_of(Prog)) / size_of(Inst);
		// Limit instruction count so that inst->id() fits nicely in an int.
		// SparseArray also assumes that the indices (inst->id()) are ints.
		// The call to WalkExponential uses 2*max_ninst_ below,
		// and other places in the code use 2 or 3 * prog->size().
		// Limiting to 2^24 should avoid overflow in those places.
		// (The point of allowing more than 32 bits of memory is to
		// have plenty of room for the DFA states, not to use it up
		// on the program.)
		if (m >= 1<<24) {
			m = 1<<24;
		}
		// Inst imposes its own limit (currently bigger than 2^24 but be safe).
		if (m > Inst.MAX_INST) {
			m = Inst.MAX_INST;
		}
		c.max_ninst = m;
	}
	c.anchor = .UNANCHORED;

	// Simplify to remove things like counted repetitions
	// and character classes like \d.
	sre := simplify(re, pool);
	if sre == null		return null;
	#if REGEXP_DEBUG	print("Simplified: \"%\" -> \"%\"\n", to_string(re), to_string(sre));

	// Record whether prog is anchored, removing the anchors.
	// (They get in the way of other optimizations.)
	anchor_start: bool;
	anchor_end: bool;
	sre, anchor_start = is_anchor_start(sre, pool, 0);
	sre, anchor_end = is_anchor_end(sre, pool, 0);

	// Generate fragment for entire regexp.
	w := Walk(*Compiler, Frag).{pre_visit = compiler_pre_visit, post_visit = compiler_post_visit, short_visit = compiler_short_visit, copy = null};
	// @ToDO @Cleanup This is a workaround for nulls not being respected in struct literals yet.
	// Remove once the struct literal bug is fixed in jai
	w.copy = null;
	w.max_visits = 2 * c.max_ninst;
	all := walk(*c, sre, Frag.{}, w);
	if c.failed		return null;

	// Success!  Finish by putting Match node at end, and record start.
	// Turn off c.reversed (if it is set) to force the remaining concatenations
	// to behave normally.
	c.reversed = false;
	all = cat(*c, all, match(*c, 0));

	c.prog.reversed = reversed;
	if (c.prog.reversed) {
		c.prog.anchor_start = anchor_end;
		c.prog.anchor_end = anchor_start;
	} else {
		c.prog.anchor_start = anchor_start;
		c.prog.anchor_end = anchor_end;
	}

	c.prog.start = all.begin;
	if (!c.prog.anchor_start) {
		// Also create unanchored version, which starts with a .*? loop.
		all = cat(*c, dot_star(*c), all);
	}
	c.prog.start_unanchored = all.begin;

	// Hand ownership of prog to caller.
	return finish(*c, re);
}

to_string :: (using comp: Compiler) -> string {
	builder: String_Builder;
	defer free_buffers(*builder);
	for inst {
		print_to_builder(*builder, "%. ", it_index);
		append(*builder, it);
		append(*builder, #char "\n");
	}
	return builder_to_string(*builder);
}

finish :: (using comp: *Compiler, re: *Regexp_Node) -> *Prog {
	if failed		 return null;

	if (prog.start == 0 && prog.start_unanchored == 0) {
		// No possible matches; keep Fail instruction only.
		inst.count = 1;
	}

	// Hand off the array to Prog.
	prog.inst = inst;

	optimize(prog);
	#if REGEXP_DEBUG	print("Optimized:\n%\n", to_string(<<prog));
	flatten(prog);
	#if REGEXP_DEBUG	print("Flattened:\n%\n", to_string(<<prog));
	compute_byte_map(prog);

	if (!prog.reversed) {
		prefix, prefix_foldcase := required_prefix_for_accel(<<re);
		if prefix.count && !prefix_foldcase {
			prog.prefix_size = prefix.count;
			prog.prefix_front = prefix[0];
			prog.prefix_back = prefix[prefix.count - 1];
		}
	}

	// Record remaining memory for DFA.
	// @ToDo
	if (max_mem <= 0) {
		prog.dfa_mem = 1 << 20;
	} else {
		m := max_mem - size_of(Prog);
		m -= prog.inst.count * size_of(Inst);  // account for inst_
		if can_bit_state(prog) {
			m -= prog.inst.count * size_of(u16);  // account for list_heads_
		}
		if (m < 0) {
			m = 0;
		}
		prog.dfa_mem = m;
	}

	p := prog;
	prog = null;
	return p;
}


alloc_inst :: (using comp: *Compiler, n: int) -> int {
	if failed || inst.count + n > max_ninst {
		failed = true;
		return -1;
	}

	array_reserve(*inst, inst.count + n);
	memset(inst.data + inst.count, 0, n * size_of(type_of(inst[0])));
	id := inst.count;
	inst.count += n;
	return id;
}


// These routines are somewhat hard to visualize in text --
// see http://swtch.com/~rsc/regexp/regexp1.html for
// pictures explaining what is going on here.

// Returns an unmatchable fragment.
no_match :: () -> Frag {
	return .{0, NULL_PATCH_LIST};
}

// Is a an unmatchable fragment?
is_no_match :: (a: Frag) -> bool {
	return a.begin == 0;
}

// Given fragments a and b, returns fragment for ab.
cat :: (using comp: *Compiler, a: Frag, b: Frag) -> Frag {
	if is_no_match(a) || is_no_match(b)	return no_match();

	// Elide no-op.
	begin := *inst[a.begin];
	if get_opcode(<<begin) == .kInstNop && a.end.head == (a.begin << 1) && get_out(<<begin) == 0 {
		// in case refs to a somewhere
		patch(*inst, a.end, b.begin);
		return b;
	}

	// To run backward over string, reverse all concatenations.
	if reversed {
		patch(*inst, b.end, a.begin);
		return make_frag(b.begin, a.end);
	}

	patch(*inst, a.end, b.begin);
	return make_frag(a.begin, b.end);
}

// Given fragments for a and b, returns fragment for a|b.
alt :: (using comp: *Compiler, a: Frag, b: Frag) -> Frag {
	// Special case for convenience in loops.
	if is_no_match(a)	return b;
	if is_no_match(b)	return a;

	array_reserve(*inst, inst.count + 1);
	id := alloc_inst(comp, 1);
	if id <	0	return no_match();
	init_alt(*inst[id], a.begin, b.begin);
	return make_frag(id, append(*inst, a.end, b.end));
}

// When capturing submatches in like-Perl mode, a kOpAlt Inst
// treats out_ as the first choice, out1_ as the second.
//
// For *, +, and ?, if out_ causes another repetition,
// then the operator is greedy.  If out1_ is the repetition
// (and out_ moves forward), then the operator is non-greedy.

// Given a fragment a, returns a fragment for a* or a*? (if nongreedy)
star :: (using comp: *Compiler, a: Frag, nongreedy: bool) -> Frag {
	id := alloc_inst(comp, 1);
	if id <	0	return no_match();
	init_alt(*inst[id], 0, 0);
	patch(*inst, a.end, id);
	if nongreedy {
		inst[id].out1 = a.begin;
		return make_frag(id, make_patch_list(id << 1));
	} else {
		set_out(*inst[id], a.begin);
		return make_frag(id, make_patch_list(id << 1 | 1));
	}
}

// Given a fragment for a, returns a fragment for a+ or a+? (if nongreedy)
plus :: (using comp: *Compiler, a: Frag, nongreedy: bool) -> Frag {
	// a+ is just a* with a different entry point.
	f := star(comp, a, nongreedy);
	return make_frag(a.begin, f.end);
}

// Given a fragment for a, returns a fragment for a? or a?? (if nongreedy)
quest :: (using comp: *Compiler, a: Frag, nongreedy: bool) -> Frag {
	if is_no_match(a)	return nop(comp);
	id := alloc_inst(comp, 1);
	if id <	0	return no_match();
	pl: PatchList;
	if nongreedy {
		init_alt(*inst[id], 0, a.begin);
		pl = make_patch_list(id << 1);
	} else {
		init_alt(*inst[id], a.begin, 0);
		pl = make_patch_list((id << 1) | 1);
	}
	return make_frag(id, append(*inst, pl, a.end));
}

dot_star :: (using comp: *Compiler) -> Frag {
	return star(comp, byte_range(comp, 0x00, 0xff, false), true);
}

// Returns a fragment for the byte range lo-hi.
byte_range :: (using comp: *Compiler, lo: u8, hi: u8, foldcase: bool) -> Frag {
	id := alloc_inst(comp, 1);
	if id <	0	return no_match();
	init_byte_range(*inst[id], lo, hi, foldcase, 0);
	return make_frag(id, make_patch_list(id << 1));
}

// Returns a no-op fragment.  Sometimes unavoidable.
nop :: (using comp: *Compiler) -> Frag {
	id := alloc_inst(comp, 1);
	if id <	0	return no_match();
	init_nop(*inst[id]);
	return make_frag(id, make_patch_list(id << 1));
}

// Returns a fragment that signals a match.
match :: (using comp: *Compiler, match_id: int) -> Frag {
	id := alloc_inst(comp, 1);
	if id <	0	return no_match();
	init_match(*inst[id], cast(s32)match_id);
	return make_frag(id, NULL_PATCH_LIST);
}

// Returns a fragment matching a particular empty-width op (like ^ or $)
empty_width :: (using comp: *Compiler, empty: EmptyOp) -> Frag {
	id := alloc_inst(comp, 1);
	if id <	0	return no_match();
	init_empty_width(*inst[id], empty, 0);
	return make_frag(id, make_patch_list(id << 1));
}

// Given a fragment a, returns a fragment with capturing parens around a.
capture :: (using comp: *Compiler, a: Frag, n: s32) -> Frag {
	if is_no_match(a)	return no_match();
	id := alloc_inst(comp, 2);
	if id <	0	return no_match();
	init_capture(*inst[id], 2 * n, a.begin);
	init_capture(*inst[id + 1], 2 * n + 1, 0);
	patch(*inst, a.end, id + 1);
	return make_frag(id, make_patch_list((id + 1) << 1));
}

// A Rune is a name for a Unicode code point.
// Returns maximum rune encoded by UTF-8 sequence of length len.
// ToDo: This should be an array of constants!
max_rune :: (len: int) -> Rune {
	b: int;  // number of Rune bits in len-byte UTF-8 sequence (len < UTFmax)
	if len == 1 {
		b = 7;
	} else {
		b = 8-(len+1) + 6*(len-1);
	}
	return cast(Rune)(1<<b) - 1;   // maximum Rune for b bits.
}

// The rune range compiler caches common suffix fragments,
// which are very common in UTF-8 (e.g., [80-bf]).
// The fragment suffixes are identified by their start
// instructions.  null denotes the eventual end match.
// The Frag accumulates in rune_range_.  Caching common
// suffixes reduces the UTF-8 "." from 32 to 24 instructions,
// and it reduces the corresponding one-pass NFA from 16 nodes to 8.
begin_range :: (using comp: *Compiler) {
	table_reset(*rune_cache);
	rune_range.begin = 0;
	rune_range.end = NULL_PATCH_LIST;
}

uncached_rune_byte_suffix :: (using comp: *Compiler, lo: u8, hi: u8, foldcase: bool, next: int) -> int {
	f := byte_range(comp, lo, hi, foldcase);
	if (next != 0) {
		patch(*inst, f.end, next);
	} else {
		rune_range.end = append(*inst, rune_range.end, f.end);
	}
	return f.begin;
}

make_rune_cache_key :: (lo: u8, hi: u8, foldcase: bool, next: int) -> u64 {
  return (cast(u64)next << 17) |
         (cast(u64)lo   <<  9) |
         (cast(u64)hi   <<  1) |
         (cast(u64)foldcase);
}

cached_rune_byte_suffix :: (using comp: *Compiler, lo: u8, hi: u8, foldcase: bool, next: int) -> int {
	key := make_rune_cache_key(lo, hi, foldcase, next);
	ptr := table_find_pointer(*rune_cache, key);
	if ptr	return <<ptr;
	id := uncached_rune_byte_suffix(comp, lo, hi, foldcase, next);
	table_add(*rune_cache, key, id);
	return id;
}

is_cached_rune_byte_suffix :: (using comp: *Compiler, id: int) -> bool {
	lo := inst[id].lo;
	hi := inst[id].hi;
	foldcase := get_foldcase(inst[id]);
	next := get_out(inst[id]);
	key := make_rune_cache_key(lo, hi, foldcase, next);
	return table_find_pointer(*rune_cache, key) != null;
}

add_suffix :: (using comp: *Compiler, id: int) {
	if failed		return;

	if rune_range.begin == 0 {
		rune_range.begin = cast(u32)id;
		return;
	}

	rune_range.begin = add_suffix_recursive(comp, rune_range.begin, id);
}

add_suffix_recursive :: (using comp: *Compiler, root: u32, id: int) -> u32 {
	assert(get_opcode(inst[root]) == .kInstAlt || get_opcode(inst[root]) == .kInstByteRange);

	f := find_byte_range(comp, root, id);
	if is_no_match(f) {
		alt := alloc_inst(comp, 1);
		if alt < 0	return 0;
		init_alt(*inst[alt], cast(u32)root, cast(u32)id);
		return cast(u32)alt;
	}

	br: u32;
	if f.end.head == 0 {
		br = root;
	} else if (f.end.head&1) {
		br = inst[f.begin].out1;
	} else {
		br = get_out(inst[f.begin]);
	}

	if is_cached_rune_byte_suffix(comp, br) {
		// We can't fiddle with cached suffixes, so make a clone of the head.
		byterange := alloc_inst(comp, 1);
		if byterange < 0	return 0;
		init_byte_range(*inst[byterange], inst[br].lo, inst[br].hi, get_foldcase(inst[br]), get_out(inst[br]));

		// Ensure that the parent points to the clone, not to the original.
		// Note that this could leave the head unreachable except via the cache.
		br = cast(u32)byterange;
		if (f.end.head == 0) {
			root = br;
		} else if (f.end.head&1) {
			inst[f.begin].out1 = cast(u32)br;
		} else {
			set_out(*inst[f.begin], br);
		}
	}

	out := get_out(inst[id]);
	if !is_cached_rune_byte_suffix(comp, id) {
		// The head should be the instruction most recently allocated, so free it
		// instead of leaving it unreachable.
		assert(id == inst.count - 1);
		inst[id].out_opcode = 0;
		inst[id].out1 = 0;
		inst.count -= 1;
	}

	out = add_suffix_recursive(comp, get_out(inst[br]), out);
	if out == 0		return 0;

	set_out(*inst[br], out);
	return root;
}

byte_range_equal :: (using comp: *Compiler, id1: int, id2: int) -> bool {
  return inst[id1].lo == inst[id2].lo &&
         inst[id1].hi == inst[id2].hi &&
         get_foldcase(inst[id1]) == get_foldcase(inst[id2]);
}

find_byte_range :: (using comp: *Compiler, root: int, id: int) -> Frag {
	if get_opcode(inst[root]) == .kInstByteRange {
		if byte_range_equal(comp, root, id) {
			return make_frag(root, NULL_PATCH_LIST);
		} else {
			return no_match();
		}
	}

	while get_opcode(inst[root]) == .kInstAlt {
		out1 := inst[root].out1;
		if byte_range_equal(comp, out1, id) {
			return make_frag(root, make_patch_list((root << 1) | 1));
		}

		// CharClass is a sorted list of ranges, so if out1 of the root Alt wasn't
		// what we're looking for, then we can stop immediately. Unfortunately, we
		// can't short-circuit the search in reverse mode.
		if (!reversed)	 return no_match();

		out := get_out(inst[root]);
		if get_opcode(inst[out]) == .kInstAlt {
			root = out;
		} else if byte_range_equal(comp, out, id) {
			return make_frag(root, make_patch_list(root << 1));
		} else {
			return no_match();
		}
	}

	assert(false, "Should never be reached");
	return no_match();
}

end_range :: (using comp: *Compiler) -> Frag {
	return rune_range;
}

// Converts rune range lo-hi into a fragment that recognizes
// the bytes that would make up those runes in the current
// encoding (always utf-8 for now).
// This lets the machine work byte-by-byte even when
// using multibyte encodings.
add_rune_range :: (using comp: *Compiler, lo: Rune, hi: Rune, foldcase: bool) {
	if (lo > hi)	return;

	// Pick off 80-10FFFF as a common special case.
	if (lo == 0x80 && hi == 0x10ffff) {
		add_80_10ffff(comp);
		return;
	}

	// Split range into same-length sized ranges.
	for i: 1..UTFmax - 1 {
		max := max_rune(i);
		if (lo <= max && max < hi) {
			add_rune_range(comp, lo, max, foldcase);
			add_rune_range(comp, max+1, hi, foldcase);
			return;
		}
	}

	// ASCII range is always a special case.
	if hi < Runeself {
		add_suffix(comp, uncached_rune_byte_suffix(comp, cast(u8)lo, cast(u8)hi, foldcase, 0));
		return;
	}

	// Split range into sections that agree on leading bytes.
	for i: 1..UTFmax - 1 {
		m := cast(s32)(1<<(6*i)) - 1;  // last i bytes of a UTF-8 sequence
		if ((lo & ~m) != (hi & ~m)) {
			if ((lo & m) != 0) {
				add_rune_range(comp, lo, lo|m, foldcase);
				add_rune_range(comp, (lo|m)+1, hi, foldcase);
				return;
			}
			if ((hi & m) != m) {
				add_rune_range(comp, lo, (hi&~m)-1, foldcase);
				add_rune_range(comp, hi&~m, hi, foldcase);
				return;
			}
		}
	}

	// Finally.  Generate byte matching equivalent for lo-hi.
	ulo, n := bytes_from_rune(lo);
	uhi, m := bytes_from_rune(hi);
	assert(n == m);

	// The logic below encodes this thinking:
	//
	// 1. When we have built the whole suffix, we know that it cannot
	// possibly be a suffix of anything longer: in forward mode, nothing
	// else can occur before the leading byte; in reverse mode, nothing
	// else can occur after the last continuation byte or else the leading
	// byte would have to change. Thus, there is no benefit to caching
	// the first byte of the suffix whereas there is a cost involved in
	// cloning it if it begins a common prefix, which is fairly likely.
	//
	// 2. Conversely, the last byte of the suffix cannot possibly be a
	// prefix of anything because next == 0, so we will never want to
	// clone it, but it is fairly likely to be a common suffix. Perhaps
	// more so in reverse mode than in forward mode because the former is
	// "converging" towards lower entropy, but caching is still worthwhile
	// for the latter in cases such as 80-BF.
	//
	// 3. Handling the bytes between the first and the last is less
	// straightforward and, again, the approach depends on whether we are
	// "converging" towards lower entropy: in forward mode, a single byte
	// is unlikely to be part of a common suffix whereas a byte range
	// is more likely so; in reverse mode, a byte range is unlikely to
	// be part of a common suffix whereas a single byte is more likely
	// so. The same benefit versus cost argument applies here.
	id := 0;
	if (reversed) {
		for i: 0..n-1 {
			// In reverse UTF-8 mode: cache the leading byte; don't cache the last
			// continuation byte; cache anything else iff it's a single byte (XX-XX).
			if (i == 0 || (ulo[i] == uhi[i] && i != n-1)) {
				id = cached_rune_byte_suffix(comp, ulo[i], uhi[i], false, id);
			} else {
				id = uncached_rune_byte_suffix(comp, ulo[i], uhi[i], false, id);
			}
		}
	} else {
		for < i: n-1..0 {
			// In forward UTF-8 mode: don't cache the leading byte; cache the last
			// continuation byte; cache anything else iff it's a byte range (XX-YY).
			if (i == n-1 || (ulo[i] < uhi[i] && i != 0)) {
				id = cached_rune_byte_suffix(comp, ulo[i], uhi[i], false, id);
			} else {
				id = uncached_rune_byte_suffix(comp, ulo[i], uhi[i], false, id);
			}
		}
	}
	add_suffix(comp, id);
}

add_80_10ffff :: (using comp: *Compiler) {
  // The 80-10FFFF (Runeself-Runemax) rune range occurs frequently enough
  // (for example, for /./ and /[^a-z]/) that it is worth simplifying: by
  // permitting overlong encodings in E0 and F0 sequences and code points
  // over 10FFFF in F4 sequences, the size of the bytecode and the number
  // of equivalence classes are reduced significantly.
  id: int;
  if reversed {
    // Prefix factoring matters, but we don't have to handle it here
    // because the rune range trie logic takes care of that already.
    id = uncached_rune_byte_suffix(comp, 0xC2, 0xDF, false, 0);
    id = uncached_rune_byte_suffix(comp, 0x80, 0xBF, false, id);
    add_suffix(comp, id);

    id = uncached_rune_byte_suffix(comp, 0xE0, 0xEF, false, 0);
    id = uncached_rune_byte_suffix(comp, 0x80, 0xBF, false, id);
    id = uncached_rune_byte_suffix(comp, 0x80, 0xBF, false, id);
    add_suffix(comp, id);

    id = uncached_rune_byte_suffix(comp, 0xF0, 0xF4, false, 0);
    id = uncached_rune_byte_suffix(comp, 0x80, 0xBF, false, id);
    id = uncached_rune_byte_suffix(comp, 0x80, 0xBF, false, id);
    id = uncached_rune_byte_suffix(comp, 0x80, 0xBF, false, id);
    add_suffix(comp, id);
  } else {
    // Suffix factoring matters - and we do have to handle it here.
	cont1 := uncached_rune_byte_suffix(comp, 0x80, 0xBF, false, 0);
    id = uncached_rune_byte_suffix(comp, 0xC2, 0xDF, false, cont1);
    add_suffix(comp, id);

    cont2 := uncached_rune_byte_suffix(comp, 0x80, 0xBF, false, cont1);
    id = uncached_rune_byte_suffix(comp, 0xE0, 0xEF, false, cont2);
    add_suffix(comp, id);

    cont3 := uncached_rune_byte_suffix(comp, 0x80, 0xBF, false, cont2);
    id = uncached_rune_byte_suffix(comp, 0xF0, 0xF4, false, cont3);
    add_suffix(comp, id);
  }
}


compiler_short_visit :: (using comp: *Compiler, re: *Regexp_Node, f: Frag) -> Frag {
	failed = true;
	return no_match();
}

compiler_pre_visit :: (using comp: *Compiler, re: *Regexp_Node, f: Frag) -> Frag, stop: bool {
	return .{}, failed;
}

literal :: (using comp: *Compiler, r: Rune, foldcase: bool) -> Frag {
	if (r < Runeself) { // Make common case fast.
		return byte_range(comp, cast(u8)r, cast(u8)r, foldcase);
	}

	buf, n := bytes_from_rune(r);
	f := byte_range(comp, buf[0], buf[0], false);
	for i: 1..n-1 {
		f = cat(comp, f, byte_range(comp, buf[i], buf[i], false));
	}
	return f;
}

// Called after traversing the node's children during the walk.
// Given their frags, build and return the frag for this re.
// @ToDo @Cleanup: Compiler never uses any input args. Use something more specific than "walk"
compiler_post_visit :: (using comp: *Compiler, re: *Regexp_Node, parent_arg: Frag, pre_arg: Frag, child_frags: [..] Frag) -> Frag {
	// If a child failed, don't bother going forward, especially
	// since the child_frags might contain Frags with NULLs in them.
	if failed	return no_match();

	// Given the child fragments, return the fragment for this node.
	if re.op == {
		case;
			assert(false, "Unexpected op: %", re.op);
			return no_match();

		case .NoMatch;
			return no_match();

		case .EmptyMatch;
			return nop(comp);

		case .HaveMatch;
			f := match(comp, re.match_id);
			if anchor == .ANCHOR_BOTH {
				// Append \z or else the subexpression will effectively be unanchored.
				// Complemented by the Unanchored case in CompileSet().
				f = cat(comp, empty_width(comp, .kEmptyEndText), f);
			}
			return f;

		case .Concat;
			f := child_frags[0];
			for i: 1..child_frags.count - 1 {
				f = cat(comp, f, child_frags[i]);
			}
			return f;

		case .Alternate;
			f := child_frags[0];
			for i: 1..child_frags.count - 1 {
				f = alt(comp, f, child_frags[i]);
			}
			return f;

		case .Star;
			return star(comp, child_frags[0], (re.parse_flags & .NonGreedy) != 0);

		case .Plus;
			return plus(comp, child_frags[0], (re.parse_flags & .NonGreedy) != 0);

		case .Quest;
			return quest(comp, child_frags[0], (re.parse_flags & .NonGreedy) != 0);

		case .Literal;
			return literal(comp, re.rune, (re.parse_flags & .FoldCase) != 0);

		case .LiteralString;
			// Concatenation of literals.
			if re.runes.count == 0	return nop(comp);

			f: Frag;
			for re.runes {
				f1 := literal(comp, it, (re.parse_flags & .FoldCase) != 0);
				if (it_index == 0) {
					f = f1;
				} else {
					f = cat(comp, f, f1);
				}
			}
			return f;

		case .AnyChar;
			begin_range(comp);
			add_rune_range(comp, 0, Runemax, false);
			return end_range(comp);

		case .AnyByte;
			return byte_range(comp, 0x00, 0xFF, false);

		case .CharClass;
			assert(re.char_class.ranges.count > 0, "No ranges in char class");

			// ASCII case-folding optimization: if the char class
			// behaves the same on A-Z as it does on a-z,
			// discard any ranges wholly contained in A-Z
			// and mark the other ranges as foldascii.
			// This reduces the size of a program for
			// (?i)abc from 3 insts per letter to 1 per letter.
			foldascii := re.char_class.folds_ascii;

			// Character class is just a big OR of the different
			// character ranges in the class.
			begin_range(comp);
			for re.char_class.ranges {
				// ASCII case-folding optimization (see above).
				if foldascii && #char "A" <= it.lo && it.hi <= #char "Z"	continue;

				// If this range contains all of A-Za-z or none of it,
				// the fold flag is unnecessary; don't bother.
				fold := foldascii;
				if it.lo <= #char "A" && #char "z" <= it.hi || it.hi < #char "A" || #char "z" < it.lo || #char "Z" < it.lo && it.hi < #char "a" {
					fold = false;
				}

				add_rune_range(comp, it.lo, it.hi, fold);
			}
			return end_range(comp);

		case .Capture;
			// If this is a non-capturing parenthesis -- (?:foo) --
			// just use the inner expression.
			if re.cap < 0 {
				return child_frags[0];
			} else {
				return capture(comp, child_frags[0], re.cap);
			}

		case .BeginLine;
			return empty_width(comp, ifx reversed then EmptyOp.kEmptyEndLine else EmptyOp.kEmptyBeginLine);

		case .EndLine;
			return empty_width(comp, ifx reversed then EmptyOp.kEmptyBeginLine else EmptyOp.kEmptyEndLine);

		case .BeginText;
			return empty_width(comp, ifx reversed then EmptyOp.kEmptyEndText else EmptyOp.kEmptyBeginText);

		case .EndText;
			return empty_width(comp, ifx reversed then EmptyOp.kEmptyBeginText else EmptyOp.kEmptyEndText);

		case .WordBoundary;
			return empty_width(comp, .kEmptyWordBoundary);

		case .NoWordBoundary;
			return empty_width(comp, .kEmptyNonWordBoundary);
	}
}

// Is this regexp required to start at the beginning of the text?
// Only approximate; can return false for complicated regexps like (\Aa|\Ab),
// but handles (\A(a|b)).  Could use the Walker to write a more exact one.
is_anchor_start :: (re: *Regexp_Node, pool: *Regexp_Pool, depth: int) -> *Regexp_Node, bool {
	// The depth limit makes sure that we don't overflow
	// the stack on a deeply nested regexp.  As the comment
	// above says, IsAnchorStart is conservative, so returning
	// a false negative is okay.  The exact limit is somewhat arbitrary.
	if re == null || depth >= 4		return re, false;

	if re.op == {
		case .Concat;
			if re.subs.count > 0 {
				sub, sub_start := is_anchor_start(re.subs[0], pool, depth + 1);
				if sub_start {
					return new_concat(pool, re.subs, re.parse_flags), true;
				}
			}
		case .Capture;
			sub, sub_start := is_anchor_start(re.subs[0], pool, depth + 1);
			if sub_start {
				return new_capture(pool, sub, re.parse_flags, re.cap), true;
			}
		case .BeginText;
			return new_literal_string(pool, .[], re.parse_flags), true;
	}
	return re, false;
}

// Is this regexp required to start at the end of the text?
// Only approximate; can return false for complicated regexps like (a\z|b\z),
// but handles ((a|b)\z).  Could use the Walker to write a more exact one.
is_anchor_end :: (re: *Regexp_Node, pool: *Regexp_Pool, depth: int) -> *Regexp_Node, bool {
	// The depth limit makes sure that we don't overflow
	// the stack on a deeply nested regexp.  As the comment
	// above says, IsAnchorEnd is conservative, so returning
	// a false negative is okay.  The exact limit is somewhat arbitrary.
	if (re == null || depth >= 4)		 return re, false;

	if re.op == {
		case .Concat;
			if re.subs.count > 0 {
				sub, sub_end := is_anchor_end(re.subs[re.subs.count - 1], pool, depth + 1);
				if sub_end {
					return new_concat(pool, re.subs, re.parse_flags), true;
				}
			}
		case .Capture;
			sub, sub_end := is_anchor_end(re.subs[0], pool, depth + 1);
			if sub_end {
				return new_capture(pool, sub, re.parse_flags, re.cap), true;
			}

		case .EndText;
			return new_literal_string(pool, .[], re.parse_flags), true;
	}

	return re, false;
}

#scope_file

#import "Hash_Table";
