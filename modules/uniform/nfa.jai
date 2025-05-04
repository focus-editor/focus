#scope_module

// Search using NFA: can find submatches but kind of slow.
match_nfa :: (prog: *Prog, text: string, ctx: string, ctx_offset: int, anchor_in: Prog.Anchor, kind: Prog.MatchKind, num_matches: int) -> bool, matches: [] string {
	assert(num_matches > 0, "We need to capture at least the full match");

	nfa: Nfa;
	// We don’t want the matches in the pool, but everything else
	matches: [] string;

	pool: Pool;
	defer release(*pool);
	set_allocators(*pool);
	#if REGEXP_DEBUG	pool.overwrite_memory = true;

	{
		push_allocator(pool_allocator_proc, *pool);
		nfa.prog = prog;

		init(*nfa.q0, prog.inst.count);
		init(*nfa.q1, prog.inst.count);
		array_reserve(*nfa.stack,
			2 * prog.inst_count[cast(u32)InstOp.kInstCapture] +
			prog.inst_count[cast(u32)InstOp.kInstEmptyWidth] +
			prog.inst_count[cast(u32)InstOp.kInstNop] + 1); // + 1 for start inst

		nfa.start = prog.start;
		anchor := anchor_in;
		if kind == .kFullMatch {
			anchor = .ANCHORED;
		}

		if nfa.start == 0	return false, matches;
		if prog.anchor_start && ctx.count != text.count		return false, matches;
		if prog.anchor_end && ctx.count != ctx_offset + text.count	return false, matches;

		anchored := (anchor == .ANCHORED) || prog.anchor_start;
		nfa.longest = (kind != .kFirstMatch);
		nfa.endmatch = false;
		if prog.anchor_end {
			nfa.longest = true;
			nfa.endmatch = true;
		}

		nfa.ncaptures = 2 * num_matches;
		nfa.match = NewArray(nfa.ncaptures, int, false);
		memset(nfa.match.data, 0, nfa.match.count * size_of(type_of(nfa.match[0])));

		runq := *nfa.q0;
		nextq := *nfa.q1;

		// Loop over the text, stepping the machine.
		for pos: 0..text.count+1 {
			c := ifx pos < text.count then cast(int) text[pos] else -1;

			// This is a no-op the first time around the loop because runq is empty.
			id := step(*nfa, runq, nextq, c, text, ctx, ctx_offset, pos);
			assert(runq.count == 0);
			nextq, runq = runq, nextq;

			if id != 0 {
				// We're done: full match ahead.
				pos = text.count;
				while true {
					i := prog.inst[id];
					if get_opcode(i) == {
						case .kInstCapture;
							if i.cap < nfa.ncaptures {
								nfa.match[i.cap] = pos;
							}
							id = get_out(i);
							continue;

						case .kInstNop;
							id = get_out(i);
							continue;

						case .kInstMatch;
							nfa.match[1] = pos;
							nfa.matched = true;

						case;
							assert(false, "Unexpected opcode in short circuit: %", get_opcode(i));
					}
					break;
				}
				break;
			}

			if pos > text.count		break;

			// Start a new thread if there have not been any matches.
			// (No point in starting a new thread if there have been
			// matches, since it would be to the right of the match
			// we already found.)
			if !nfa.matched && (!anchored || pos == 0) {
				// Try to use prefix accel (e.g. memchr) to skip ahead.
				// The search must be unanchored and there must be zero
				// possible matches already.
				if !anchored && !runq.count && pos < text.count && prog.prefix_size {
					pos = prefix_accel(prog, text, pos);
					if pos < 0 {
						pos = text.count;
					}
				}

				t := new_thread(*nfa);
				copy_capture(*t.capture, nfa.match);
				t.capture[0] = pos;
				c = ifx pos < text.count then cast(s16)text[pos] else -1;
				add_to_queue(*nfa, runq, prog.start, c, ctx, ctx_offset, t, pos);
				decref(*nfa, t);
			}

			// If all the threads have died, stop early.
			if runq.count == 0		break;

			// @ToDo There was a special case here.
			// Not sure if it is needed after our transformations.

		}
	}

	if nfa.matched {
		matches = NewArray(num_matches, string, false);
		for i: 0..num_matches - 1 {
			matches[i] = slice(text, nfa.match[2 * i], nfa.match[2 * i + 1] - nfa.match[2 * i]);
		}

		if kind == .kFullMatch && matches[0].count != text.count {
			return false, matches;
		}
	}

	return nfa.matched, matches;
}

