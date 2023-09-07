Anchor :: enum {
	UNANCHORED;         // No anchoring
	ANCHOR_START;       // Anchor at start only
	ANCHOR_BOTH; // Anchor at start and end
}

// See comile.jai and match.jai for details

#scope_module

REGEXP_DEBUG :: false;

#scope_file

#load "char_class.jai";
#load "compile.jai";
#load "match.jai";
#load "nfa.jai";
#load "parse.jai";
#load "program.jai";
#load "rune.jai";
#load "simplify.jai";
#load "sparse.jai";
#load "unicode_casefold.jai";
#load "unicode_group.jai";
#load "walk.jai";
