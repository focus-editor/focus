// This parser is based on RE2’s parser
// https://github.com/google/re2

ParseFlags :: enum_flags u16 {
	NoParseFlags :: 0;
	FoldCase     :: 1<<0;   // Fold case during matching (case-insensitive).
	// Literal      :: 1<<1;   // Treat s as literal string instead of a regexp.
	ClassNL      :: 1<<2;   // Allow char classes like [^a-z] and \D and \s
	// and [[:space:]] to match newline.
	DotNL        :: 1<<3;   // Allow . to match newline.
	MatchNL      :: ClassNL | DotNL;
	OneLine      :: 1<<4;   // Treat ^ and $ as only matching at beginning and
	// end of text, not around embedded newlines.
	// (Perl's default)
	// Latin1       :: 1<<5;   // Regexp_Node and text are in Latin1, not UTF-8.
	NonGreedy    :: 1<<6;   // Repetition operators are non-greedy by default.
	PerlClasses  :: 1<<7;   // Allow Perl character classes like \d.
	PerlB        :: 1<<8;   // Allow Perl's \b and \B.
	PerlX        :: 1<<9;   // Perl extensions:
	//   non-capturing parens - (?: )
	//   non-greedy operators - *? +? ?? {}?
	//   flag edits - (?i) (?-i) (?i: )
	//     i - FoldCase
	//     m - !OneLine
	//     s - DotNL
	//     U - NonGreedy
	//   line ends: \A \z
	//   \Q and \E to disable/enable metacharacters
	//   (?P<name>expr) for named captures
	//   \C to match any single byte
	UnicodeGroups :: 1<<10;  // Allow \p{Han} for Unicode Han group
	//   and \P{Han} for its negation.
	NeverNL      :: 1<<11;  // Never match NL, even if the regexp mentions
	//   it explicitly.
	NeverCapture :: 1<<12;  // Parse all parens as non-capturing.

	// As close to Perl as we can get.
	LikePerl      :: ClassNL | OneLine | PerlClasses | PerlB | PerlX |
	UnicodeGroups;

	// Internal use only.
	WasDollar     :: 1<<13;  // on EndText: was $ in regexp text
	AllParseFlags :: (1<<14)-1;
};


Regexp_Node :: struct {
	// Operator.
	op: RegexpOp;
	// Is this regexp structure already simple
	// (has it been returned by Simplify)?
	simple: bool;

	// Flags saved from parsing and used during execution.
	// (Only FoldCase is used.)
	parse_flags: ParseFlags;

	// Subexpressions.
	// Concat and Alternate handle larger numbers of subexpressions
	// by building concatenation or alternation trees.
	// Other routines should call Concat or Alternate instead of
	// filling in sub() by hand.
	MAX_SUBS :: 0xFFFF;
	subs: [] *Regexp_Node;
	// Extra space for parse and teardown stacks.
	down: *Regexp_Node;

	// Arguments to operator.
	using args: union {
		struct {  // Repeat
			max: s16;
			min: s16;
		}
		struct {  // Capture
			cap: s32;
			name: string;
		}
		runes: [..] Rune; // LiteralString
		struct { // CharClass
			char_class: *CharClass;
			char_class_finished: bool;
		}
		rune: Rune;  // Literal
		// @ToDo Verify size is ok
		match_id: int;  // HaveMatch
		// void *the_union_[2];  // as big as any other element, for memset
	};
}

RegexpOp :: enum {
	// @ToDo: Rename all options

	// Matches no strings.
	NoMatch :: 1;

	// Matches empty string.
	EmptyMatch;

	// Matches rune_.
	Literal;

	// Matches runes_.
	LiteralString;

	// Matches concatenation of sub_[0..nsub-1].
	Concat;
	// Matches union of sub_[0..nsub-1].
	Alternate;

	// Matches sub_[0] zero or more times.
	Star;
	// Matches sub_[0] one or more times.
	Plus;
	// Matches sub_[0] zero or one times.
	Quest;

	// Matches sub_[0] at least min_ times, at most max_ times.
	// max_ == -1 means no upper limit.
	Repeat;

	// Parenthesized (capturing) subexpression.  Index is cap_.
	// Optionally, capturing name is name_.
	Capture;

	// Matches any character.
	AnyChar;

	// Matches any byte [sic].
	AnyByte;

	// Matches empty string at beginning of line.
	BeginLine;
	// Matches empty string at end of line.
	EndLine;

	// Matches word boundary "\b".
	WordBoundary;
	// Matches not-a-word boundary "\B".
	NoWordBoundary;

	// Matches empty string at beginning of text.
	BeginText;
	// Matches empty string at end of text.
	EndText;

	// Matches character class given by cc_.
	CharClass;

	// Forces match of entire expression right now,
	// with match ID match_id_ (used by RE2::Set).
	HaveMatch;

	// The ones below are only used internally by the parser and don’t occur in finshed RegExps
	kLeftParen;
	kVerticalBar;
};

Regexp_Pool :: struct {
	pool: *Pool;
	bucket: Bucket_Array(Regexp_Node, 64);
}

init :: (pool: *Regexp_Pool) {
	pool.pool = New(Pool);
	set_allocators(pool.pool);
	#if REGEXP_DEBUG	pool.pool.overwrite_memory = true;
	pool.bucket.allocator.proc = pool_allocator_proc;
	pool.bucket.allocator.data = pool.pool;
}

uninit :: (pool: *Regexp_Pool) {
	release(pool.pool);
	free(pool.pool);
}

#scope_module

new_regexp :: (pool: *Regexp_Pool, op: RegexpOp, flags: ParseFlags) -> *Regexp_Node {
	re := find_and_occupy_empty_slot(*pool.bucket);
	// Need to clear, in case we re-use a bucket slot
	// @ToDo, @Speed: This is unnecessary when its a fresh slot. Find a better way
	memset(re, 0, size_of(Regexp_Node));
	re.op = op;
	re.parse_flags = flags;
	return re;
}

remove_regexp :: (pool: *Regexp_Pool, re: *Regexp_Node) {
	// @ToDo: Delete subs!
	// @ToDO: Delete char_class!
	for * pool.bucket {
		if it == re {
			remove it;
			break;
		}
	}
}

// Tests equality of all top-level structure but not subregexps.
regexp_top_equal :: (a: *Regexp_Node, b: *Regexp_Node) -> bool {
	if a.op != b.op	 return false;

	if a.op == {
		case .NoMatch; #through;
		case .EmptyMatch; #through;
		case .AnyChar; #through;
		case .AnyByte; #through;
		case .BeginLine; #through;
		case .EndLine; #through;
		case .WordBoundary; #through;
		case .NoWordBoundary; #through;
		case .BeginText;
			return true;

		case .EndText;
			// The parse flags remember whether it's \z or (?-m:$),
			// which matters when testing against PCRE.
			return ((a.parse_flags ^ b.parse_flags) & .WasDollar) == 0;

		case .Literal;
			return a.rune == b.rune && ((a.parse_flags ^ b.parse_flags) & .FoldCase) == 0;

		case .LiteralString;
			return a.runes.count == b.runes.count && ((a.parse_flags ^ b.parse_flags) & .FoldCase) == 0 &&
				memcmp(a.runes.data, b.runes.data, a.runes.count * size_of(Rune)) == 0;

		case .Alternate; #through;
		case .Concat;
			return a.subs.count == b.subs.count;

		case .Star; #through;
		case .Plus; #through;
		case .Quest;
			return ((a.parse_flags ^ b.parse_flags) & .NonGreedy) == 0;

		case .Repeat;
			return ((a.parse_flags ^ b.parse_flags) & .NonGreedy) == 0 && a.min == b.min && a.max == b.max;

		case .Capture;
			return a.cap == b.cap && a.name == b.name;

		case .HaveMatch;
			return a.match_id == b.match_id;

		case .CharClass;
			return a.char_class.nrunes == b.char_class.nrunes &&
				a.char_class.ranges.count == b.char_class.ranges.count &&
				memcmp(a.char_class.ranges.data, b.char_class.ranges.data, a.char_class.ranges.count * size_of(RuneRange)) == 0;
		case;
			assert(false, "Unexpected op: %", a.op);
			return false;
	}
}

regexp_equal :: (a: *Regexp_Node, b: *Regexp_Node) -> bool {
	if a == null || b == null		return a == b;

	if !regexp_top_equal(a, b)	return false;

	// The stack has pairs of regexps waiting to
	// be compared.  The regexps are only equal if
	// all the pairs end up being equal.
	stack: [..] *Regexp_Node;
	stack.allocator = __temporary_allocator;

	a1 := a;
	b1 := b;
	while true {
		// Invariant: TopEqual(a1, b1) == true.
		a2: *Regexp_Node;
		b2: *Regexp_Node;
		if a1.op == {
			case .Alternate; #through;
			case .Concat;
				for i: 0..a1.subs.count-1 {
					a2 = a1.subs[i];
					b2 = b1.subs[i];
					if !regexp_top_equal(a2, b2)	return false;

					array_add(*stack, a2);
					array_add(*stack, b2);
				}

			case .Star; #through;
			case .Plus; #through;
			case .Quest; #through;
			case .Repeat; #through;
			case .Capture;
				a2 = a1.subs[0];
				b2 = b1.subs[0];
				if !regexp_top_equal(a2, b2)	return false;
				// Really:
				//   stack.push_back(a2);
				//   stack.push_back(b2);
				//   break;
				// but faster to assign directly and loop.
				a1 = a2;
				b1 = b2;
				continue;
			case;
				return true;
		}

		if !stack.count		return true;

		a1 = stack[stack.count-2];
		b1 = stack[stack.count-1];
		stack.count -= 2;
	}

	return true;
}

// Determines whether regexp matches must be anchored
// with a fixed string prefix.  If so, returns the prefix and
// the regexp that remains after the prefix.  The prefix might
// be ASCII case-insensitive.
required_prefix :: (re: *Regexp_Node, pool: *Regexp_Pool) -> prefix: string, foldcase: bool, suffix: *Regexp_Node {
	// No need for a walker: the regexp must be of the form
	// 1. some number of ^ anchors
	// 2. a literal char or string
	// 3. the rest
	suffix := re;
	if re.op != .Concat		return "", false, suffix;
	i := 0;
	while i < re.subs.count && re.subs[i].op == .BeginText {
		i += 1;
	}
	if i == 0 || i >= re.subs.count		return "", false, suffix;

	to_analyze := re.subs[i];
	if to_analyze.op != .Literal && to_analyze.op != .LiteralString		return "", false, suffix;

	i += 1;
	if (i < re.subs.count) {
		suffix = new_concat(pool, array_view(re.subs, i, re.subs.count - i), re.parse_flags);
	} else {
		suffix = new_regexp(pool, .EmptyMatch, re.parse_flags);
	}

	runes: [] Rune;
	if to_analyze.op == .Literal {
		runes.data = *to_analyze.rune;
		runes.count = 1;
	} else {
		runes = to_analyze.runes;
	}

	{
		push_allocator(pool_allocator_proc, pool.pool);
		prefix := string_from_runes(runes);
		return prefix, (to_analyze.parse_flags & .FoldCase) != 0, suffix;
	}
}

required_prefix_for_accel :: (re: Regexp_Node) -> prefix: string, foldcase: bool {
	// No need for a walker: the regexp must either begin with or be
	// a literal char or string.
	to_analyze := *re;
	if re.op == .Concat && re.subs.count > 0 {
		to_analyze = re.subs[0];
	}

	if to_analyze.op != .Literal && to_analyze.op != .LiteralString	return "", false;

	runes: [] Rune;
	if to_analyze.op == .Literal {
		runes.data = *to_analyze.rune;
		runes.count = 1;
	} else {
		runes = to_analyze.runes;
	}
	prefix := string_from_runes(runes);

	return prefix, (to_analyze.parse_flags & .FoldCase) != 0;
}

