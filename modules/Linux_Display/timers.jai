Timer :: s64;

timer_create :: (user_data: *void = null, cb: type_of(TimerData.cb) = null, initial_tick: u32 = 0, repeat: u32 = 0) -> Timer {
    TFD_TIMER_ABSTIME : s32 : 1;

    tmr: *TimerData;
    tid: Timer;
    for * t, ti : timers {
        if t.fd < 0 {
            tmr = t;
            tid = ti;
            break;
        }
    }

    if !tmr {
        tmr = array_add(*timers);
        tid = timers.count - 1;
    }

    tmr.fd = timerfd_create(xx CLOCK_MONOTONIC, O_CLOEXEC);

    ev := epoll_event.{
        events =  EPOLLIN,
        data._u64 = xx tid,
    };
    epoll_ctl(timers_epfd, EPOLL_CTL_ADD, tmr.fd, *ev);

    tmr.cb = cb;
    tmr.user_data = user_data;

    timer_start(tid, initial_tick, repeat);

    return tid;
}

timer_destroy :: (tid: Timer) {
    timer := *timers[tid];
    close(timer.fd);
    timer.* = .{};
}

timer_start :: (tid: Timer, initial_tick: u32, repeat: u32 = 0) {
    if initial_tick == 0 && repeat == 0 return;

    T :: type_of(itimerspec.it_value.tv_nsec);

    timer := *timers[tid];
    spec: itimerspec;
    spec.it_value.tv_nsec = max(cast(T) 1, (cast(T) initial_tick) * 1_000_000);
    spec.it_value.tv_sec  = spec.it_value.tv_nsec / 1_000_000_000;
    spec.it_value.tv_nsec = spec.it_value.tv_nsec % 1_000_000_000;
    spec.it_interval.tv_nsec += (cast(T) repeat) * 1_000_000;
    spec.it_interval.tv_sec  += spec.it_interval.tv_nsec / 1_000_000_000;
    spec.it_interval.tv_nsec  = spec.it_interval.tv_nsec % 1_000_000_000;

    timerfd_settime(timer.fd, 0, *spec, null);
}

timer_stop :: (tid: Timer) {
    spec: itimerspec;
    timer := *timers[tid];
    timerfd_settime(timer.fd, 0, *spec, null);
}

#scope_module

timers_epfd: s32 = -1;

timers_init :: () {
    if timers_epfd < 0 {
        timers_epfd = epoll_create1(EPOLL_CLOEXEC);
        assert(timers_epfd >= 0);
    }
}

timers_tick :: () {
    epevs: [16]epoll_event;
    count := epoll_wait(timers_epfd, epevs.data, xx epevs.count, 0);
    while count > 0 {
        for 0..count - 1 {
            num: u64;
            tid: Timer = xx epevs[it].data._u64;
            timer := *timers[tid];
            read(timer.fd, *num, size_of(u64));
            if timer.cb timer.cb(tid, timer.user_data);
        }
        count = epoll_wait(timers_epfd, epevs.data, xx epevs.count, 0);
    }
}

#scope_file

TimerData :: struct {
    fd: s32 = -1;
    user_data: *void = null;
    cb: #type (tid: Timer, data: *void) = null;
}

timers: [..]TimerData;
