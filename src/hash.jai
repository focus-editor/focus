#if CPU == .X64 {
    // NOTE: calculates only 64 bits
    calculate_meow_hash :: (bytes: [] u8) -> u64 {
        #asm { hash: vec; }

        MH.MeowHash(MH.MeowDefaultSeed, xx bytes.count, bytes.data, hash);

        return MH.MeowU64From(hash, 0);
    }
} else {
    calculate_meow_hash :: (bytes: [] u8) -> u64 {
        return fallback_hash(bytes);
    }
}

fallback_hash :: (bytes: [] u8) -> u64 {
    return Hash.get_hash(bytes);
}


// To be used as a replacement of the standard hash for paths to avoid allocations and copying
get_platform_path_hash :: (s: string) -> u32 {
    #if OS == .WINDOWS {
        // TODO: support non-ASCII paths later
        return cast,trunc(u32) inline fnv1a_hash_lowercase(s.data, s.count, HASH_INIT);
    } else {
        // Unix systems use case-sensitive paths
        return inline Hash.get_hash(s, HASH_INIT);
    }
}


#scope_file


fnv1a_hash_lowercase :: (data: *void, size: int, h := Hash.FNV_64_OFFSET_BIAS) -> u64 {
    for 0..size-1 #no_abc #no_aoc {
        h = Hash.fnv1a_hash(inline to_lower((cast(*u8)data)[it]), h);
    }

    return h;
}


HASH_INIT : u32 : 5381;

MH :: #import "meow_hash";

