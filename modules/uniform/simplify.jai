#scope_module

compute_simple :: (using re: *Regexp_Node) -> bool {
	if #complete op == {
		case .NoMatch;	#through;
		case .EmptyMatch;	#through;
		case .Literal;	#through;
		case .LiteralString;	#through;
		case .BeginLine;	#through;
		case .EndLine;	#through;
		case .BeginText;	#through;
		case .WordBoundary;	#through;
		case .NoWordBoundary;	#through;
		case .EndText;	#through;
		case .AnyChar;	#through;
		case .AnyByte;	#through;
		case .HaveMatch;
			return true;
		case .Concat;		#through;
		case .Alternate;
			// These are simple as long as the subpieces are simple.
			for subs {
				if !it.simple	return false;
			}
			return true;
		case .CharClass;
			// Simple as long as the char class is not empty, not full.
			return char_class.nrunes != 0 && char_class.nrunes != Runemax + 1;
		case .Capture;
			return subs[0].simple;
		case .Star;	#through;
		case .Plus;	#through;
		case .Quest;
			if !subs[0].simple		return false;
			if subs[0].op == {
				case .Star;	#through;
				case .Plus;	#through;
				case .Quest;	#through;
				case .EmptyMatch;	#through;
				case .NoMatch;
					return false;
				case;
					return true;
			}
		case .Repeat;
			return false;
		case .kVerticalBar; #through;
		case .kLeftParen;
			assert(false, "Found parser tokens in compute_simple: %", op);
			return false;
	}
}

// Simplifies a regular expression, returning a new regexp.
// The new regexp uses traditional Unix egrep features only,
// plus the Perl (?:) non-capturing parentheses.
// Otherwise, no POSIX or Perl additions.  The new regexp
// captures exactly the same subexpressions (with the same indices)
// as the original.
// Does not edit given Regexp_Node.
simplify :: (re: *Regexp_Node, pool: *Regexp_Pool) -> *Regexp_Node {
	cre := coalesce(re, pool);
	if !cre		return null;

	sre := simplify_coalesced(cre, pool);
	if !sre		return null;

	return sre;
}

// Coalesces runs of star/plus/quest/repeat of the same literal along with any
// occurrences of that literal into repeats of that literal. It also works for
// char classes, any char and any byte.
coalesce :: (using re: *Regexp_Node, pool: *Regexp_Pool) -> *Regexp_Node {
	coalesce_post :: (pool: *Regexp_Pool, re: *Regexp_Node, parent_arg: *Regexp_Node, pre_arg: *Regexp_Node, child_args: [..] *Regexp_Node) -> *Regexp_Node {
		if re.subs.count == 0	return re;
		if re.op != .Concat {
			if !child_args_changed(re, child_args) return re;

			// Something changed. Build a new op.
			nre := new_regexp(pool, re.op, re.parse_flags);
			// @ToDo: Should we copy here?
			nre.subs = child_args;
			// Repeats and Captures have additional data that must be copied.
			if (re.op == .Repeat) {
				nre.min = re.min;
				nre.max = re.max;
			} else if re.op == .Capture {
				nre.cap = re.cap;
			}
			return nre;
		}

		can_coalesce_any := false;
		for i: 0..child_args.count - 2 {
			if can_coalesce(child_args[i], child_args[i+1]) {
				can_coalesce_any = true;
				break;
			}
		}

		if !can_coalesce_any {
			if !child_args_changed(re, child_args)	return re;

			// Something changed. Build a new op.
			nre := new_regexp(pool, re.op, re.parse_flags);
			// @ToDo: Should we copy here?
			nre.subs = child_args;
			return nre;
		}

		// @Speed: Do this in one pass with the loop above?
		for i: 0..child_args.count - 2 {
			if can_coalesce(child_args[i], child_args[i+1]) {
				do_coalesce(pool, *child_args[i], *child_args[i+1]);
			}
		}

		// Determine how many empty matches were left by DoCoalesce.
		n := 0;
		for child_args {
			if (it.op == .EmptyMatch) {
				n += 1;
			}
		}

		// Build a new op.
		nre := new_regexp(pool, re.op, re.parse_flags);
		nre.subs = NewArray(re.subs.count - n, *Regexp_Node, false);
		j := 0;
		for child_args {
			if (it.op != .EmptyMatch) {
				nre.subs[j] = it;
				j += 1;
			}
		}
		return nre;
	}

	w := Walk(*Regexp_Pool, *Regexp_Node).{post_visit = coalesce_post};
	result, stopped := walk(pool, re, null, w);
	if stopped		return null;
	return result;
}