#scope_file

Nfa :: struct {
	prog: *Prog;
	start: int; // start instruction in program
	ncaptures: int; // number of submatches to track
	longest: bool;              // whether searching for longest match
	endmatch: bool;             // whether match must end at text.end()
	q0: Thread_Queue;
	q1: Thread_Queue;
	stack: [..] AddState;
	threads: Bucket_Array(Thread, 16);
	free_list: *Thread;
	match: [] int;  // best match so far
	matched: bool;         // any match so far?
}

Thread :: struct {
	// @ToDo @Cleanup I don’t want to ref-count here, but the original algorithm
	// is too complicated to safely remove the ref-counting while porting it to jai.
	// Needs to happend in a separat step once we have tests in place.
	union {
		ref: int;
		next: *Thread;
	}
	capture: [] int;
}

new_thread :: (using nfa: *Nfa) -> *Thread {
	t: *Thread;
	if free_list {
		t = free_list;
		free_list = t.next;
	} else {
		t = find_and_occupy_empty_slot(*threads);
		t.capture = NewArray(ncaptures, int, false);
	}
	t.ref = 1;
	return t;
}

incref :: (t: *Thread) -> *Thread {
	t.ref += 1;
	return t;
}

decref :: (using nfa: *Nfa, t: *Thread) {
	t.ref -= 1;
	if !t.ref {
		t.next = free_list;
		free_list = t;
	}
}

Thread_Queue :: Sparse_Array(*Thread);

AddState :: struct {
	id: int;
	t: *Thread;
}

make_state :: (id: int, t: *Thread) -> AddState {
	s: AddState;
	s.id = id;
	s.t = t;
	return s;
}

copy_capture :: (dst: *[] int, src: [] int) {
	memcpy(dst.data, src.data, dst.count * size_of(type_of(src[0])));
}

// Run runq on byte c, appending new states to nextq.
// Updates matched_ and match_ as new, better matches are found.
// context is used (with p) for evaluating empty-width specials.
// p is the position of byte c in the input string for AddToThreadq;
// p-1 will be used when processing Match instructions.
// Frees all the threads on runq.
// If there is a shortcut to the end, returns that shortcut.
step :: (using nfa: *Nfa, runq: *Thread_Queue, nextq: *Thread_Queue, c: int, text: string, ctx: string, ctx_offset: int, pos: int) -> int {
	for runq {
		t := it.value;
		if t == null		continue;

		if longest {
			// Can skip any threads started after our current best match.
			if (matched && match[0] < t.capture[0]) {
				decref(nfa, t);
				continue;
			}
		}

		id := it.index;
		i := prog.inst[id];

		if get_opcode(i) == {
			case;
				assert(false, "Unexpected opcode: %", get_opcode(i));

			case .kInstByteRange;
				add_to_queue(nfa, nextq, get_out(i), c, ctx, ctx_offset, t, pos);

			case .kInstAltMatch;
				if it_index == 0 {
					// The match is ours if we want it.
					if greedy(i, prog) || longest {
						copy_capture(*match, t.capture);
						matched = true;

						decref(nfa, t);
						for j: it_index+1..cast(int)runq.count-1 {
							if runq.dense[j].value != null {
								decref(nfa, runq.dense[j].value);
							}
						}
						runq.count = 0;
						if greedy(i, prog) {
							return i.out1;
						} else {
							return get_out(i);
						}
					}
				}

			case .kInstMatch;
				// @ToDo There was a special case here.
				// Not sure if it is needed after our transformations.

				if !endmatch || pos - 1 == text.count {
					if longest {
						// Leftmost-longest mode: save this match only if
						// it is either farther to the left or at the same
						// point but longer than an existing match.
						if !matched || t.capture[0] < match[0] || t.capture[0] == match[0] && pos - 1 > match[1] {
							copy_capture(*match, t.capture);
							match[1] = pos - 1;
							matched = true;
						}
					} else {
						// Leftmost-biased mode: this match is by definition
						// better than what we've already found (see next line).
						copy_capture(*match, t.capture);
						match[1] = pos - 1;
						matched = true;

						// Cut off the threads that can only find matches
						// worse than the one we just found: don't run the
						// rest of the current Threadq.
						decref(nfa, t);
						for j: it_index+1..cast(int)runq.count-1 {
							if runq.dense[j].value != null {
								decref(nfa, runq.dense[j].value);
							}
						}
						runq.count = 0;
						return 0;
					}
				}
		}
		decref(nfa, t);
	}

	runq.count = 0;
	return 0;
}

