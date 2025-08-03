// Taken and adapted from Roman Skabin's fork https://github.com/Roman-Skabin/focus/

#if OS == .WINDOWS {

    // non-recursive, not shared across processes
    RWLock :: SRWLOCK;

    init :: inline (rwlock: *RWLock) {
        rwlock.ptr = null;
    }

    destroy :: inline (rwlock: *RWLock) {
    }

    try_lock :: inline (rwlock: *RWLock, $read := false) -> bool {
        success := #ifx read then TryAcquireSRWLockShared(rwlock) else TryAcquireSRWLockExclusive(rwlock);
        return success != 0;
    }

    lock :: inline (rwlock: *RWLock, $read := false) {
        #if read then AcquireSRWLockShared(rwlock); else AcquireSRWLockExclusive(rwlock);
    }

    unlock :: inline (rwlock: *RWLock, $read := false) {
        #if read then ReleaseSRWLockShared(rwlock); else ReleaseSRWLockExclusive(rwlock);
    }

    lock_scoped :: (rwlock: *RWLock, $read := false) #expand {
        lock(rwlock, read);
        `defer unlock(rwlock, read);
    }

#scope_file

    kernel32 :: #system_library "kernel32";

    TryAcquireSRWLockExclusive :: (SRWLock: *SRWLOCK) -> BOOLEAN #foreign kernel32;
    TryAcquireSRWLockShared    :: (SRWLock: *SRWLOCK) -> BOOLEAN #foreign kernel32;
    AcquireSRWLockExclusive    :: (SRWLock: *SRWLOCK) #foreign kernel32;
    AcquireSRWLockShared       :: (SRWLock: *SRWLOCK) #foreign kernel32;
    ReleaseSRWLockExclusive    :: (SRWLock: *SRWLOCK) #foreign kernel32;
    ReleaseSRWLockShared       :: (SRWLock: *SRWLOCK) #foreign kernel32;

    SRWLOCK :: struct { ptr : *void; }
    BOOLEAN :: u8;

#scope_export

} else #if OS == .LINUX || OS == .MACOS {

    // non-recursive, not shared across processes
    RWLock :: pthread_rwlock_t;

    init :: (rwlock: *RWLock) {
        attr : pthread_rwlockattr_t;
        error := pthread_rwlockattr_init(*attr);
        assert(!error);

        #if OS == .LINUX {
            error = pthread_rwlockattr_setpshared(*attr, PTHREAD_PROCESS_PRIVATE);
        } else {
            error = pthread_rwlockattr_setpshared(*attr, xx PTHREAD_PROCESS.PRIVATE);
        }
        assert(!error);

        error = pthread_rwlock_init(rwlock, *attr);
        assert(!error);

        error = pthread_rwlockattr_destroy(*attr);
        assert(!error);
    }

    destroy :: inline (rwlock: *RWLock) {
        error := pthread_rwlock_destroy(rwlock);
        assert(!error);
    }

    try_lock :: inline (rwlock: *RWLock, $read := false) -> bool {
        error := #ifx read then pthread_rwlock_tryrdlock(rwlock) else pthread_rwlock_trywrlock(rwlock);
        return !error;
    }

    lock :: inline (rwlock: *RWLock, $read := false) {
        error := #ifx read then pthread_rwlock_rdlock(rwlock) else pthread_rwlock_wrlock(rwlock);
        assert(!error);
    }

    unlock :: inline (rwlock: *RWLock, $read := false) {
        error := pthread_rwlock_unlock(rwlock);
        assert(!error);
    }

    lock_rwlock_scoped :: (rwlock: *RWLock, $read := false) #expand {
        lock(rwlock, read);
        `defer unlock(rwlock, read);
    }

}