// @ToDo: rename these
StatusCode :: enum {
	// No error
	Success :: 0;

	// Unexpected error
	InternalError;

	// Parse errors
	BadEscape;          // bad escape sequence
	BadCharClass;       // bad character class
	BadCharRange;       // bad character class range
	MissingBracket;     // missing closing ]
	MissingParen;       // missing closing )
	UnexpectedParen;    // unexpected closing )
	TrailingBackslash;  // at end of regexp
	RepeatArgument;     // repeat argument missing, e.g. "*"
	RepeatSize;         // bad repetition argument
	RepeatOp;           // bad repetition operator
	BadPerlOp;          // bad perl operator
	BadUTF8;            // invalid UTF-8 in regexp
	BadNamedCapture;    // bad named capture
};

// Regular expression parse state.
// The list of parsed regexps so far is maintained as a vector of
// Regexp_Node pointers called the stack.  Left parenthesis and vertical
// bar markers are also placed on the stack, as Regexps with
// non-standard opcodes.
// Scanning a left parenthesis causes the parser to push a left parenthesis
// marker on the stack.
// Scanning a vertical bar causes the parser to pop the stack until it finds a
// vertical bar or left parenthesis marker (not popping the marker),
// concatenate all the popped results, and push them back on
// the stack (DoConcatenation).
// Scanning a right parenthesis causes the parser to act as though it
// has seen a vertical bar, which then leaves the top of the stack in the
// form LeftParen regexp VerticalBar regexp VerticalBar ... regexp VerticalBar.
// The parser pops all this off the stack and creates an alternation of the
// regexps (DoAlternation).
ParseState :: struct {
	flags: ParseFlags;
	whole_regexp: string;
	status: Status;
	stacktop: *Regexp_Node;
	ncap: s32;  // number of capturing parens seen
	rune_max := Runemax;  // maximum char value for this encoding
	pool: Regexp_Pool;
}

Status :: struct {
	code: StatusCode;
	error_arg: string;
}

make_status :: (code := StatusCode.Success, error_arg := "") -> Status {
	status: Status;
	status.code = code;
	status.error_arg = error_arg;
	return status;
}

rep :: (ps: *ParseState, op: RegexpOp, t: *string, lastunary: string) -> isunary: string, success: bool  {
	opstr := <<t;
	nongreedy := false;
	advance(t);  // '*' or '+' or '?'
	if (ps.flags & .PerlX) {
		if (t.count && (<<t)[0] == #char "?") {
			nongreedy = true;
			advance(t);  // '?'
		}
		if (lastunary) {
			// In Perl it is not allowed to stack repetition operators:
			//   a** is a syntax error, not a double-star.
			// (and a++ means something else entirely, which we don't support!)
			ps.status.code = .RepeatOp;
			ps.status.error_arg.data = lastunary.data;
			ps.status.error_arg.count = t.data - lastunary.data;
			return "", false;
		}
	}

	opstr.count -= t.count;
	if !push_repeat_op(ps, op, opstr, nongreedy)
		return "", false;
	return opstr, true;
}

// Parses the regular expression given by s,
// returning the corresponding Regexp_Node tree.
// Returns null on error.
parse :: (s: string, global_flags: ParseFlags = .NoParseFlags) -> *Regexp_Node, status: Status, pool: Regexp_Pool {
	ps: ParseState;
	ps.whole_regexp = s;
	ps.flags = global_flags;

	init(*ps.pool);
	push_allocator(pool_allocator_proc, ps.pool.pool);

	lastunary: string;
	t := s;
	while t.count {
		isunary: string;
		if t[0] == {
			case; {
				r, len, status := consume_rune(*t);
				if !len		return null, status, ps.pool;
				push_literal(*ps, r);
			}

			case #char "(";
				// "(?" introduces Perl escape.
				if ps.flags & .PerlX && t.count >= 2 && t[1] == #char "?" {
					// Flag changes and non-capturing groups.
					success: bool;
					ps.status, success = parse_perl_flags(*ps, *t);
					if !success		return null, ps.status, ps.pool;
				} else if ps.flags & .NeverCapture {
					do_left_paren_no_capture(*ps);
					advance(*t); // '('
				} else {
					do_left_paren(*ps);
					advance(*t); // '('
				}

			case #char "|";
				do_vertical_bar(*ps);
				advance(*t);  // '|'

			case #char ")";
				if !do_right_paren(*ps)		return null, ps.status, ps.pool;
				advance(*t);  // ')'

			case #char "^";  // Beginning of line.
				push_caret(*ps);
				advance(*t);  // '^'

			case #char "$";  // End of line.
				push_dollar(*ps);
				advance(*t);  // '$'

			case #char ".";  // Any character (possibly except newline).
				push_dot(*ps);
				advance(*t);  // '.'

			case #char "[";   // Character class.
				re, status, success := parse_char_class(*ps, *t);
				if !success					return null, status, ps.pool;
				push_regexp(*ps, re);

			case #char "*";  // Zero or more.
				success: bool;
				isunary, success = rep(*ps, .Star, *t, lastunary);
				if !success		return null, ps.status, ps.pool;
			case #char "+";  // One or more.
				success: bool;
				isunary, success = rep(*ps, .Plus, *t, lastunary);
				if !success		return null, ps.status, ps.pool;
			case #char "?";  // Zero or one.
				success: bool;
				isunary, success = rep(*ps, .Quest, *t, lastunary);
				if !success		return null, ps.status, ps.pool;

			case #char "{";   // Counted repetition.
				opstr := t;
				lo, hi, success := maybe_parse_repetition(*t);
				if !success {
					// Treat like a literal.
					push_literal(*ps, #char "{");
					advance(*t);  // '{'
				} else {
					nongreedy := false;
					if ps.flags & .PerlX {
						if t && t[0] == #char "?" {
							nongreedy = true;
							advance(*t);  // '?'
						}
						if lastunary {
							// Not allowed to stack repetition operators.
							ps.status.code = .RepeatOp;
							ps.status.error_arg = slice(lastunary, 0, t.data - lastunary.data);
							return null, ps.status, ps.pool;
						}
					}
					opstr.count -= t.count;
					if !push_repetition(*ps, lo, hi, opstr, nongreedy) {
						return null, ps.status, ps.pool;
					}
					isunary = opstr;
				}

			case #char "\\";    // Escaped character or Perl sequence.
								// \b and \B: word boundary or not
				parsed := false;
				if ps.flags & .PerlB &&
						t.count >= 2 && (t[1] == #char "b" || t[1] == #char "B") {
					if t[1] == #char "b" {
						push_simple_op(*ps, .WordBoundary);
					} else {
						push_simple_op(*ps, .NoWordBoundary);
					}
					advance(*t, 2);  // '\\', 'b'
					parsed = true;
				} else if (ps.flags & .PerlX) && t.count >= 2 {
					if (t[1] == #char "A") {
						push_simple_op(*ps, .BeginText);
						advance(*t, 2);  // '\\', 'A'
						parsed = true;
					} else if (t[1] == #char "z") {
						push_simple_op(*ps, .EndText);
						advance(*t, 2);  // '\\', 'z'
						parsed = true;
						// Do not recognize \Z, because this library can't
						// implement the exact Perl/PCRE semantics.
						// (This library treats "(?-m)$" as \z, even though
						// in Perl and PCRE it is equivalent to \Z.)
					} else if (t[1] == #char "C") {  // \C: any byte [sic]
						push_simple_op(*ps, .AnyByte);
						advance(*t, 2);  // '\\', 'C'
						parsed = true;
					} else if (t[1] == #char "Q") {  // \Q ... \E: the ... is always literals
						advance(*t, 2);  // '\\', 'Q'
						while t.count {
							if (t.count >= 2 && t[0] == #char "\\" && t[1] == #char "E") {
								advance(*t, 2);  // '\\', 'E'
								parsed = true;
							}
							r, len, status := consume_rune(*t);
							if !len		return null, status, ps.pool;
							push_literal(*ps, r);
						}
						parsed = true;
					}
				}

				if (!parsed && t.count >= 2 && (t[1] == #char "p" || t[1] == #char "P")) {
					re := new_regexp(*ps.pool, .CharClass, ps.flags & ~.FoldCase);
					re.char_class = New(CharClass);
					re.char_class_finished = false;
					parseStatus, parseResult := maybe_parse_unicode_group(*t, ps.flags, re.char_class);
					if parseResult == {
						case .kParseOk;
							push_regexp(*ps, re);
							lastunary = isunary;
							parsed = true;
						case .kParseError;
							remove_regexp(*ps.pool, re);
							ps.status = parseStatus;
							return null, ps.status, ps.pool;
						case .kParseNothing;
							remove_regexp(*ps.pool, re);
					}
				}

				if !parsed {
					g := maybe_parse_perl_cc_escape(*t, ps.flags);
					if g != null {
						re := new_regexp(*ps.pool, .CharClass, ps.flags & ~.FoldCase);
						re.char_class = New(CharClass);
						re.char_class_finished = false;
						add_unicode_group(re.char_class, g, g.sign, ps.flags);
						push_regexp(*ps, re);
						parsed = true;
					}
				}

				if !parsed {
					r, status, success := parse_escape(*t, ps.rune_max);
					if !success		return null, status, ps.pool;
					push_literal(*ps, r);
				}
		}
	}
	return do_finish(*ps), ps.status, ps.pool;
}

new_literal_string :: (pool: *Regexp_Pool, runes: [] Rune, flags: ParseFlags) -> *Regexp_Node {
	if runes.count == {
		case 0;
			return new_regexp(pool, .EmptyMatch, flags);
		case 1;
			return new_literal(pool, runes[0], flags);
		case;
			re := new_regexp(pool, .LiteralString, flags);
			for runes {
				add_rune_to_string(re, it);
			}
			return re;
	}
}

new_literal :: (pool: *Regexp_Pool, rune: Rune, flags: ParseFlags) -> *Regexp_Node {
	re := new_regexp(pool, .Literal, flags);
	re.rune = rune;
	return re;
}

new_star_plus_quest :: (pool: *Regexp_Pool, op: RegexpOp, sub: *Regexp_Node, flags: ParseFlags) -> *Regexp_Node {
	// Squash **, ++ and ??.
	if (op == sub.op && flags == sub.parse_flags)		return sub;

	// Squash *+, *?, +*, +?, ?* and ?+. They all squash to *, so because
	// op is Star/Plus/Quest, we just have to check that sub.op() is too.
	if ((sub.op == .Star ||
			sub.op == .Plus ||
			sub.op == .Quest) &&
			flags == sub.parse_flags) {
		// If sub is Star, no need to rewrite it.
		if (sub.op == .Star)	 return sub;

		re := new_regexp(pool, .Star, flags);
		array_resize(*re.subs, 1, false);
		re.subs[0] = sub.subs[0];
		return re;
	}

	re := new_regexp(pool, op, flags);
	array_resize(*re.subs, 1, false);
	re.subs[0] = sub;
	return re;
}

// @ToDo: Why does #bake_arguments not work here? (Compiler bug I can’t find a simple repro for)
// new_plus :: #bake_arguments new_star_plus_quest(op = .Plus);
// new_star :: #bake_arguments new_star_plus_quest(op = RegexpOp.Star);
// new_quest :: #bake_arguments new_star_plus_quest(op = .Quest);
new_plus:: (pool: *Regexp_Pool, sub: *Regexp_Node, flags: ParseFlags) -> *Regexp_Node {
	return new_star_plus_quest(pool, .Plus, sub, flags);
}
new_star :: (pool: *Regexp_Pool, sub: *Regexp_Node, flags: ParseFlags) -> *Regexp_Node {
	return new_star_plus_quest(pool, .Star, sub, flags);
}
new_quest :: (pool: *Regexp_Pool, sub: *Regexp_Node, flags: ParseFlags) -> *Regexp_Node {
	return new_star_plus_quest(pool, .Quest, sub, flags);
}

