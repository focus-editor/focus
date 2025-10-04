#if CPU == .X64 {
    // NOTE: calculates only 64 bits
    calculate_meow_hash :: (bytes: [] u8) -> u64 {
        #asm { hash: vec; }

        MeowHash(MeowDefaultSeed, xx bytes.count, bytes.data, hash);

        return MeowU64From(hash, 0);
    }
} else {
    calculate_meow_hash :: (bytes: [] u8) -> u64 {
        return fallback_hash(bytes);
    }
}

fallback_hash :: (bytes: [] u8) -> u64 {
    return Hash.get_hash(bytes);
}

#scope_file

#import "meow_hash";