child_args_changed :: (re: *Regexp_Node, child_args: [] *Regexp_Node) -> bool {
	for sub, i: re.subs {
		if sub != child_args[i]		return true;
	}
	return false;
}

can_coalesce :: (r1: *Regexp_Node, r2: *Regexp_Node) -> bool {
	// r1 must be a star/plus/quest/repeat of a literal, char class, any char or
	// any byte.
	if ((r1.op == .Star ||
			r1.op == .Plus ||
			r1.op == .Quest ||
			r1.op == .Repeat) &&
			(r1.subs[0].op == .Literal ||
			r1.subs[0].op == .CharClass ||
			r1.subs[0].op == .AnyChar ||
			r1.subs[0].op == .AnyByte)) {
		// r2 must be a star/plus/quest/repeat of the same literal, char class,
		// any char or any byte.
		if ((r2.op == .Star ||
				r2.op == .Plus ||
				r2.op == .Quest ||
				r2.op == .Repeat) &&
				regexp_equal(r1.subs[0], r2.subs[0]) &&
				// The parse flags must be consistent.
				((r1.parse_flags & .NonGreedy) == (r2.parse_flags & .NonGreedy))) {
			return true;
		}
		// ... OR an occurrence of that literal, char class, any char or any byte
		if (regexp_equal(r1.subs[0], r2)) {
			return true;
		}
		// ... OR a literal string that begins with that literal.
		if (r1.subs[0].op == .Literal && r2.op == .LiteralString && r2.runes[0] == r1.subs[0].rune &&
				// The parse flags must be consistent.
				((r1.subs[0].parse_flags & .FoldCase) == (r2.parse_flags & .FoldCase))) {
			return true;
		}
	}
	return false;
}

do_coalesce :: (pool: *Regexp_Pool, r1ptr: **Regexp_Node, r2ptr: **Regexp_Node) {
	leave_empty :: (r1ptr: **Regexp_Node, r2ptr: **Regexp_Node, pool: *Regexp_Pool, nre: *Regexp_Node) {
		// @ToDo, @Speed: Why don’t we set this to null instead of allocing a temporary new regexp?
		r1ptr.* = new_regexp(pool, .EmptyMatch, .NoParseFlags);
		r2ptr.* = nre;
	}

	r1 := r1ptr.*;
	r2 := r2ptr.*;

	nre := new_repeat(pool, r1.subs[0], r1.parse_flags, 0, 0);

	if r1.op == {
		case .Star;
			nre.min = 0;
			nre.max = -1;
		case .Plus;
			nre.min = 1;
			nre.max = -1;
		case .Quest;
			nre.min = 0;
			nre.max = 1;
		case .Repeat;
			nre.min = r1.min;
			nre.max = r1.max;
		case;
			assert(false, "Unexpected r1.op: %", r1.op);
	}


	if r2.op == {
		case .Star;
			nre.max = -1;
			leave_empty(r1ptr, r2ptr, pool, nre);

		case .Plus;
			nre.min += 1;
			nre.max = -1;
			leave_empty(r1ptr, r2ptr, pool, nre);

		case .Quest;
			if nre.max != -1 {
				nre.max += 1;
			}
			leave_empty(r1ptr, r2ptr, pool, nre);

		case .Repeat;
			nre.min += r2.min;
			if (r2.max == -1) {
				nre.max = -1;
			} else if (nre.max != -1) {
				nre.max += r2.max;
			}
			leave_empty(r1ptr, r2ptr, pool, nre);

		case .Literal; #through;
		case .CharClass; #through;
		case .AnyChar; #through;
		case .AnyByte;
			nre.min += 1;
			if (nre.max != -1) {
				nre.max += 1;
			}
			leave_empty(r1ptr, r2ptr, pool, nre);

		case .LiteralString;
			r := r1.subs[0].rune;
			// Determine how much of the literal string is removed.
			// We know that we have at least one rune. :)
			n: s16 = 1;
			while (n < r2.runes.count && r2.runes[n] == r) {
				n += 1;
			}
			nre.min += n;
			if (nre.max != -1) {
				nre.max += n;
			}
			if n == r2.runes.count {
				leave_empty(r1ptr, r2ptr, pool, nre);
			} else {
				r1ptr.* = nre;
				r2ptr.* = new_literal_string(pool, slice(r2.runes, n, r2.runes.count - n), r2.parse_flags);
			}

		case;
			assert(false, "Unexpected r2.op: %", r2.op);
	}
}