new_concat_or_alternate :: (pool: *Regexp_Pool, op: RegexpOp, subs: [] *Regexp_Node, flags: ParseFlags, can_factor: bool) -> *Regexp_Node {
	if subs.count == 1 {
		sub := subs[0];
		return sub;
	}

	if subs.count == 0 {
		if op == .Alternate {
			return new_regexp(pool, .NoMatch, flags);
		} else {
			return new_regexp(pool, .EmptyMatch, flags);
		}
	}

	// @ToDo, @Incomplete: We need this factorization for selecting the right
	// execution engine later. But does it matter if we implement only NDA for now?

	// PODArray<Regexp_Node*> subcopy;
	// if op == .Alternate && can_factor {
	// 	// Going to edit sub; make a copy so we don't step on caller.
	// 	subcopy = PODArray<Regexp_Node*>(nsub);
	// 	memmove(subcopy.data(), sub, nsub * sizeof sub[0]);
	// 	sub = subcopy.data();
	// 	nsub = FactorAlternation(sub, nsub, flags);
	// 	if (nsub == 1) {
	// 		Regexp_Node* re = sub[0];
	// 		return re;
	// 	}
	// }

	// @ToDo, @Incomplete: Is this necessary for us?
	// We use a normal array at the moment, so we waste 6 more bytes on the size and won’t overflow

	// if (nsub > MAX_SUBS) {
	// 	// Too many subexpressions to fit in a single Regexp_Node.
	// 	// Make a two-level tree.  Two levels gets us to 65535^2.
	// 	int nbigsub = (nsub+MAX_SUBS-1)/MAX_SUBS;
	// 	Regexp_Node* re = new Regexp_Node(op, flags);
	// 	re->AllocSub(nbigsub);
	// 	Regexp_Node** subs = re->sub();
	// 	for (int i = 0; i < nbigsub - 1; i++)
	// 	subs[i] = ConcatOrAlternate(op, sub+i*MAX_SUBS, MAX_SUBS, flags, false);
	// 	subs[nbigsub - 1] = ConcatOrAlternate(op, sub+(nbigsub-1)*MAX_SUBS,
	// 	nsub - (nbigsub-1)*MAX_SUBS, flags,
	// 	false);
	// 	return re;
	// }

	re := new_regexp(pool, op, flags);
	re.subs = subs;
	return re;
}

// concat :: #bake_arguments concat_or_alternate(op = .Concat, can_factor = false);
// alternate :: #bake_arguments concat_or_alternate(op = .Alternate, can_factor = true);
// alternate_no_factor :: #bake_arguments concat_or_alternate(op = .Alternate, can_factor = false);
new_concat :: (pool: *Regexp_Pool, subs: [] *Regexp_Node, flags: ParseFlags) -> *Regexp_Node {
	return new_concat_or_alternate(pool, .Concat, subs, flags, false);
}
new_alternate :: (pool: *Regexp_Pool, subs: [] *Regexp_Node, flags: ParseFlags) -> *Regexp_Node {
	return new_concat_or_alternate(pool, .Alternate, subs, flags, true);
}
new_alternate_no_factor :: (pool: *Regexp_Pool, subs: [] *Regexp_Node, flags: ParseFlags) -> *Regexp_Node {
	return new_concat_or_alternate(pool, .Alternate, subs, flags, false);
}

new_capture :: (pool: *Regexp_Pool, sub: *Regexp_Node, flags: ParseFlags, cap: s32) -> *Regexp_Node {
	re := new_regexp(pool, .Capture, flags);
	array_resize(*re.subs, 1, false);
	re.subs[0] = sub;
	re.cap = cap;
	return re;
}

new_repeat :: (pool: *Regexp_Pool, sub: *Regexp_Node, flags: ParseFlags, min: s16, max: s16) -> *Regexp_Node {
	re := new_regexp(pool, .Repeat, flags);
	array_resize(*re.subs, 1, false);
	re.subs[0] = sub;
	re.min = min;
	re.max = max;
	return re;
}

