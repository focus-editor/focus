publish_new_config_snapshot :: (new_config: Config) {  // only done from the main thread
    snapshot := New(Config_Snapshot);
    snapshot.config = new_config;

    lock(*config_snapshots.lock);
    {
        snapshot.generation = config_snapshots.current_generation;
        config_snapshots.current_generation += 1;

        array_add(*config_snapshots.array, snapshot);
        config_snapshots.current = snapshot;
    }
    unlock(*config_snapshots.lock);
}

acquire_current_config_snapshot :: () -> *Config_Snapshot {
    current_snapshot: *Config_Snapshot;

    lock(*config_snapshots.lock);
    {
        current_snapshot = config_snapshots.current;
        current_snapshot.reference_count += 1;
    }
    unlock(*config_snapshots.lock);

    return current_snapshot;
}

context_set_config_snapshot :: (snapshot: *Config_Snapshot) {
    if context.config_snapshot == snapshot return;

    context.config_snapshot = snapshot;
    context.config = *context.config_snapshot.config;

    buffer_settings_cache_clear();
}

release_config_snapshot :: (snapshot: *Config_Snapshot) {
    if !snapshot return;

    lock(*config_snapshots.lock);
    {
        assert(snapshot.reference_count > 0);
        snapshot.reference_count -= 1;
    }
    unlock(*config_snapshots.lock);
}

cleanup_old_config_snapshots :: () {
    old_snapshots: [..] *Config_Snapshot;
    old_snapshots.allocator = temp;

    lock(*config_snapshots.lock);
    {
        for config_snapshots.array {
            if it.reference_count == 0 {
                array_add(*old_snapshots, it);
                remove it;
            }
        }
    }
    unlock(*config_snapshots.lock);

    for old_snapshots {
        free_config(*it.config);
        free(it);
    }
}

// Thread-safety:
// When the config is changed we publish a new snapshot, then threads can safely use their old snapshots
// without risking memory unsafe behaviour.
// Each thread, including the main thread, will have a reference to their config via context.config.
config_snapshots: struct {
    array: [..] *Config_Snapshot;
    current: *Config_Snapshot;
    current_generation: int;
    lock: Mutex;
}

Config_Snapshot :: struct {
    config: Config;

    reference_count: int;
    generation: int;
}