// Follows all empty arrows from id0 and enqueues all the states reached.
// Enqueues only the ByteRange instructions that match byte c.
// context is used (with p) for evaluating empty-width specials.
// pos is the current input position, and t0 is the current thread.
add_to_queue :: (using nfa: *Nfa, q: *Thread_Queue, id0: int, c: int, ctx: string, ctx_offset: int, t0_in: *Thread, pos: int) {
	if id0 == 0		return;

	// Use stack_ to hold our stack of instructions yet to process.
	// It was preallocated as follows:
	//   two entries per Capture;
	//   one entry per EmptyWidth; and
	//   one entry per Nop.
	// This reflects the maximum number of stack pushes that each can
	// perform. (Each instruction can be processed at most once.)
	stack_size := stack.allocated;
	stack.count = 0;
	array_add(*stack, make_state(id0, null));
	t0 := t0_in;
	while stack.count > 0 {
		assert(stack.count < stack_size);
		a := pop(*stack);

		if (a.t != null) {
			// t0 was a thread that we allocated and copied in order to
			// record the capture, so we must now decref it.
			decref(nfa, t0);
			t0 = a.t;
		}

		id := a.id;
		if id == 0	continue;
		if contains(<<q, id)		continue;

		// Create entry in q no matter what.  We might fill it in below,
		// or we might not.  Even if not, it is necessary to have it,
		// so that we don't revisit id0 during the recursion.
		add_unchecked(q, id, null);

		i := prog.inst[id];
		if get_opcode(i) == {
			case .kInstFail;

			case .kInstAltMatch;
				// Save state; will pick up at next byte.
				t := incref(t0);
				set(q, id, t);

				assert(!get_last(i));
				array_add(*stack, make_state(id+1, null));

			case .kInstNop;
				if !get_last(i) {
					array_add(*stack, make_state(id+1, null));
				}
				array_add(*stack, make_state(get_out(i), null));

			case .kInstCapture;
				if !get_last(i) {
					array_add(*stack, make_state(id+1, null));
				}
				j := i.cap;

				if j < ncaptures {
					// Push a dummy whose only job is to restore t0
					// once we finish exploring this possibility.
					array_add(*stack, make_state(0, t0));

					// Record capture.
					t := new_thread(nfa);
					copy_capture(*t.capture, t0.capture);
					t.capture[j] = pos;
					t0 = t;
				}
				array_add(*stack, make_state(get_out(i), null));

			case .kInstByteRange;
				if !matches(i, c) {
					if !get_last(i) {
						array_add(*stack, make_state(id + 1, null));
					}
				} else {
					// Save state; will pick up at next byte.
					t: = incref(t0);
					set(q, id, t);
					hint := get_hint(i);
					if hint != 0 {
						array_add(*stack, make_state(id + hint, null));
					}
				}

			case .kInstMatch;
				// Save state; will pick up at next byte.
				t: = incref(t0);
				set(q, id, t);

				if !get_last(i) {
					array_add(*stack, make_state(id + 1, null));
				}

			case .kInstEmptyWidth;
				if !get_last(i) {
					array_add(*stack, make_state(id + 1, null));
				}

				// Continue on if we have all the right flag bits.
				if !(i.empty & ~empty_flags(ctx, ctx_offset + pos)) {
					array_add(*stack, make_state(get_out(i), null));
				}

			case;
				assert(false, "Unexpected op: %", get_opcode(i));
		}
	}
}
