MAX_ONE_PASS_CAPTURES :: 5;

// You need to free the captures array, but not its contents (which just references the input text)
match :: (text: string, pattern: string, anchor: Anchor = .UNANCHORED) -> matched: bool, captures: [] string {
	regexp, success := compile(pattern);
	if !success {
		return false, .[];
	}
	defer uninit(*regexp);

	matched, captures: = match(text, regexp, anchor);
	return matched, captures;
}

// You need to free the captures array, but not its contents (which just references the input text)
match :: (text: string, re: Regexp, re_anchor_in: Anchor = .UNANCHORED) -> matched: bool, captures: [] string {
	num_captures := 1 + re.num_capture_groups;

	re_anchor := re_anchor_in;
	if re.prog.anchor_start && re.prog.anchor_end {
		re_anchor = .ANCHOR_BOTH;
	} else if re.prog.anchor_start && re_anchor != .ANCHOR_BOTH {
		re_anchor = .ANCHOR_START;
	}

	subtext := text;
	if re.prefix.count {
		if re.prefix.count > text.count {
			return false, .[];
		}

		if re.prefix_foldcase {
			if ascii_strcasecmp(re.prefix, subtext) != 0	return false, .[];
		} else {
			if memcmp(re.prefix.data, subtext.data, re.prefix.count) != 0		return false, .[];
		}

		subtext = slice(subtext, re.prefix.count, subtext.count - re.prefix.count);

		// If there is a required prefix, the anchor must be at least Anchor_Start.
		if re_anchor != .ANCHOR_BOTH {
			re_anchor = .ANCHOR_START;
		}
	}

	anchor := Prog.Anchor.UNANCHORED;
	kind := Prog.MatchKind.kFirstMatch;

	// @ToDo: For one-pass NFA
	// can_one_pass := is_one_pass && num_captures <= MAX_ONE_PASS_CAPTURES;
	// can_bit_state := can_bit_state(prog);

	if #complete re_anchor == {
		case .UNANCHORED;
			//	@ToDo: Implement!
		case .ANCHOR_BOTH; #through;
		case .ANCHOR_START;
			if re_anchor == .ANCHOR_BOTH {
				kind = .kFullMatch;
			}
			anchor = .ANCHORED;
			// @ToDo: Implement fast-passes
	}

	// @ToDo: Implement fast-passes

	matched, submatches := match_nfa(re.prog, subtext, text, re.prefix.count, anchor, kind, num_captures);

	if re.prefix.count && matched {
		// Prepend prefix to full match
		if submatches[0].count {
			submatches[0].data -= re.prefix.count;
			submatches[0].count += re.prefix.count;
		} else {
			submatches[0] = slice(text, 0, re.prefix.count);
		}
	}

	return matched, submatches;
}

// Avoid possible locale nonsense in standard strcasecmp.
// The string a is known to be all lowercase.
ascii_strcasecmp :: (a: string, b: string) -> int {
	for i: 0..a.count-1 {
		x := a[i];
		y := b[i];
		if #char "A" <= y && y <= #char "Z" {
			y += #char "a" - #char "A";
		}
		if x != y {
			return x - y;
		}
	}
	return 0;
}

// Execution engines.  They all search for the regexp (run the prog)
// in text, which is in the larger context (used for ^ $ \b etc).
// Anchor and kind control the kind of search.
// Returns true if match found, false if not.
// If match found, fills match[0..nmatch-1] with submatch info.
// match[0] is overall match, match[1] is first set of parens, etc.
// If a particular submatch is not matched during the regexp match,
// it is set to NULL.
//
// Matching text == StringPiece(NULL, 0) is treated as any other empty
// string, but note that on return, it will not be possible to distinguish
// submatches that matched that empty string from submatches that didn't
// match anything.  Either way, match[i] == NULL.


//   // Search using DFA: much faster than NFA but only finds
//   // end of match and can use a lot more memory.
//   // Returns whether a match was found.
//   // If the DFA runs out of memory, sets *failed to true and returns false.
//   // If matches != NULL and kind == kManyMatch and there is a match,
//   // SearchDFA fills matches with the match IDs of the final matching state.
//   bool SearchDFA(const StringPiece& text, const StringPiece& context,
//                  Anchor anchor, MatchKind kind, StringPiece* match0,
//                  bool* failed, SparseSet* matches);

//   // The callback issued after building each DFA state with BuildEntireDFA().
//   // If next is null, then the memory budget has been exhausted and building
//   // will halt. Otherwise, the state has been built and next points to an array
//   // of bytemap_range()+1 slots holding the next states as per the bytemap and
//   // kByteEndText. The number of the state is implied by the callback sequence:
//   // the first callback is for state 0, the second callback is for state 1, ...
//   // match indicates whether the state is a matching state.
//   using DFAStateCallback = std::function<void(const int* next, bool match)>;

//   // Build the entire DFA for the given match kind.
//   // Usually the DFA is built out incrementally, as needed, which
//   // avoids lots of unnecessary work.
//   // If cb is not empty, it receives one callback per state built.
//   // Returns the number of states built.
//   // FOR TESTING OR EXPERIMENTAL PURPOSES ONLY.
//   int BuildEntireDFA(MatchKind kind, const DFAStateCallback& cb);

//   // Controls whether the DFA should bail out early if the NFA would be faster.
//   // FOR TESTING ONLY.
//   static void TEST_dfa_should_bail_when_slow(bool b);


compute_num_captures :: (re: *Regexp_Node) -> int {
	count_pre_visit :: (num: *int, re: *Regexp_Node, v: *void) -> *void, bool {
		if re.op == .Capture {
			<<num += 1;
		}
		return null, false;
	}

	num_captures := 0;

	w := Walk(*int, *void).{pre_visit = count_pre_visit};
	walk(*num_captures, re, null, w);

	return num_captures;
}