to_string :: (re: *Regexp_Node) -> string {
	// Appends a rune for use in a character class to the string t.
	append_cc_char :: (builder: *String_Builder, r: Rune) {
		if 0x20 <= r && r <= 0x7E {
			if find_index_from_left("[]^-\\", cast(u8)r) != -1 {
				append(builder, "\\");
			}
			append(builder, cast(u8)r);
		} else {
			if r == {
				case #char "\r";
					append(builder, "\\r");
					return;

				case #char "\t";
					append(builder, "\\t");
					return;

				case #char "\n";
					append(builder, "\\n");
					return;

				case 0x0c;
					append(builder, "\\f");
					return;
			}

			if (r < 0x100) {
				print_to_builder(builder, "\\x%", formatInt(r, base = 16, minimum_digits = 2));
			} else {
				print_to_builder(builder, "\\x{%}", formatInt(r, base = 16));
			}
		}
	}

	append_cc_range :: (builder: *String_Builder, lo: Rune, hi: Rune) {
		append_cc_char(builder, lo);
		// < would be enough here, but we want to print invalid ranges as well, just in case we have a bug somewhere
		if lo != hi {
			append(builder, #char "-");
			append_cc_char(builder, hi);
		}
	}

	append_literal :: (builder: *String_Builder, r: Rune, foldcase: bool) {
		if r != 0 && r < 0x80 && find_index_from_left("(){}[]*+?|.^$\\", cast(u8)r) != -1 {
			append(builder, #char "\\");
			append(builder, cast(u8)r);
		} else if (foldcase && #char "a" <= r && r <= #char "z") {
			r -= #char "a" - #char "A";
			append(builder, #char "[");
			append(builder, cast(u8)r);
			append(builder, cast(u8)r + #char "a" - #char "A");
			append(builder, #char "]");
		} else {
			append_cc_range(builder, r, r);
		}
	}

	// Appends ( if needed and passes new precedence to children.
	to_string_pre :: (builder: *String_Builder, re: *Regexp_Node, prec: Precedence) -> Precedence, bool {
		nprec := Precedence.Atom;

		if re.op == {
			case .NoMatch; #through;
			case .EmptyMatch; #through;
			case .Literal; #through;
			case .AnyChar; #through;
			case .AnyByte; #through;
			case .BeginLine; #through;
			case .EndLine; #through;
			case .BeginText; #through;
			case .EndText; #through;
			case .WordBoundary; #through;
			case .NoWordBoundary; #through;
			case .CharClass; #through;
			case .HaveMatch;
				// Atom is fine

			case .Concat; #through;
			case .LiteralString;
				if prec < .Concat {
					append(builder, "(?:");
				}
				nprec = .Concat;

			case .Alternate;
				if prec < .Alternate {
					append(builder, "(?:");
				}
				nprec = .Alternate;

			case .Capture;
				append(builder, #char "(");
				assert (re.cap != 0, "Capture 0");
				if re.name {
					append(builder, "?P<");
					append(builder, re.name);
					append(builder, #char ">");
				}
				nprec = .Paren;

			case .Star; #through;
			case .Plus; #through;
			case .Quest; #through;
			case .Repeat;
				if (prec < .Unary) {
					append(builder, "(?:");
				}
				// The subprecedence here is Atom instead of Unary
				// because PCRE treats two unary ops in a row as a parse error.
				nprec = .Atom;
		}

		return nprec, false;
	}

	to_string_post :: (builder: *String_Builder, re: *Regexp_Node, prec: Precedence, pre_arg: Precedence, child_args: [..] Precedence) -> Precedence {
		if re.op == {
			case .NoMatch;
				// There's no simple symbol for "no match", but
				// [^0-Runemax] excludes everything.
				append(builder, "[^\\x00-\\x{10ffff}]");

			case .EmptyMatch;
				// Append (?:) to make empty string visible,
				// unless this is already being parenthesized.
				if prec < .Empty {
					append(builder, "(?:)");
				}

			case .Literal;
				append_literal(builder, re.rune, (re.parse_flags & .FoldCase) != 0);

			case .LiteralString;
				for re.runes {
					append_literal(builder, it, (re.parse_flags & .FoldCase) != 0);
				}
				if prec < .Concat {
					append(builder, #char ")");
				}

			case .Concat;
				if prec < .Concat {
					append(builder, #char ")");
				}

			case .Alternate;
				// Clumsy but workable: the children all appended |
				// at the end of their strings, so just remove the last one.
				// @ToDo: we can’t do that with string_builder, at least not without very clumsy or very slow code
				// if ((*t_)[t_->size()-1] == '|')
				// t_->erase(t_->size()-1);
				// else
				// LOG(DFATAL) << "Bad final char: " << t_;
				if prec < .Alternate {
					append(builder, #char ")");
				}

			case .Star;
				append(builder, #char "*");
				if re.parse_flags & .NonGreedy {
					append(builder, #char "?");
				}

				if (prec < .Unary) {
					append(builder, #char ")");
				}

			case .Plus;
				append(builder, #char "+");
				if re.parse_flags & .NonGreedy {
					append(builder, #char "?");
				}
				if prec < .Unary {
					append(builder, #char ")");
				}

			case .Quest;
				append(builder, #char "?");
				if re.parse_flags & .NonGreedy {
					append(builder, #char "?");
				}
				if (prec < .Unary) {
					append(builder, #char ")");
				}

			case .Repeat;
				if (re.max == -1) {
					print_to_builder(builder, "{%,}", re.min);
				} else if re.min == re.max {
					print_to_builder(builder, "{%}", re.min);
				} else {
					print_to_builder(builder, "{%,%}", re.min, re.max);
				}
				if (re.parse_flags & .NonGreedy) {
					append(builder, #char "?");
				}
				if (prec < .Unary) {
					append(builder, #char ")");
				}

			case .AnyChar;
				append(builder, #char ".");

			case .AnyByte;
				append(builder, "\\C");

			case .BeginLine;
				append(builder, #char "^");

			case .EndLine;
				append(builder, #char "$");

			case .BeginText;
				append(builder, "(?-m:^)");

			case .EndText;
				if re.parse_flags & .WasDollar {
					append(builder, "(?-m:$)");
				} else {
					append(builder, "\\z");
				}

			case .WordBoundary;
				append(builder, "\\b");

			case .NoWordBoundary;
				append(builder, "\\B");

			case .CharClass;
				if (re.char_class.ranges.count == 0) {
					append(builder, "[^\\x00-\\x{10ffff}]");
				} else {
					append(builder, "[");
					// Heuristic: show class as negated if it contains the
					// non-character 0xFFFE and yet somehow isn't full.
					cc := re.char_class;
					if contains(cc, 0xFFFE) && cc.nrunes != Runemax + 1 {
						cc = copy(cc);
						negate(cc);
						append(builder, "^");
					}
					for cc.ranges {
						append_cc_range(builder, it.lo, it.hi);
					}
					if cc != re.char_class {
						uninit(cc);
						free(cc);
					}
					append(builder, #char "]");
				}

			case .Capture;
				append(builder, #char ")");

			case .HaveMatch;
				// There's no syntax accepted by the parser to generate
				// this node (it is generated by RE2::Set) so make something
				// up that is readable but won't compile.
				print_to_builder(builder, "(?HaveMatch:%)", re.match_id);
		}

		// If the parent is an alternation, append the | for it.
		if (prec == .Alternate) {
			append(builder, #char "|");
		}

		return .Atom;
	}

	builder: String_Builder;
	defer free_buffers(*builder);
	w := Walk(*String_Builder, Precedence).{pre_visit = to_string_pre, post_visit = to_string_post, copy = null};
	// @ToDO @Cleanup This is a workaround for nulls not being respected in struct literals yet.
	// Remove once the struct literal bug is fixed in jai
	w.copy = null;
	walk(*builder, re, .Toplevel, w);
	return builder_to_string(*builder);
}

#scope_file

MAX_REPEAT :: 1000;

// Finishes the regexp if necessary, preparing it for use in
// a more complex expression.
finish_regexp:: (re: *Regexp_Node) -> *Regexp_Node {
	if re == null		return null;

	re.down = null;

	if re.op == .CharClass && re.char_class != null && !re.char_class_finished {
		finish_char_class(re.char_class);
		re.char_class_finished = true;
	}

	return re;
}

// Pushes the given regular expression onto the stack.
// Could check for too much memory used here.
push_regexp :: (using ps: *ParseState, re: *Regexp_Node) {
	maybe_concat_string(ps, -1, .NoParseFlags);

	// Special case: a character class of one character is just
	// a literal.  This is a common idiom for escaping
	// single characters (e.g., [.] instead of \.), and some
	// analysis does better with fewer character classes.
	// Similarly, [Aa] can be rewritten as a literal A with ASCII case folding.
	if re.op == .CharClass && re.char_class != null {
		remove_above(re.char_class, rune_max);
		if re.char_class.nrunes == 1 {
			r := re.char_class.ranges[0].lo;
			// @ToDo, @Speed: No need to remove and create a new one, just clean up and repurpose the old one
			remove_regexp(*ps.pool, re);
			re = new_literal(*ps.pool, r, flags);
		} else if re.char_class.nrunes == 2 {
			r := re.char_class.ranges[0].lo;
			if #char "A" <= r && r <= #char "Z" && contains(re.char_class, r + #char "a" - #char "A") {
				// @ToDo, @Speed: No need to remove and create a new one, just clean up and repurpose the old one
				remove_regexp(*ps.pool, re);
				re = new_literal(*ps.pool, r + #char "a" - #char "A", flags | .FoldCase);
			}
		}
	}

	if !is_marker(re.op) {
		re.simple = compute_simple(re);
	}

	re.down = stacktop;
	stacktop = re;
}


// Add lo-hi to the class, along with their fold-equivalent characters.
// If lo-hi is already in the class, assume that the fold-equivalent
// chars are there too, so there's no work to do.
add_folded_range :: (cc: *CharClass, lo: Rune, hi: Rune, depth: int) {
	// AddFoldedRange calls itself recursively for each rune in the fold cycle.
	// Most folding cycles are small: there aren't any bigger than four in the
	// current Unicode tables.  make_unicode_casefold.py checks that
	// the cycles are not too long, and we double-check here using depth.
	assert(depth <= 10, "AddFoldedRange recurses too much.");

	if !add_range(cc, lo, hi)	return;  // lo-hi was already there? we're done

	while lo <= hi {
		f := lookup_casefold(unicode_casefold, lo);
		if f == null	break;  // lo has no fold, nor does anything above lo

		if lo < f.lo {  // lo has no fold; next rune with a fold is f.lo
			lo = f.lo;
		} else {
			// Add in the result of folding the range lo - f.hi
			// and that range's fold, recursively.
			lo1 := lo;
			hi1 := min(hi, f.hi);
			if f.delta ==  {
				case;
					lo1 += f.delta;
					hi1 += f.delta;
				case EvenOdd;
					if lo1%2 == 1	 lo1 -= 1;
					if hi1%2 == 0	 hi1 += 1;
				case OddEven;
					if lo1%2 == 0	 lo1 -= 1;
					if hi1%2 == 1	 hi1 += 1;
			}
			add_folded_range(cc, lo1, hi1, depth + 1);

			// Pick up where this fold left off.
			lo = f.hi + 1;
		}
	}
}

// Pushes the literal rune r onto the stack.
push_literal :: (using ps: *ParseState, r: Rune) {
	// Do case folding if needed.
	if (flags & .FoldCase) && cycle_fold_rune(r) != r {
		re := new_regexp(*ps.pool, .CharClass, flags & ~.FoldCase);
		re.char_class = New(CharClass);
		re.char_class_finished = false;
		r1 := r;

		if !(flags & .NeverNL) || r != #char "\n" {
			add_range(re.char_class, r, r);
		}
		r = cycle_fold_rune(r);
		while (r != r1) {
			if !(flags & .NeverNL) || r != #char "\n" {
				add_range(re.char_class, r, r);
			}
			r = cycle_fold_rune(r);
		}

		push_regexp(ps, re);
		return;
	}

	// Exclude newline if applicable.
	if (flags & .NeverNL) && r == #char "\n" {
		push_regexp(ps, new_regexp(*ps.pool, .NoMatch, flags));
		return;
	}

	// No fancy stuff worked.  Ordinary literal.
	if maybe_concat_string(ps, r, flags)	return;

	re := new_regexp(*ps.pool, .Literal, flags);
	re.rune = r;
	push_regexp(ps, re);
}

// Pushes a ^ onto the stack.
push_caret :: (using ps: *ParseState) {
	if flags & .OneLine {
		push_simple_op(ps, .BeginText);
	} else {
		push_simple_op(ps, .BeginLine);
	}
}

// Pushes a $ onto the stack.
push_dollar :: (using ps: *ParseState) {
	if flags & .OneLine {
		// Clumsy marker so that MimicsPCRE() can tell whether
		// this EndText was a $ and not a \z.
		// @ToDo, @Cleanup pass flags as optional argument
		oflags := flags;
		flags = flags | .WasDollar;
		push_simple_op(ps, .EndText);
		flags = oflags;
	} else {
		push_simple_op(ps, .EndLine);
	}
}

// Pushes a . onto the stack.
push_dot :: (using ps: *ParseState) {
	if flags & .DotNL && !(flags & .NeverNL) {
		push_simple_op(ps, .AnyChar);
	} else {
		// Rewrite . into [^\n]
		re := new_regexp(*ps.pool, .CharClass, flags & ~.FoldCase);
		re.char_class = New(CharClass);
		re.char_class_finished = false;
		add_range(re.char_class, 0, #char "\n" - 1);
		add_range(re.char_class, #char "\n" + 1, rune_max);
		push_regexp(ps, re);
	}
}

// Pushes a regexp with the given op (and no args) onto the stack.
push_simple_op :: (using ps: *ParseState, op: RegexpOp) {
	push_regexp(ps, new_regexp(*ps.pool, op, flags));
}

// Pushes a repeat operator regexp onto the stack.
// A valid argument for the operator must already be on the stack.
// The char c is the name of the operator, for use in error messages.
push_repeat_op :: (using ps: *ParseState, op: RegexpOp, s: string, nongreedy: bool) -> bool #must {
	if stacktop == null || is_marker(stacktop.op) {
		status.code = .RepeatArgument;
		status.error_arg = s;
		return false;
	}

	fl := ifx nongreedy then flags ^ .NonGreedy else flags;

	// Squash **, ++ and ??. Regexp_Node::Star() et al. handle this too, but
	// they're mostly for use during simplification, not during parsing.
	if op == stacktop.op && fl == stacktop.parse_flags	return true;

	// Squash *+, *?, +*, +?, ?* and ?+. They all squash to *, so because
	// op is a repeat, we just have to check that stacktop_.op() is too,
	// then adjust stacktop_.
	if (stacktop.op == .Star || stacktop.op == .Plus || stacktop.op == .Quest) && fl == stacktop.parse_flags {
		stacktop.op = .Star;
		return true;
	}

	re := new_regexp(*ps.pool, op, fl);
	re.down = stacktop.down;
	re.subs = NewArray(1, *Regexp_Node, initialized = false);
	re.subs[0] = finish_regexp(stacktop);
	re.simple = compute_simple(re);
	stacktop = re;
	return true;
}

// // RepetitionWalker reports whether the repetition regexp is valid.
// // Valid means that the combination of the top-level repetition
// // and any inner repetitions does not exceed n copies of the
// // innermost thing.
// // This rewalks the regexp tree and is called for every repetition,
// // so we have to worry about inducing quadratic behavior in the parser.
// // We avoid this by only using RepetitionWalker when min or max >= 2.
// // In that case the depth of any >= 2 nesting can only get to 9 without
// // triggering a parse error, so each subtree can only be rewalked 9 times.
// class RepetitionWalker : public Regexp_Node::Walker<int> {
//  public:
//   RepetitionWalker() {}
//   virtual int PreVisit(Regexp_Node* re, int parent_arg, bool* stop);
//   virtual int PostVisit(Regexp_Node* re, int parent_arg, int pre_arg,
//                         int* child_args, int nchild_args);
//   virtual int ShortVisit(Regexp_Node* re, int parent_arg);

//  private:
//   RepetitionWalker(const RepetitionWalker&) = delete;
//   RepetitionWalker& operator=(const RepetitionWalker&) = delete;
// };

// int RepetitionWalker::PreVisit(Regexp_Node* re, int parent_arg, bool* stop) {
//   int arg = parent_arg;
//   if (re.op() == .Repeat) {
//     int m = re.max();
//     if (m < 0) {
//       m = re.min();
//     }
//     if (m > 0) {
//       arg /= m;
//     }
//   }
//   return arg;
// }

// int RepetitionWalker::PostVisit(Regexp_Node* re, int parent_arg, int pre_arg,
//                                 int* child_args, int nchild_args) {
//   int arg = pre_arg;
//   for (int i = 0; i < nchild_args; i++) {
//     if (child_args[i] < arg) {
//       arg = child_args[i];
//     }
//   }
//   return arg;
// }

// int RepetitionWalker::ShortVisit(Regexp_Node* re, int parent_arg) {
//   // Should never be called: we use Walk(), not WalkExponential().
// #ifndef FUZZING_BUILD_MODE_UNSAFE_FOR_PRODUCTION
//   LOG(DFATAL) << "RepetitionWalker::ShortVisit called";
// #endif
//   return 0;
// }

// Pushes a repetition regexp onto the stack.
// A valid argument for the operator must already be on the stack.
push_repetition :: (using ps: *ParseState, min: int, max: int, s: string, nongreedy: bool) -> bool #must {
	if (max != -1 && max < min) || min > MAX_REPEAT || max > MAX_REPEAT {
		status.code = .RepeatSize;
		status.error_arg = s;
		return false;
	}
	if stacktop == null || is_marker(stacktop.op) {
		status.code = .RepeatArgument;
		status.error_arg = s;
		return false;
	}

	fl := ifx nongreedy then flags ^ .NonGreedy else flags;

	down := stacktop.down;
	re := new_repeat(*ps.pool, finish_regexp(stacktop), fl, cast(s16)min, cast(s16)max);
	re.down = down;
	re.simple = compute_simple(re);
	stacktop = re;
	if min >= 2 || max >= 2 {
		// @ToDo: Check for repetition limits (see RepetitionWalker in the original source)
		// if repetition_walk(stacktop, kMaxRepeat) == 0 {
		// 	status.code = .RepeatSize;
		// 	status.error_arg = s;
		// 	return false;
		// }
	}

	return true;
}

// Checks whether a particular regexp op is a marker.
is_marker :: (op: RegexpOp) -> bool {
	return op >= .kLeftParen;
}

// Processes a left parenthesis in the input.
// Pushes a marker onto the stack.
do_left_paren :: (using ps: *ParseState, name: string = "") {
	re := new_regexp(*ps.pool, .kLeftParen, flags);
	ncap += 1;
	re.cap = ncap;
	if name {
		re.name = name;
	}
	push_regexp(ps, re);
}

// Pushes a non-capturing marker onto the stack.
do_left_paren_no_capture :: (using ps: *ParseState) {
	re := new_regexp(*ps.pool, .kLeftParen, flags);
	re.cap = -1;
	push_regexp(ps, re);
}

// Processes a vertical bar in the input.
do_vertical_bar ::(using ps: *ParseState) {
	maybe_concat_string(ps, -1, .NoParseFlags);
	do_concatenation(ps);

	// Below the vertical bar is a list to alternate.
	// Above the vertical bar is a list to concatenate.
	// We just did the concatenation, so either swap
	// the result below the vertical bar or push a new
	// vertical bar on the stack.
	r1 := stacktop;
	if r1 {
		r2 := r1.down;
		if r2 && r2.op == .kVerticalBar {
			r3 := r2.down;
			if r3 && (r1.op == .AnyChar || r3.op == .AnyChar) {
				// AnyChar is above or below the vertical bar. Let it subsume
				// the other when the other is Literal, CharClass or AnyChar.
				if r3.op == .AnyChar && (r1.op == .Literal || r1.op == .CharClass || r1.op == .AnyChar) {
					// Discard r1.
					stacktop = r2;
					remove_regexp(*ps.pool, r1);
					return;
				}
				if r1.op == .AnyChar && (r3.op == .Literal || r3.op == .CharClass || r3.op == .AnyChar) {
					// Rearrange the stack and discard r3.
					r1.down = r3.down;
					r2.down = r1;
					stacktop = r2;
					remove_regexp(*ps.pool, r3);
					return;
				}
			}
			// Swap r1 below vertical bar (r2).
			r1.down = r2.down;
			r2.down = r1;
			stacktop = r2;
			return;
		}
	}
	push_simple_op(ps, .kVerticalBar);
}

// Processes a right parenthesis in the input.
do_right_paren :: (using ps: *ParseState) -> bool #must {
	// Finish the current concatenation and alternation.
	do_alternation(ps);

	// The stack should be: LeftParen regexp
	// Remove the LeftParen, leaving the regexp,
	// parenthesized.
	r1 := stacktop;
	if r1 == null || r1.down == null || r1.down.op != .kLeftParen {
		status.code = .UnexpectedParen;
		status.error_arg = whole_regexp;
		return false;
	}

	r2 := r1.down;

	// Pop off r1, r2.  Will Decref or reuse below.
	stacktop = r2.down;

	// Restore flags from when paren opened.
	re := r2;
	flags = re.parse_flags;

	// Rewrite LeftParen as capture if needed.
	if re.cap > 0 {
		re.op = .Capture;
		// re.cap is already set
		re.subs = NewArray(1, *Regexp_Node, initialized = false);
		re.subs[0] = finish_regexp(r1);
		re.simple = compute_simple(re);
	} else {
		remove_regexp(*ps.pool, re);
		re = r1;
	}

	push_regexp(ps, re);
	return true;
}

// Processes the end of input, returning the final regexp.
do_finish :: (using ps: *ParseState) -> *Regexp_Node {
	do_alternation(ps);
	re := stacktop;
	if re != null && re.down != null {
		status.code = .MissingParen;
		status.error_arg = whole_regexp;
		return null;
	}
	stacktop = null;
	return finish_regexp(re);
}

// Returns the leading regexp that re starts with.
// The returned Regexp_Node* points into a piece of re,
// so it must not be used after the caller calls re.Decref().
leading_regexp :: (re: *Regexp_Node) -> *Regexp_Node {
	if re.op == .EmptyMatch		return null;
	if re.op == .Concat && re.subs.count >= 2 {
		sub := re.subs[0];
		if sub.op == .EmptyMatch	 return null;
		return sub;
	}
	return re;
}

// Removes LeadingRegexp(re) from re and returns what's left.
// Consumes the reference to re and may edit it in place.
// If caller wants to hold on to LeadingRegexp(re),
// must have already Incref'ed it.
// @ToDO: Check if this is possible / correct in all usages without using reference counting!
remove_leading_regexp :: (using ps: *ParseState, re: *Regexp_Node) -> *Regexp_Node {
	if re.op == .EmptyMatch	return re;

	if re.op == .Concat && re.subs.count >= 2 {
		if re.subs[0].op == .EmptyMatch		return re;

		remove_regexp(*ps.pool, re.subs[0]);
		re.subs[0] = null;

		if re.subs.count == 2 {
			// Collapse concatenation to single regexp.
			nre := re.subs[1];
			re.subs[1] = null;
			remove_regexp(*ps.pool, re);
			return nre;
		}
		// 3 or more -> 2 or more.
		// @Stability: We won’t be able to free this array ever again
		// because we modify it’s base pointer.
		// But it doesn’t matter because we’re working within a Pool anyway.
		print("Before: %\n", re.subs);
		re.subs.data += 1;
		re.subs.count -= 1;
		print("After: %\n", re.subs);
		return re;
	} else {
		pf := re.parse_flags;
		// @ToDo, @Speed: Reuse regexp instead of removing and creating a new one?
		remove_regexp(*ps.pool, re);
		return new_regexp(*ps.pool, .EmptyMatch, pf);
	}
}

// Returns the leading string that re starts with.
// The returned Rune* points into a piece of re,
// so it must not be used after the caller calls re.Decref().
// @ToDo
// Rune* Regexp_Node::LeadingString(Regexp_Node* re, int *nrune,
//                             Regexp_Node::ParseFlags *flags) {
//   while (re.op() == .Concat && re.nsub() > 0)
//     re = re.sub()[0];

//   *flags = static_cast<Regexp_Node::ParseFlags>(re.parse_flags_ & Regexp_Node::FoldCase);

//   if (re.op() == .Literal) {
//     *nrune = 1;
//     return &re.rune_;
//   }

//   if (re.op() == .LiteralString) {
//     *nrune = re.nrunes_;
//     return re.runes_;
//   }

//   *nrune = 0;
//   return null;
// }

// Removes the first n leading runes from the beginning of re.
// Edits re in place.
// @ToDO
// void Regexp_Node::RemoveLeadingString(Regexp_Node* re, int n) {
//   // Chase down concats to find first string.
//   // For regexps generated by parser, nested concats are
//   // flattened except when doing so would overflow the 16-bit
//   // limit on the size of a concatenation, so we should never
//   // see more than two here.
//   Regexp_Node* stk[4];
//   size_t d = 0;
//   while (re.op() == .Concat) {
//     if (d < arraysize(stk))
//       stk[d++] = re;
//     re = re.sub()[0];
//   }

//   // Remove leading string from re.
//   if (re.op() == .Literal) {
//     re.rune_ = 0;
//     re.op_ = .EmptyMatch;
//   } else if (re.op() == .LiteralString) {
//     if (n >= re.nrunes_) {
//       delete[] re.runes_;
//       re.runes_ = null;
//       re.nrunes_ = 0;
//       re.op_ = .EmptyMatch;
//     } else if (n == re.nrunes_ - 1) {
//       Rune rune = re.runes_[re.nrunes_ - 1];
//       delete[] re.runes_;
//       re.runes_ = null;
//       re.nrunes_ = 0;
//       re.rune_ = rune;
//       re.op_ = .Literal;
//     } else {
//       re.nrunes_ -= n;
//       memmove(re.runes_, re.runes_ + n, re.nrunes_ * sizeof re.runes_[0]);
//     }
//   }

//   // If re is now empty, concatenations might simplify too.
//   while (d > 0) {
//     re = stk[--d];
//     Regexp_Node** sub = re.sub();
//     if (sub[0].op() == .EmptyMatch) {
//       sub[0].Decref();
//       sub[0] = null;
//       // Delete first element of concat.
//       switch (re.nsub()) {
//         case 0:
//         case 1:
//           // Impossible.
//           LOG(DFATAL) << "Concat of " << re.nsub();
//           re.submany_ = null;
//           re.op_ = .EmptyMatch;
//           break;

//         case 2: {
//           // Replace re with sub[1].
//           Regexp_Node* old = sub[1];
//           sub[1] = null;
//           re.Swap(old);
//           old.Decref();
//           break;
//         }

//         default:
//           // Slide down.
//           re.nsub_--;
//           memmove(sub, sub + 1, re.nsub_ * sizeof sub[0]);
//           break;
//       }
//     }
//   }
// }

// @ToDo: All of that
//// In the context of factoring alternations, a Splice is: a factored prefix or
//// merged character class computed by one iteration of one round of factoring;
//// the span of subexpressions of the alternation to be "spliced" (i.e. removed
//// and replaced); and, for a factored prefix, the number of suffixes after any
//// factoring that might have subsequently been performed on them. For a merged
//// character class, there are no suffixes, of course, so the field is ignored.
//struct Splice {
//  Splice(Regexp_Node* prefix, Regexp_Node** sub, int nsub)
//      : prefix(prefix),
//        sub(sub),
//        nsub(nsub),
//        nsuffix(-1) {}

//  Regexp_Node* prefix;
//  Regexp_Node** sub;
//  int nsub;
//  int nsuffix;
//};

//// Named so because it is used to implement an explicit stack, a Frame is: the
//// span of subexpressions of the alternation to be factored; the current round
//// of factoring; any Splices computed; and, for a factored prefix, an iterator
//// to the next Splice to be factored (i.e. in another Frame) because suffixes.
//struct Frame {
//  Frame(Regexp_Node** sub, int nsub)
//      : sub(sub),
//        nsub(nsub),
//        round(0) {}

//  Regexp_Node** sub;
//  int nsub;
//  int round;
//  std::vector<Splice> splices;
//  int spliceidx;
//};

//// Bundled into a class for friend access to Regexp_Node without needing to declare
//// (or define) Splice in regexp.h.
//class FactorAlternationImpl {
// public:
//  static void Round1(Regexp_Node** sub, int nsub,
//                     Regexp_Node::ParseFlags flags,
//                     std::vector<Splice>* splices);
//  static void Round2(Regexp_Node** sub, int nsub,
//                     Regexp_Node::ParseFlags flags,
//                     std::vector<Splice>* splices);
//  static void Round3(Regexp_Node** sub, int nsub,
//                     Regexp_Node::ParseFlags flags,
//                     std::vector<Splice>* splices);
//};

//// Factors common prefixes from alternation.
//// For example,
////     ABC|ABD|AEF|BCX|BCY
//// simplifies to
////     A(B(C|D)|EF)|BC(X|Y)
//// and thence to
////     A(B[CD]|EF)|BC[XY]
////
//// Rewrites sub to contain simplified list to alternate and returns
//// the new length of sub.  Adjusts reference counts accordingly
//// (incoming sub[i] decremented, outgoing sub[i] incremented).
//int Regexp_Node::FactorAlternation(Regexp_Node** sub, int nsub, ParseFlags flags) {
//  std::vector<Frame> stk;
//  stk.emplace_back(sub, nsub);

//  for (;;) {
//    auto& sub = stk.back().sub;
//    auto& nsub = stk.back().nsub;
//    auto& round = stk.back().round;
//    auto& splices = stk.back().splices;
//    auto& spliceidx = stk.back().spliceidx;

//    if (splices.empty()) {
//      // Advance to the next round of factoring. Note that this covers
//      // the initialised state: when splices is empty and round is 0.
//      round++;
//    } else if (spliceidx < static_cast<int>(splices.size())) {
//      // We have at least one more Splice to factor. Recurse logically.
//      stk.emplace_back(splices[spliceidx].sub, splices[spliceidx].nsub);
//      continue;
//    } else {
//      // We have no more Splices to factor. Apply them.
//      auto iter = splices.begin();
//      int out = 0;
//      for (int i = 0; i < nsub; ) {
//        // Copy until we reach where the next Splice begins.
//        while (sub + i < iter.sub)
//          sub[out++] = sub[i++];
//        switch (round) {
//          case 1:
//          case 2: {
//            // Assemble the Splice prefix and the suffixes.
//            Regexp_Node* re[2];
//            re[0] = iter.prefix;
//            re[1] = Regexp_Node::AlternateNoFactor(iter.sub, iter.nsuffix, flags);
//            sub[out++] = Regexp_Node::Concat(re, 2, flags);
//            i += iter.nsub;
//            break;
//          }
//          case 3:
//            // Just use the Splice prefix.
//            sub[out++] = iter.prefix;
//            i += iter.nsub;
//            break;
//          default:
//            LOG(DFATAL) << "unknown round: " << round;
//            break;
//        }
//        // If we are done, copy until the end of sub.
//        if (++iter == splices.end()) {
//          while (i < nsub)
//            sub[out++] = sub[i++];
//        }
//      }
//      splices.clear();
//      nsub = out;
//      // Advance to the next round of factoring.
//      round++;
//    }

//    switch (round) {
//      case 1:
//        FactorAlternationImpl::Round1(sub, nsub, flags, &splices);
//        break;
//      case 2:
//        FactorAlternationImpl::Round2(sub, nsub, flags, &splices);
//        break;
//      case 3:
//        FactorAlternationImpl::Round3(sub, nsub, flags, &splices);
//        break;
//      case 4:
//        if (stk.size() == 1) {
//          // We are at the top of the stack. Just return.
//          return nsub;
//        } else {
//          // Pop the stack and set the number of suffixes.
//          // (Note that references will be invalidated!)
//          int nsuffix = nsub;
//          stk.pop_back();
//          stk.back().splices[stk.back().spliceidx].nsuffix = nsuffix;
//          ++stk.back().spliceidx;
//          continue;
//        }
//      default:
//        LOG(DFATAL) << "unknown round: " << round;
//        break;
//    }

//    // Set spliceidx depending on whether we have Splices to factor.
//    if (splices.empty() || round == 3) {
//      spliceidx = static_cast<int>(splices.size());
//    } else {
//      spliceidx = 0;
//    }
//  }
//}

//void FactorAlternationImpl::Round1(Regexp_Node** sub, int nsub,
//                                   Regexp_Node::ParseFlags flags,
//                                   std::vector<Splice>* splices) {
//  // Round 1: Factor out common literal prefixes.
//  int start = 0;
//  Rune* rune = null;
//  int nrune = 0;
//  Regexp_Node::ParseFlags runeflags = Regexp_Node::NoParseFlags;
//  for (int i = 0; i <= nsub; i++) {
//    // Invariant: sub[start:i] consists of regexps that all
//    // begin with rune[0:nrune].
//    Rune* rune_i = null;
//    int nrune_i = 0;
//    Regexp_Node::ParseFlags runeflags_i = Regexp_Node::NoParseFlags;
//    if (i < nsub) {
//      rune_i = Regexp_Node::LeadingString(sub[i], &nrune_i, &runeflags_i);
//      if (runeflags_i == runeflags) {
//        int same = 0;
//        while (same < nrune && same < nrune_i && rune[same] == rune_i[same])
//          same++;
//        if (same > 0) {
//          // Matches at least one rune in current range.  Keep going around.
//          nrune = same;
//          continue;
//        }
//      }
//    }

//    // Found end of a run with common leading literal string:
//    // sub[start:i] all begin with rune[0:nrune],
//    // but sub[i] does not even begin with rune[0].
//    if (i == start) {
//      // Nothing to do - first iteration.
//    } else if (i == start+1) {
//      // Just one: don't bother factoring.
//    } else {
//      Regexp_Node* prefix = Regexp_Node::LiteralString(rune, nrune, runeflags);
//      for (int j = start; j < i; j++)
//        Regexp_Node::RemoveLeadingString(sub[j], nrune);
//      splices.emplace_back(prefix, sub + start, i - start);
//    }

//    // Prepare for next iteration (if there is one).
//    if (i < nsub) {
//      start = i;
//      rune = rune_i;
//      nrune = nrune_i;
//      runeflags = runeflags_i;
//    }
//  }
//}

//void FactorAlternationImpl::Round2(Regexp_Node** sub, int nsub,
//                                   Regexp_Node::ParseFlags flags,
//                                   std::vector<Splice>* splices) {
//  // Round 2: Factor out common simple prefixes,
//  // just the first piece of each concatenation.
//  // This will be good enough a lot of the time.
//  //
//  // Complex subexpressions (e.g. involving quantifiers)
//  // are not safe to factor because that collapses their
//  // distinct paths through the automaton, which affects
//  // correctness in some cases.
//  int start = 0;
//  Regexp_Node* first = null;
//  for (int i = 0; i <= nsub; i++) {
//    // Invariant: sub[start:i] consists of regexps that all
//    // begin with first.
//    Regexp_Node* first_i = null;
//    if (i < nsub) {
//      first_i = Regexp_Node::LeadingRegexp(sub[i]);
//      if (first != null &&
//          // first must be an empty-width op
//          // OR a char class, any char or any byte
//          // OR a fixed repeat of a literal, char class, any char or any byte.
//          (first.op() == .BeginLine ||
//           first.op() == .EndLine ||
//           first.op() == .WordBoundary ||
//           first.op() == .NoWordBoundary ||
//           first.op() == .BeginText ||
//           first.op() == .EndText ||
//           first.op() == .CharClass ||
//           first.op() == .AnyChar ||
//           first.op() == .AnyByte ||
//           (first.op() == .Repeat &&
//            first.min() == first.max() &&
//            (first.sub()[0].op() == .Literal ||
//             first.sub()[0].op() == .CharClass ||
//             first.sub()[0].op() == .AnyChar ||
//             first.sub()[0].op() == .AnyByte))) &&
//          Regexp_Node::Equal(first, first_i))
//        continue;
//    }

//    // Found end of a run with common leading regexp:
//    // sub[start:i] all begin with first,
//    // but sub[i] does not.
//    if (i == start) {
//      // Nothing to do - first iteration.
//    } else if (i == start+1) {
//      // Just one: don't bother factoring.
//    } else {
//      Regexp_Node* prefix = first.Incref();
//      for (int j = start; j < i; j++)
//        sub[j] = Regexp_Node::RemoveLeadingRegexp(sub[j]);
//      splices.emplace_back(prefix, sub + start, i - start);
//    }

//    // Prepare for next iteration (if there is one).
//    if (i < nsub) {
//      start = i;
//      first = first_i;
//    }
//  }
//}

//void FactorAlternationImpl::Round3(Regexp_Node** sub, int nsub,
//                                   Regexp_Node::ParseFlags flags,
//                                   std::vector<Splice>* splices) {
//  // Round 3: Merge runs of literals and/or character classes.
//  int start = 0;
//  Regexp_Node* first = null;
//  for (int i = 0; i <= nsub; i++) {
//    // Invariant: sub[start:i] consists of regexps that all
//    // are either literals (i.e. runes) or character classes.
//    Regexp_Node* first_i = null;
//    if (i < nsub) {
//      first_i = sub[i];
//      if (first != null &&
//          (first.op() == .Literal ||
//           first.op() == .CharClass) &&
//          (first_i.op() == .Literal ||
//           first_i.op() == .CharClass))
//        continue;
//    }

//    // Found end of a run of Literal/CharClass:
//    // sub[start:i] all are either one or the other,
//    // but sub[i] is not.
//    if (i == start) {
//      // Nothing to do - first iteration.
//    } else if (i == start+1) {
//      // Just one: don't bother factoring.
//    } else {
//      CharClassBuilder ccb;
//      for (int j = start; j < i; j++) {
//        Regexp_Node* re = sub[j];
//        if (re.op() == .CharClass) {
//          CharClass* cc = re.cc();
//          for (CharClass::iterator it = cc.begin(); it != cc.end(); ++it)
//            ccb.AddRange(it.lo, it.hi);
//        } else if (re.op() == .Literal) {
//          ccb.AddRangeFlags(re.rune(), re.rune(), re.parse_flags());
//        } else {
//          LOG(DFATAL) << "RE2: unexpected op: " << re.op() << " "
//                      << re.ToString();
//        }
//        re.Decref();
//      }
//      Regexp_Node* re = Regexp_Node::NewCharClass(ccb.GetCharClass(), flags);
//      splices.emplace_back(re, sub + start, i - start);
//    }

//    // Prepare for next iteration (if there is one).
//    if (i < nsub) {
//      start = i;
//      first = first_i;
//    }
//  }
//}

// Collapse the regexps on top of the stack, down to the
// first marker, into a new op node (op == .Alternate
// or op == .Concat).
do_collapse :: (using ps: *ParseState, op: RegexpOp) {
	// Scan backward to marker, counting children of composite.
	n := 0;
	next: *Regexp_Node;
	sub := stacktop;
	while sub != null && !is_marker(sub.op) {
		next = sub.down;
		if sub.op == op {
			n += sub.subs.count;
		}
		else {
			n += 1;
		}
		sub = next;
	}

	// If there's just one child, leave it alone.
	// (Concat of one thing is that one thing; alternate of one thing is same.)
	if stacktop != null && stacktop.down == next		return;

	// Construct op (alternation or concatenation), flattening op of op.
	subs: [..] *Regexp_Node;
	array_reserve(*subs, n);
	subs.count = n;
	next = null;
	i := n;
	sub = stacktop;
	while sub != null && !is_marker(sub.op) {
		next = sub.down;
		if sub.op == op {
			for < sub.subs {
				i -= 1;
				subs[i] = it;
			}
			sub.subs.count = 0;
			remove_regexp(*ps.pool, sub);
		} else {
			i -= 1;
			subs[i] = finish_regexp(sub);
		}
		sub = next;
	}
	assert(i == 0, "Sub expression count mismatch: %", i);

	// Takes ownership of subs
	re := new_concat_or_alternate(*ps.pool, op, subs, flags, true);
	re.simple = compute_simple(re);
	re.down = next;
	stacktop = re;
}

// Finishes the current concatenation,
// collapsing it into a single regexp on the stack.
do_concatenation :: (using ps: *ParseState) {
	r1 := stacktop;
	if r1 == null || is_marker(r1.op) {
		// empty concatenation is special case
		re := new_regexp(*ps.pool, .EmptyMatch, flags);
		push_regexp(ps, re);
	}
	do_collapse(ps, .Concat);
}

// Finishes the current alternation,
// collapsing it to a single regexp on the stack.
do_alternation :: (using ps: *ParseState) {
	do_vertical_bar(ps);
	// Now stack top is kVerticalBar.
	r1 := stacktop;
	stacktop = r1.down;
	remove_regexp(*ps.pool, r1);
	do_collapse(ps, .Alternate);
}

// Incremental conversion of concatenated literals into strings.
// If top two elements on stack are both literal or string,
// collapse into single string.
// Don't walk down the stack -- the parser calls this frequently
// enough that below the bottom two is known to be collapsed.
// Only called when another regexp is about to be pushed
// on the stack, so that the topmost literal is not being considered.
// (Otherwise ab* would turn into (ab)*.)
// If r >= 0, consider pushing a literal r on the stack.
// Return whether that happened.
maybe_concat_string :: (ps: *ParseState, r: Rune, flags: ParseFlags) -> bool {
	re1 := ps.stacktop;
	if re1 == null		 return false;
	re2 := re1.down;
	if re2 == null		 return false;

	if re1.op != .Literal && re1.op != .LiteralString	return false;
	if re2.op != .Literal && re2.op != .LiteralString	return false;
	if re1.parse_flags & .FoldCase != re2.parse_flags & .FoldCase		return false;

	if re2.op == .Literal {
		// convert into string
		rune := re2.rune;
		re2.op = .LiteralString;
		re2.runes.count = 0;
		re2.runes.data = null;
		add_rune_to_string(re2, rune);
	}

	// push re1 into re2.
	if (re1.op == .Literal) {
		add_rune_to_string(re2, re1.rune);
	} else {
		for re1.runes {
			add_rune_to_string(re2, it);
		}
		array_free(re1.runes);
	}

	// reuse re1 if possible
	if r >= 0 {
		re1.op = .Literal;
		re1.rune = r;
		re1.parse_flags = flags;
		return true;
	}

	ps.stacktop = re2;
	remove_regexp(*ps.pool, re1);
	return false;
}

add_rune_to_string :: (re: *Regexp_Node, r: Rune) {
	assert(re.op == .LiteralString);
	if re.runes.count == 0 {
		array_reserve(*re.runes, 8);
	}
	array_add(*re.runes, r);
}

// Lexing routines.

// Parses a decimal integer, storing it in *np.
// Sets *s to span the remainder of the string.
parse_integer :: (s: *string) -> int, success: bool {
	if !s.count || !isdigit((<<s)[0])		return 0, false;

	// Disallow leading zeros.
	if s.count >= 2 && (<<s)[0] == #char "0" && isdigit((<<s)[1])	return 0, false;

	n := 0;
	while s.count && isdigit((<<s)[0]) {
		c := (<<s)[0];
		// Avoid overflow.
		if n >= 100000000	return 0, false;
		n = n*10 + c - #char "0";
		advance(s);
	}
	return n, true;
}

// Parses a repetition suffix like {1,2} or {2} or {2,}.
// Sets *s to span the remainder of the string on success.
// Sets *lo and *hi to the given range.
// In the case of {2,}, the high number is unbounded;
// sets *hi to -1 to signify this.
// {,2} is NOT a valid suffix.
// The Maybe in the name signifies that the regexp parse
// doesn't fail even if ParseRepetition does, so the StringPiece
// s must NOT be edited unless MaybeParseRepetition returns true.
maybe_parse_repetition :: (sp: *string) -> lo: int, hi: int, success: bool {
	s := <<sp;
	if !s.count || s[0] != #char "{"	 return 0, 0, false;

	advance(*s);

	lo, success, remainder := to_integer(s);
	if !success		return 0, 0, false;
	if !remainder	return 0, 0, false;
	s = remainder;

	hi: int;
	if s[0] == #char "," {
		advance(*s); // ','
		if !s	return 0, 0, false;

		if s[0] == #char "}" {
			// {2,} means at least 2
			hi = -1;
		} else {
			// {2,4} means 2, 3, or 4.
			hi, success, remainder = to_integer(s);
			if !success		return 0, 0, false;
			s = remainder;
		}
	} else {
		// {2} means exactly two
		hi = lo;
	}
	if !s.count || s[0] != #char "}"	return 0, 0, false;
	advance(*s);
	<<sp = s;

	return lo, hi, true;
}

// @ToDo: Move to unicode module?
consume_rune :: (str: *string) -> Rune, len: int, status: Status {
	result, len := rune_from_string(<<str);
	if !len		return 0, 0, make_status(.BadUTF8);

	advance(str, len);
	return result, len, .{};
}

// @Speed:: Using my own unicode#is_valid_utf8 would probably be faster
is_valid_utf8 :: (str: string) -> bool, status: Status {
	t := str;
	while t {
		result, len, status := consume_rune(*t);
		if !len		return false, status;
	}
	return true, .{};
}

// Convert hex digit to value.
hex_value :: (c: Rune) -> int, success: bool {
	if #char "0" <= c && c <= #char "9"		return c - #char "0", true;
	if #char "A" <= c && c <= #char "F"		return c - #char "A" + 10, true;
	if #char "a" <= c && c <= #char "f"		return c - #char "a" + 10, true;

	return 0, false;
}

// Parse an escape sequence (e.g., \n, \{).
// Sets *s to span the remainder of the string.
// Sets *rp to the named character.
parse_escape :: (s: *string, rune_max: s32) -> r: Rune, status: Status, success: bool {
	bad_escape :: (begin: string, s: *string) -> Status {
		status: Status;
		status.code = .BadEscape;
		status.error_arg = slice(begin, 0, begin.count - s.count);
		return status;
	}

	assert(s.count && (<<s)[0] == #char "\\");

	if s.count == 1 {
		return 0, make_status(.TrailingBackslash), false;
	}

	begin := <<s;

	advance(s); // backslash

	c, len, status := consume_rune(s);
	if !len		return 0, status, false;

	if c == {
		case;
			if c < Runeself && !isalpha(c) && !isdigit(c) {
				// Escaped non-word characters are always themselves.
				// PCRE is not quite so rigorous: it accepts things like
				// \q, but we don't.  We once rejected \_, but too many
				// programs and people insist on using it, so allow \_.
				return c, status, true;
			}
			return 0, bad_escape(begin, s), false;

		// Octal escapes.
		case #char "1"; #through;
		case #char "2"; #through;
		case #char "3"; #through;
		case #char "4"; #through;
		case #char "5"; #through;
		case #char "6"; #through;
		case #char "7";
			// Single non-zero octal digit is a backreference; not supported.
			if !s.count || (<<s)[0] < #char "0" || (<<s)[0] > #char "7"	 return 0, bad_escape(begin, s), false;
			#through;
		case #char "0";
			// consume up to three octal digits; already have one.
			code := c - #char "0";
			if !s.count		return 0, bad_escape(begin, s), false;
			c = (<<s)[0];
			if #char "0" <= c && c <= #char "7" {
				code = code * 8 + c - #char "0";
				advance(s); // digit
				if s {
					c = (<<s)[0];
					if #char "0" <= c && c <= #char "7" {
						code = code * 8 + c - #char "0";
						advance(s); // digit
					}
				}
			}
			if code > rune_max		return 0, bad_escape(begin, s), false;

			return code, status, true;

		// Hexadecimal escapes
		case #char "x";
			if !s.count	 return 0, bad_escape(begin, s), false;
			len: int;
			c, len, status = consume_rune(s);
			if !len		return 0, status, false;
			if c == #char "{" {
				// Any number of digits in braces.
				// Update n as we consume the string, so that
				// the whole thing gets shown in the error message.
				// Perl accepts any text at all; it ignores all text
				// after the first non-hex digit.  We require only hex digits,
				// and at least one.
				c, len, status = consume_rune(s);
				if !len		return 0, status, false;

				nhex := 0;
				code: Rune;
				hval, success := hex_value(c);
				while success {
					nhex += 1;
					code = cast(Rune)(code * 16 + hval);
					if code > rune_max		return 0, bad_escape(begin, s), false;
					if !s.count				return 0, bad_escape(begin, s), false;
					c, len, status = consume_rune(s);
					if !len		return 0, status, false;
					hval, success = hex_value(c);
				}
				if c != #char "}" || nhex == 0		return 0, bad_escape(begin, s), false;
				return code, status, true;
			} else {
				// Easy case: two hex digits.
				if !s.count		return 0, bad_escape(begin, s), false;
				c1, len, status := consume_rune(s);
				if !len			return 0, status, false;
				hc0, success0 := hex_value(c);
				hc1, success1 := hex_value(c);
				if !success0 || success1	return 0, bad_escape(begin, s), false;
				return cast(Rune)(hc0 * 16 + hc1), status, true;
			}

		// C escapes.
		case #char "n";
			return #char "\n", status, true;
		case #char "r";
			return #char "\r", status, true;
		case #char "t";
			return #char "\t", status, true;

		// Less common C escapes.
		// @ToDO: Implement?
		case #char "a";
			// return #char "\a", status, true;
			return 0, bad_escape(begin, s), false;
		case #char "f";
			// return #char "\f", status, true;
			return 0, bad_escape(begin, s), false;
		case #char "v";
			// return #char "\v", status, true;
			return 0, bad_escape(begin, s), false;

		// This code is disabled to avoid misparsing
		// the Perl word-boundary \b as a backspace
		// when in POSIX regexp mode.  Surprisingly,
		// in Perl, \b means word-boundary but [\b]
		// means backspace.  We don't support that:
		// if you want a backspace embed a literal
		// backspace character or use \x08.
		//
		// case #char "b";
		//   *rp = #char "\b";
		//   return true;
	}
}

// Add a range to the character class, but exclude newline if asked.
// Also handle case folding.
add_range_flags :: (using char_class: *CharClass, lo: Rune, hi: Rune, parse_flags: ParseFlags) {
	// Take out \n if the flags say so.
	cutnl := !(parse_flags & .ClassNL) || (parse_flags & .NeverNL);
	if cutnl && lo <= #char "\n" && #char "\n" <= hi {
		if lo < #char "\n" {
			add_range_flags(char_class, lo, #char "\n" - 1, parse_flags);
		}
		if hi > #char "\n" {
			add_range_flags(char_class, #char "\n" + 1, hi, parse_flags);
		}
		return;
	}

	// If folding case, add fold-equivalent characters too.
	if parse_flags & .FoldCase {
		add_folded_range(char_class, lo, hi, 0);
	} else {
		add_range(char_class, lo, hi);
	}
}

// Look for a group with the given name.
lookup_group :: (name: string, groups: [] UGroup) -> *UGroup {
	for * groups {
		if it.name == name	return it;
	}
	return null;
}

// Look for a POSIX group with the given name (e.g., "[:^alpha:]")
lookup_posix_group :: (name: string) -> *UGroup {
	return lookup_group(name, posix_groups);
}
lookup_perl_group :: (name: string) -> *UGroup {
	return lookup_group(name, perl_groups);
}

#if true {
	// Fake UGroup containing all Runes
	any16 :: URange16.{0, 65535};
	any32 :: URange32.{65535, Runemax};
	any16array :: URange16.[any16];
	any32array :: URange32.[any32];
	anygroup :: UGroup.{"Any", 1, any16array, any32array};

	// Look for a Unicode group with the given name (e.g., "Han")
	lookup_unicode_group :: (name: string) -> *UGroup {
		if name == "any" {
			return *anygroup;
		}
		return lookup_group(name, unicode_groups);
	}
}

// Add a UGroup or its negation to the character class.
// @ToDo: Why is sign not a boolean?
add_unicode_group :: (cc: *CharClass, g: *UGroup, sign: int, parse_flags: ParseFlags) {
	if (sign == +1) {
		for g.r16	add_range_flags(cc, it.lo, it.hi, parse_flags);
		for g.r32	add_range_flags(cc, it.lo, it.hi, parse_flags);
	} else {
		if parse_flags & .FoldCase {
			// Normally adding a case-folded group means
			// adding all the extra fold-equivalent runes too.
			// But if we're adding the negation of the group,
			// we have to exclude all the runes that are fold-equivalent
			// to what's already missing.  Too hard, so do in two steps.
			char_class1: CharClass;
			// @ToDo: Cleanup char_class1
			add_unicode_group(*char_class1, g, 1, parse_flags);
			// If the flags say to take out \n, put it in, so that negating will take it out.
			// Normally AddRangeFlags does this, but we're bypassing AddRangeFlags.
			cutnl := !(parse_flags & .ClassNL) || (parse_flags & .NeverNL);
			if cutnl {
				add_range(*char_class1, #char "\n", #char "\n");
			}
			negate(*char_class1);
			add_char_class(cc, char_class1);
			return;
		} else {
			next: Rune;
			for g.r16 {
				if next < it.lo {
					add_range_flags(cc, next, it.lo - 1, parse_flags);
				}
				next = it.hi + 1;
			}
			for g.r32 {
				if next < it.lo {
					add_range_flags(cc, next, it.lo - 1, parse_flags);
				}
				next = it.hi + 1;
			}
			if next <= Runemax {
				add_range_flags(cc, next, Runemax, parse_flags);
			}
		}
	}
}

// Maybe parse a Perl character class escape sequence.
// Only recognizes the Perl character classes (\d \s \w \D \S \W),
// not the Perl empty-string classes (\b \B \A \Z \z).
// On success, sets *s to span the remainder of the string
// and returns the corresponding UGroup.
// The StringPiece must *NOT* be edited unless the call succeeds.
maybe_parse_perl_cc_escape :: (s: *string, parse_flags: ParseFlags) -> *UGroup #must {
	if !(parse_flags & .PerlClasses)	return null;
	if s.count < 2 || (<<s)[0] != #char "\\"		return null;

	// Could use StringPieceToRune, but there aren't
	// any non-ASCII Perl group names.
	name := slice(<<s, 0, 2);
	g := lookup_perl_group(name);
	if g == null		return null;
	advance(s, name.count);
	return g;
}

ParseResult :: enum {
	// @ToDo: Rename those
	kParseOk;  // Did some parsing.
	kParseError;  // Found an error.
	kParseNothing;  // Decided not to parse.
};

// Maybe parses a Unicode character group like \p{Han} or \P{Han}
// (the latter is a negated group).
maybe_parse_unicode_group :: (s: *string, parse_flags: ParseFlags, cc: *CharClass) -> status: Status, result: ParseResult {
	status: Status;
	// Decide whether to parse.
	if !(parse_flags & .UnicodeGroups)	return status, .kParseNothing;
	if s.count < 2 || (<<s)[0] != #char "\\"  return status, .kParseNothing;

	c: Rune = (<<s)[1];
	if c != #char "p" && c != #char "P"		return status, .kParseNothing;

	// Committed to parse.  Results:
	sign: int = 1;  // -1 = negated char class
	if (c == #char "P")	{
		sign = -sign;
	}
	seq := <<s; // \p{Han} or \pL
	name: string;  // Han or L
	advance(s, 2);  // '\\', 'p'


	if (<<s)[0] != #char "{" {
		status: Status;
		len: int;
		c, len, status = consume_rune(s);
		if !len		return status, .kParseError;

		// Name is just the single rune we just parsed
		name = slice(seq, 2, len);
	} else {
		// Name is in braces. Look for closing }
		end := find_index_from_left(<<s, #char "}");
		if end != -1 {
			valid: bool;
			valid, status = is_valid_utf8(seq);
			if !valid		return status, .kParseError;

			return make_status(.BadCharRange, seq), .kParseError;
		}
		name = slice(<<s, 1, end - 1); // without '}'
		advance(s, end + 1);
		valid: bool;
		valid, status = is_valid_utf8(name);
		if !valid		return status, .kParseError;
	}

	// Chop seq where s now begins.
	seq.count = seq.count - s.count;

	if name && name[0] == #char "^" {
		sign = -sign;
		advance(*name);  // '^'
	}

	#if true {
		// Look up the group in the RE2 Unicode data.
		g := lookup_unicode_group(name);
		if g == null {
			status.code = .BadCharRange;
			status.error_arg = seq;
			return status, .kParseError;
		}

		add_unicode_group(cc, g, sign, parse_flags);
	} else {
		// // Look up the group in the ICU Unicode data. Because ICU provides full
		// // Unicode properties support, this could be more than a lookup by name.
		// ::icu::UnicodeString ustr = ::icu::UnicodeString::fromUTF8(
		// 	std::string("\\p{") + std::string(name) + std::string("}"));
		// 	UErrorCode uerr = U_ZERO_ERROR;
		// 	::icu::UnicodeSet uset(ustr, uerr);
		// 	if (U_FAILURE(uerr)) {
		// 		status.set_code(.BadCharRange);
		// 		status.set_error_arg(seq);
		// 		return .kParseError;
		// 	}

		// 	// Convert the UnicodeSet to a URange32 and UGroup that we can add.
		// 	int nr = uset.getRangeCount();
		// 	PODArray<URange32> r(nr);
		// 	for (int i = 0; i < nr; i++) {
		// 		r[i].lo = uset.getRangeStart(i);
		// 		r[i].hi = uset.getRangeEnd(i);
		// 	}
		// 	UGroup g = {"", +1, 0, 0, r.data(), nr};
		// 	AddUGroup(cc, &g, sign, parse_flags);
	}

	return status, .kParseOk;
}

// Parses a character class name like [:alnum:].
// Sets *s to span the remainder of the string.
// Adds the ranges corresponding to the class to ranges.
parse_cc_name :: (s: *string, parse_flags: ParseFlags, cc: *CharClass) -> status: Status, result: ParseResult {
	// Check begins with [:
	if s.count < 2	|| (<<s)[0] != #char "[" || (<<s)[1] != #char ":"		return Status.{}, .kParseNothing;

	// Look for closing :].
	end := find_index_from_left(<<s, ":]");

	// If no closing :], then ignore.
	if !end		return Status.{}, .kParseNothing;

	// Got it.  Check that it's valid.
	name := slice(<<s, 2, end - 2);
	g := lookup_posix_group(name);
	if (g == null) {
		return make_status(.BadCharRange, name), .kParseError;
	}

	advance(s, name.count + 4);
	add_unicode_group(cc, g, g.sign, parse_flags);
	return Status.{}, .kParseOk;
}

// Parses a character inside a character class.
// There are fewer special characters here than in the rest of the regexp.
// Sets *s to span the remainder of the string.
parse_cc_character :: (using ps: *ParseState, s: *string, whole_class: string) -> rune: Rune, status: Status, success: bool {
	if !s 	return 0, make_status(.MissingBracket, whole_class), false;

	// Allow regular escape sequences even though
	// many need not be escaped in this context.
	if (<<s)[0] == #char "\\" {
		rune, status, success := parse_escape(s, rune_max);
		return rune, status, success;
	} else {
		// Otherwise take the next rune.
		rune, len, status := consume_rune(s);
		return rune, status, len > 0;
	}
}

// Parses a character class character, or, if the character
// is followed by a hyphen, parses a character class range.
// For single characters, rr.lo == rr.hi.
// Sets *s to span the remainder of the string.
parse_cc_range :: (using ps: *ParseState, s: *string, whole_class: string) -> RuneRange, status: Status, success: bool {
	os := <<s;
	rr: RuneRange;
	success: bool;
	rr.lo, status, success = parse_cc_character(ps, s, whole_class);
	if !success		return rr, status, false;

	// [a-] means (a|-), so check for final ].
	if s.count >= 2 && (<<s)[0] == #char "-" && (<<s)[1] != #char "]" {
		advance(s);  // #char "-"

		rr.hi, status, success = parse_cc_character(ps, s, whole_class);
		if !success		return rr, status, false;

		if rr.hi < rr.lo {
			return rr, make_status(.BadCharRange, slice(os, 0, os.count - s.count)), false;
		}
	} else {
		rr.hi = rr.lo;
	}
	return rr, status, true;
}

// Parses a possibly-negated character class expression like [^abx-z[:digit:]].
// Sets *s to span the remainder of the string.
// Sets *out_re to the regexp for the class.
parse_char_class :: (using ps: *ParseState, s: *string) -> *Regexp_Node, status: Status, success: bool {
	whole_class := <<s;
	// Caller checked this.
	assert(s.count && (<<s)[0] == #char "[");

	negated: bool;
	re := new_regexp(*ps.pool, .CharClass, flags & ~.FoldCase);
	re.char_class = New(CharClass);
	re.char_class_finished = false;
	advance(s);  // '['
	if s.count && (<<s)[0] == #char "^" {
		advance(s); // '^'
		negated = true;
		if !(flags & .ClassNL) || flags & .NeverNL {
			// If NL can't match implicitly, then pretend
			// negated classes include a leading \n.
			add_range(re.char_class, #char "\n", #char "\n");
		}
	}
	first := true;  // ] is okay as first char in class
	while s.count && (first || (<<s)[0] != #char "]") {
		// - is only okay unescaped as first or last in class.
		// Except that Perl allows - anywhere.
		if !first && (<<s)[0] == #char "-" && !(flags & .PerlX) && (s.count == 1 || (<<s)[1] != #char "]") {
			remove_regexp(*ps.pool, re);

			t := <<s;
			advance(*t);  // '-'
			r, n, status := consume_rune(*t);
			if !n {
				return null, status, false;
			}

			return null, make_status(.BadCharRange, slice(<<s, 0, 1 + n)), false;
		}
		first = false;

		// Look for [:alnum:] etc.
		if s.count > 2 && (<<s)[0] == #char "[" && (<<s)[1] == #char ":" {
			status, result := parse_cc_name(s, flags, re.char_class);
			if #complete result == {
				case .kParseOk;
					continue;
				case .kParseError;
					remove_regexp(*ps.pool, re);
					return null, status, false;
				case .kParseNothing;
			}
		}

		// Look for Unicode character group like \p{Han}
		if s.count > 2 && (<<s)[0] == #char "\\" && ((<<s)[1] == #char "p" || (<<s)[1] == #char "P") {
			status, result := maybe_parse_unicode_group(s, flags, re.char_class);
			if #complete result == {
				case .kParseOk;
					continue;
				case .kParseError;
					remove_regexp(*ps.pool, re);
					return null, status, false;
				case .kParseNothing;
			}
		}

		// Look for Perl character class symbols (extension).
		g := maybe_parse_perl_cc_escape(s, flags);
		if g != null {
			add_unicode_group(re.char_class, g, g.sign, flags);
			continue;
		}

		// Otherwise assume single character or simple range.
		rr, status, success := parse_cc_range(ps, s, whole_class);
		if !success {
			remove_regexp(*ps.pool, re);
			return null, status, false;
		}

		// AddRangeFlags is usually called in response to a class like
		// \p{Foo} or [[:foo:]]; for those, it filters \n out unless
		// Regexp_Node::ClassNL is set.  In an explicit range or singleton
		// like we just parsed, we do not filter \n out, so set ClassNL
		// in the flags.
		add_range_flags(re.char_class, rr.lo, rr.hi, flags | .ClassNL);
	}

	if !s.count {
		remove_regexp(*ps.pool, re);
		return null, make_status(.MissingBracket, whole_class), false;
	}
	advance(s);  // ']'

	if negated {
		negate(re.char_class);
	}

	return re, .{}, true;
}

// Is this a valid capture name?  [A-Za-z0-9_]+
// PCRE limits names to 32 bytes.
// Python rejects names starting with digits.
// We don't enforce either of those.
is_valid_capture_name :: (name: string) -> bool {
  if !name	return false;
  for 0..name.count - 1 {
	  c := name[it];
	  if !((#char "0" <= c && c <= #char "9") ||
			  (#char "a" <= c && c <= #char "z") ||
			  (#char "A" <= c && c <= #char "Z") ||
			  c == #char "_")
		  return false;
  }
  return true;
}

// Parses a Perl flag setting or non-capturing group or both,
// like (?i) or (?: or (?i:.  Removes from s, updates parse state.
// The caller must check that s begins with "(?".
// Returns true on success.  If the Perl flag is not
// well-formed or not supported, sets status and returns false.
parse_perl_flags :: (using ps: *ParseState, s: *string) -> Status, success: bool {
	// Caller is supposed to check this.
	assert(flags & .PerlX && s.count >= 2 && (<<s)[0] == #char "(" && (<<s)[1] == #char "?");

	t := <<s;
	advance(*t, 2); // "(?"

	// Check for named captures, first introduced in Python's regexp library.
	// As usual, there are three slightly different syntaxes:
	//
	//   (?P<name>expr)   the original, introduced by Python
	//   (?<name>expr)    the .NET alteration, adopted by Perl 5.10
	//   (?'name'expr)    another .NET alteration, adopted by Perl 5.10
	//
	// Perl 5.10 gave in and implemented the Python version too,
	// but they claim that the last two are the preferred forms.
	// PCRE and languages based on it (specifically, PHP and Ruby)
	// support all three as well.  EcmaScript 4 uses only the Python form.
	//
	// In both the open source world (via Code Search) and the
	// Google source tree, (?P<expr>name) is the dominant form,
	// so that's the one we implement.  One is enough.
	if (t.count > 2 && t[0] == #char "P" && t[1] == #char "<") {
		advance(*t, 2);
		// Pull out name.
		end := find_index_from_left(t, #char ">");
		if end == -1 {
			valid, status := is_valid_utf8(<<s);
			if !valid		return status, false;
			return make_status(.BadNamedCapture, <<s), false;
		}

		// t is "name>...", t[end] == '>'
		capture := slice(<<s, 2, end + 3);
		name := slice(t, 0, end);
		valid, status := is_valid_utf8(name);
		if !valid		return status, false;

		if !is_valid_capture_name(name)		return make_status(.BadNamedCapture, capture), false;

		do_left_paren(ps, name);

		advance(s, capture.count + 2);
		return status, true;
	}

	negated: bool;
	sawflags: bool;
	nflags := flags;
	done: bool;
	while !done {
		if !t.count		return make_status(.BadPerlOp, <<s), false;
		c, len, status :=  consume_rune(*t);
		if !len		return status, false;
		if c == {
			case;
				return make_status(.BadPerlOp, slice(<<s, 0, s.count - t.count)), false;
			// Parse flags.
			case #char "i";
				sawflags = true;
				if negated {
					nflags &= ~.FoldCase;
				} else {
					nflags |= .FoldCase;
				}

			case #char "m";  // opposite of our OneLine
				sawflags = true;
				if negated {
					nflags |= .OneLine;
				} else {
					nflags &= ~.OneLine;
				}

			case #char "s";
				sawflags = true;
				if negated {
					nflags &= ~.DotNL;
				} else {
					nflags |= .DotNL;
				}

			case #char "U";
				sawflags = true;
				if negated {
					nflags &= ~.NonGreedy;
				} else {
					nflags |= .NonGreedy;
				}

			// Negation
			case #char "-";
				if negated		return make_status(.BadPerlOp, slice(<<s, 0, s.count - t.count)), false;

				negated = true;
				sawflags = false;

			// Open new group.
			case #char ":";
				do_left_paren_no_capture(ps);
				done = true;

			// Finish flags.
			case #char ")";
				done = true;
		}
	}

	if negated && !sawflags		return make_status(.BadPerlOp, slice(<<s, 0, s.count - t.count)), false;

	flags = nflags;
	<<s = t;
	return .{}, true;
}

// // Converts latin1 (assumed to be encoded as Latin1 bytes)
// // into UTF8 encoding in string.
// // Can't use EncodingUtils::EncodeLatin1AsUTF8 because it is
// // deprecated and because it rejects code points 0x80-0x9F.
// void ConvertLatin1ToUTF8(const StringPiece& latin1, std::string* utf) {
//   char buf[UTFmax];

//   utf.clear();
//   for (size_t i = 0; i < latin1.size(); i++) {
//     Rune r = latin1[i] & 0xFF;
//     int n = runetochar(buf, &r);
//     utf.append(buf, n);
//   }
// }

// Actually C library functions, but it feels stupid to call out to libc for that
isalpha :: (c: s32) -> bool {
    return (c >= #char "A" && c <= #char "Z") || (c >= #char "a" && c <= #char "z");
}
isdigit :: (c: s32) -> bool {
    return c >= #char "0" && c <= #char "9";
}


// For to_string
Precedence :: enum {
	Atom;
	Unary;
	Concat;
	Alternate;
	Empty;
	Paren;
	Toplevel;
}

#import "Basic";
#import "String";
#import "Bucket_Array";
#import "Pool";
