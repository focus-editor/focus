// This currently serves only one task - highlighting words in comments.
// Therefore it takes in and outputs words with tokens attached to them.
// If we ever need this for anything else then it will be a good time to make it a little more generic


// TODO: these names could be better

Highlight_Word :: struct {
    word: string;
    token_type: Token_Type;
}

Found_Highlight_Word :: struct {
    offset: s32;
    len: s32;
    token_type: Token_Type;
}


build_aho_corasick_automaton :: (words: [] Highlight_Word) -> Aho_Corasick_Automaton {
    using automaton: Aho_Corasick_Automaton;

    push_allocator(Allocator.{ proc = flat_pool_allocator_proc, data = *memory_pool });

    insert_words(*automaton, words);
    build_failure_links(*automaton);
    cleanup(*automaton);

    return automaton;
}

free :: (using automaton: *Aho_Corasick_Automaton) {
    array_reset(*nodes);
    array_reset(*raw_nodes);
    reset(*memory_pool);
}

find_whole_words :: (using automaton: *Aho_Corasick_Automaton, text: string) -> found_words: [] Found_Highlight_Word /* temp */ {
    found_words: [..] Found_Highlight_Word;
    found_words.allocator = temp;

    state: s32 = 0;

    s := text;
    while s {
        char, result := utf8_next_character(*s);
        if result != .CONVERSION_OK continue;

        // Transition to the next state
        node  := *nodes[state];
        found := false;
        for node.children {
            if it.char == char { state = it.node_index; found = true; break; }
        }

        if found {
            node := *nodes[state];
            for node.output_words {
                result := Found_Highlight_Word.{
                    offset = cast(s32) (s.data - text.data - it.word.count),
                    len = cast(s32) it.word.count,
                    token_type = it.token_type,
                };
                if is_whole_word(text, result.offset, result.len) {
                    array_add(*found_words, result);
                }
            }
        } else {
            state = node.failure_link;
        }
    }

    return found_words;
}

Aho_Corasick_Automaton :: struct {
    nodes: [] Node;
    raw_nodes: [..] RawNode;  // used only when building

    memory_pool: Flat_Pool;  // TODO: use the pool
}

#scope_file

simulate_raw :: (using automaton: *Aho_Corasick_Automaton, chars: [] u32, start_state: s32 = 0) -> end_state: s32 {
    state := start_state;

    for char : chars {
        node  := *raw_nodes[state];
        found := false;
        for node.children {
            if it.char == char { state = it.node_index; found = true; break; }
        }
        if !found then state = node.failure_link;
    }

    return state;
}

insert_words :: (using automaton: *Aho_Corasick_Automaton, words: [] Highlight_Word) {
    if !raw_nodes then array_add(*raw_nodes, .{});  // add a root node

    for words {
        // Convert the word to a char array
        chars: [..] u32;
        s := it.word;
        while s {
            char, result := utf8_next_character(*s);
            if result != .CONVERSION_OK { log_error("Invalid UTF8 in word '%' when trying to insert it to Aho-Corasick automaton", it.word); continue; }
            array_add(*chars, char);
        }

        // Add nodes to the trie
        node_index: s32 = 0;
        for i : 0 .. chars.count - 1 {
            char   := chars[i];
            prefix := array_view(chars, 0, i + 1);
            node_index = get_or_create_child(automaton, node_index, char, prefix);
        }

        add_word_if_unique(*raw_nodes[node_index].output_words, it);
    }
}

build_failure_links :: (using automaton: *Aho_Corasick_Automaton) {
    q: Fifo_Queue(s32);
    enqueue(*q, 0);  // root
    while true {
        success, node_index := dequeue(*q);
        if !success break;

        node := *raw_nodes[node_index];
        for node.children  enqueue(*q, it.node_index);

        // TODO: use parent's failure link
        prefix := node.prefix;
        if prefix { prefix.data += 1; prefix.count -= 1; }  // remove the first char
        node.failure_link = simulate_raw(automaton, prefix, start_state = 0);
        failure_node := *raw_nodes[node.failure_link];
        for failure_node.output_words  add_word_if_unique(*node.output_words, it);
    }
}

get_or_create_child :: (using automaton: *Aho_Corasick_Automaton, node_index: s32, char: u32, prefix: [] u32) -> next_node_index: s32 {
    // Search among existing children
    node := *raw_nodes[node_index];
    for node.children {
        if it.char == char  return it.node_index;
    }

    // Create a new node
    new_node_index := cast(s32) raw_nodes.count;
    array_add(*node.children, Child.{ char = char, node_index = new_node_index });
    array_add(*raw_nodes, .{ parent = node_index, prefix = prefix });

    return new_node_index;
}

cleanup :: (using automaton: *Aho_Corasick_Automaton) {
    nodes = NewArray(raw_nodes.count, Node, initialized = false);
    for raw_node : raw_nodes {
        node := *nodes[it_index];
        node.children     = raw_node.children;
        node.output_words = raw_node.output_words;
        node.failure_link = raw_node.failure_link;

        quick_sort(node.output_words, (a, b) => (b.word.count - a.word.count));  // sort by longest first
    }
}

add_word_if_unique :: (words: *[..] Highlight_Word, item: Highlight_Word) {
    for words.*  if it.word == item.word return;
    array_add(words, item);
}

// Used for searching - compact for better cache utilisation
Node :: struct {
    children: [] Child;
    output_words: [] Highlight_Word;
    failure_link: s32;
}

// Used for building the trie and the failure links
RawNode :: struct {
    parent: s32 = -1;
    failure_link: s32 = 0;
    prefix: [] u32;
    children:     [..] Child;
    output_words: [..] Highlight_Word;
}

Child :: struct {
    char: u32;
    node_index: s32;
}

