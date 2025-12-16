#scope_module

Walk_State :: struct (T: Type) {
	re: *Regexp_Node;
	n := -1;
	parent_arg: T;
	pre_arg: T;
	child_args: [..] T;
}

walk_state :: (re: *Regexp_Node, parent_arg: $T) -> Walk_State(T) {
	s: Walk_State(T);
	s.re = re;
	s.parent_arg = parent_arg;
	s.child_args.allocator = __temporary_allocator;
	return s;
}

Walk :: struct (C: Type, T: Type) {
	pre_visit := no_pre;
	post_visit := no_post;
	short_visit := no_short;
	copy := no_copy;
	max_visits := 1000000;

	//ToDo: Use [] T as child_args
	no_post :: (ctx: C, re: *Regexp_Node, parent_arg: T, pre_arg: T, child_args: [..] T) -> T {
		return parent_arg;
	}

	no_pre :: (ctx: C, re: *Regexp_Node, parent_arg: T) -> T, bool {
		return parent_arg, false;
	}

	no_short :: (ctx: C, re: *Regexp_Node, parent_arg: T) -> T {
		return parent_arg;
	}

	no_copy :: (ctx: C, arg: T) -> T {
		return arg;
	}
}

walk :: (ctx: C, re: *Regexp_Node, initial_value: T, w: Walk($C, $T)) -> T, stopped_early: bool {
	do_visit :: (ctx: C, stack: *[..] Walk_State(T), w: *Walk(C, T)) -> T, stopped_early: bool, done: bool {
		s := *(stack.*)[stack.count - 1];
		if s.n == -1 {
			w.max_visits -= 1;
			if (w.max_visits < 0) {
				return w.short_visit(ctx, s.re, s.parent_arg), true, true;
			}

			stop: bool;
			s.pre_arg, stop = w.pre_visit(ctx, s.re, s.parent_arg);
			if (stop) {
				return s.pre_arg, false, true;
			}

			array_resize(*s.child_args, s.re.subs.count, false);
			s.n = 0;
		}

		if (s.re.subs.count > 0) {
			if (s.n < s.re.subs.count) {
				if (w.copy && s.n > 0 && s.re.subs[s.n - 1] == s.re.subs[s.n]) {
					s.child_args[s.n] = w.copy(ctx, s.child_args[s.n - 1]);
					s.n += 1;
				} else {
					array_add(stack, walk_state(s.re.subs[s.n], s.pre_arg));
				}
				t: T;
				return t, false, false;
			}
		}

		return w.post_visit(ctx, s.re, s.parent_arg, s.pre_arg, s.child_args), false, true;
	}
	assert(re != null, "Missing regexp");

	stack: [..] Walk_State(T);
	stack.allocator = __temporary_allocator;
	array_add(*stack, walk_state(re, initial_value));
	stopped_early := false;

	while true {
		t, early, done := do_visit(ctx, *stack, *w);
		if early {
			stopped_early = true;
		}

		if done {
			// We've finished stack.top().
			// Update next guy down.
			pop(*stack);
			if !stack.count		return t, stopped_early;
			s := *stack[stack.count - 1];
			if s.child_args.count {
				s.child_args[s.n] = t;
			}
			s.n += 1;
		}
	}

	// This will never be reached, but Jai complains otherwise
	// @Cleanup: remove this once Jai is fixed
	t: T;
	return t, true;
}