simplify_coalesced :: (using re: *Regexp_Node, pool: *Regexp_Pool) -> *Regexp_Node {
	simplify_pre :: (pool: *Regexp_Pool, re: *Regexp_Node, parent_arg: *Regexp_Node) -> *Regexp_Node, stop: bool {
		if (re.simple) {
			return re, true;
		}

		return null, false;
	}
	simplify_post :: (pool: *Regexp_Pool, re: *Regexp_Node, parent_arg: *Regexp_Node, pre_arg: *Regexp_Node, child_args: [..] *Regexp_Node) -> *Regexp_Node {
		if re.op == {
			case .NoMatch; #through;
			case .EmptyMatch; #through;
			case .Literal; #through;
			case .LiteralString; #through;
			case .BeginLine; #through;
			case .EndLine; #through;
			case .BeginText; #through;
			case .WordBoundary; #through;
			case .NoWordBoundary; #through;
			case .EndText; #through;
			case .AnyChar; #through;
			case .AnyByte; #through;
			case .HaveMatch;
				// All these are always simple.
				re.simple = true;
				return re;

			case .Concat; #through;
			case .Alternate;
				// These are simple as long as the subpieces are simple.
				if !child_args_changed(re, child_args) {
					re.simple = true;
					return re;
				}
				nre := new_regexp(pool, re.op, re.parse_flags);
				// @ToDo: Should we copy here?
				nre.subs = child_args;
				nre.simple = true;
				return nre;


			case .Capture;
				newsub := child_args[0];
				if newsub == re.subs[0] {
					re.simple = true;
					return re;
				}
				nre := new_regexp(pool, .Capture, re.parse_flags);
				nre.subs = NewArray(1, *Regexp_Node, false);
				nre.subs[0] = newsub;
				nre.cap = re.cap;
				nre.simple = true;
				return nre;

			case .Star; #through;
			case .Plus; #through;
			case .Quest;
				newsub := child_args[0];
				// Special case: repeat the empty string as much as
				// you want, but it's still the empty string.
				if newsub.op == .EmptyMatch		return newsub;

				// These are simple as long as the subpiece is simple.
				if newsub == re.subs[0] {
					re.simple = true;
					return re;
				}

				// These are also idempotent if flags are constant.
				if re.op == newsub.op && re.parse_flags == newsub.parse_flags	return newsub;

				nre := new_regexp(pool, re.op, re.parse_flags);
				nre.subs = NewArray(1, *Regexp_Node, false);
				nre.subs[0] = newsub;
				nre.simple = true;
				return nre;

			case .Repeat;
				newsub := child_args[0];
				// Special case: repeat the empty string as much as
				// you want, but it's still the empty string.
				if newsub.op == .EmptyMatch		return newsub;

				nre := simplify_repeat(pool, newsub, re.min, re.max, re.parse_flags);
				nre.simple = true;
				return nre;

			case .CharClass;
				nre := simplify_char_class(pool, re);
				nre.simple = true;
				return nre;
			case;
				assert(false, "Simpilfy case not handled: %", re.op);
				return null;
		}
	}

	w := Walk(*Regexp_Pool, *Regexp_Node).{pre_visit = simplify_pre, post_visit = simplify_post};
	result, stopped := walk(pool, re, null, w);
	if stopped		return null;
	return result;
}

