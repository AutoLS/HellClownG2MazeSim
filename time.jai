Clock :: struct
{
    start_time: float;   
    last_time: float;    
    t: float;            
    fps: s32;            
}

init_clock :: () -> Clock
{
    result: Clock;
    result.start_time = cast(float) GetTime();
    result.last_time = result.start_time;
    return result;
}

get_frame_time :: (clock: Clock) -> float
{
    return GetFrameTime();
}

get_seconds_elapsed :: (clock: *Clock) -> float
{
    return cast(float) GetTime() - clock.last_time;
}

get_seconds_elapsed :: (start_time: float, current_time: float) -> float
{
    return current_time - start_time;
}

update_clock :: (clock: *Clock)
{
    clock.t = GetFrameTime();
    clock.fps = GetFPS();
    clock.last_time = cast(float) GetTime();
}

get_fps :: (clock: Clock) -> float
{
    return cast(float) GetFPS();
}

print_fps :: (clock: Clock)
{
    print("FPS: %\n", GetFPS());
}

Timer :: struct
{
	t: float;
	t_end: float;
	t_def: float;
	
	active: bool;
	complete: bool;
}

create_timer :: (t_end: float, active: bool) -> Timer
{
	timer: Timer;
	timer.t_end = t_end;
	timer.t_def = t_end;
	timer.active = active;
	
	return timer;
}

start_timer :: (timer: *Timer)
{
	timer.active = true;
}

stop_timer :: (timer: *Timer)
{
	timer.active = false;
}

reset_timer :: (timer: *Timer)
{
	timer.t = 0;
	timer.complete = false;
}

reset_and_stop_timer :: (timer: *Timer)
{
	reset_timer(timer);
	stop_timer(timer);
}

reset_and_start_timer :: (timer: *Timer)
{
	reset_timer(timer);
	start_timer(timer);
}

timer_completed :: (timer: Timer) -> bool
{
	return timer.complete;
}

process_timer :: (timer: *Timer, t: float)
{
	if timer.active
	{
		timer.t += t;
		if timer.t >= timer.t_end && timer.t_end > 0
		{
			timer.complete = true;
			stop_timer(timer);
		}
		else if timer.t_end == 0
		{
			timer.complete = true;
		}
	}
}

process_timers :: (timers: [] Timer, t: float)
{
	for *timer : timers
	{
		process_timer(timer, t);
	}
}