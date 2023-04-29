// NOTE: calculates only 64 bits
calculate_meow_hash :: (bytes: [] u8) -> u64 {
    #asm { hash: vec; }

    MeowHash(MeowDefaultSeed, xx bytes.count, bytes.data, hash);

    return MeowU64From(hash, 0);
}

calculate_meow_hash :: inline (s: string) -> u64 {
    return calculate_meow_hash(to_bytes(s));
}

#scope_file

#import "meow_hash";