// Creates a concatenation of two Regexp_Node, consuming refs to re1 and re2.
// Returns a new Regexp_Node, handing the ref to the caller.
concat2 :: (pool: *Regexp_Pool, re1: *Regexp_Node, re2: *Regexp_Node, parse_flags: ParseFlags) -> *Regexp_Node {
	re := new_regexp(pool, .Concat, parse_flags);
	re.subs = NewArray(2, *Regexp_Node, false);
	re.subs[0] = re1;
	re.subs[1] = re2;
	return re;
}

// Simplifies the expression re{min,max} in terms of *, +, and ?.
// Returns a new regexp.  Does not edit re.  Does not consume reference to re.
// Caller must Decref return value when done with it.
// The result will *not* necessarily have the right capturing parens
// if you call ToString() and re-parse it: (x){2} becomes (x)(x),
// but in the Regexp_Node* representation, both (x) are marked as $1.
simplify_repeat :: (pool: *Regexp_Pool, re: *Regexp_Node, min: int, max: int, f: ParseFlags) -> *Regexp_Node {
	// x{n,} means at least n matches of x.
	if (max == -1) {
		// Special case: x{0,} is x*
		if (min == 0) return new_star(pool, re, f);

		// Special case: x{1,} is x+
		if (min == 1) return new_plus(pool, re, f);

		// General case: x{4,} is xxxx+
		nre_subs := NewArray(min, *Regexp_Node, false);
		for i: 0..min-2 {
			nre_subs[i] = re;
		}
		nre_subs[min-1] = new_plus(pool, re, f);
		return new_concat(pool, nre_subs, f);
	}

	// Special case: (x){0} matches only empty string.
	if (min == 0 && max == 0) return new_regexp(pool, .EmptyMatch, f);

	// Special case: x{1} is just x.
	if (min == 1 && max == 1) return re;

	// General case: x{n,m} means n copies of x and m copies of x?.
	// The machine will do less work if we nest the final m copies,
	// so that x{2,5} = xx(x(x(x)?)?)?

	// Build leading prefix: xx.  Capturing only on the last one.
	nre: *Regexp_Node;
	if (min > 0) {
		nre_subs := NewArray(min, *Regexp_Node, false);
		for i: 0..min-1 {
			nre_subs[i] = re;
		}
		nre = new_concat(pool, nre_subs, f);
	}

	// Build and attach suffix: (x(x(x)?)?)?
	if (max > min) {
		suf := new_quest(pool, re, f);
		for i: min+1..max-1 {
			suf = new_quest(pool, concat2(pool, re, suf, f), f);
		}
		if (nre == null) {
			nre = suf;
		} else {
			nre = concat2(pool, nre, suf, f);
		}
	}

	// Some degenerate case, like min > max, or min < max < 0.
	// This shouldn't happen, because the parser rejects such regexps.
	assert(nre != null, "Malformed repeat: % %", min, max);

	return nre;
}

// Simplifies a character class.
simplify_char_class :: (pool: *Regexp_Pool, re: *Regexp_Node) -> *Regexp_Node {
	// Special cases
	if (re.char_class.nrunes == 0)				return new_regexp(pool, .NoMatch, re.parse_flags);
	if (re.char_class.nrunes == Runemax + 1)	return new_regexp(pool, .AnyChar, re.parse_flags);

	return re;
}

#scope_file

// @ToDo: Move to a common utility module
slice :: inline (array: [] $T, index: int, count: int) -> [] T {
    assert(index >= 0, "index = %", index);             // @@ Should we also clamp in these cases?
    assert(count >= 0, "count = %", count);
	c: [] T = ---;
    if index >= array.count {
		c.data = null;
		c.count = 0;
		return c;
	}

    if index + count > array.count {
        count = array.count - index;
    }

    c.data = array.data + index;
    c.count = count;
    return c;
}

