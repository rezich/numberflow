// ported from https://github.com/TylerGlaiel/FrameTimingControl/blob/master/frame_timer.cpp

/*
MIT License

Copyright (c) 2019 Tyler Glaiel

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

frame_timer: struct {
    is_quitting: bool;
    update_rate: float = 60;
    update_multiplicity := 1;
    unlock_framerate := true;

    clocks_per_second: s64 = 1000;
    fixed_deltatime: float;
    desired_frametime: s64;
    vsync_maxerror: s64;

    display_framerate: int = 60;
    snap_hz: s64;

    SNAP_FREQUENCIES_COUNT :: 8;
    snap_frequencies: [SNAP_FREQUENCIES_COUNT] s64;

    TIME_HISTORY_COUNT :: 4;
    time_averager: [TIME_HISTORY_COUNT] s64;
    averager_residual: s64;

    prev_frame_time: s64;
    frame_accumulator: s64;

    DEATH_SPIRAL_FACTOR :: 8;
    resync: bool;
}

init_frame_timer :: () {
    using frame_timer;
    #if OS == .WINDOWS {
        Windows :: #import "Windows";
        success: bool;
        success = xx Windows.QueryPerformanceFrequency(*clocks_per_second);
        assert(success);
        success = xx Windows.QueryPerformanceCounter(*prev_frame_time);
        assert(success);
    }
    fixed_deltatime = 1.0 / update_rate;
    desired_frametime = clocks_per_second / xx update_rate;
    vsync_maxerror = xx (clocks_per_second * 0.0002);

    //TODO: set display_framerate based on current display

    snap_hz = display_framerate;
    if snap_hz <= 0 then snap_hz = 60;

    for 0..SNAP_FREQUENCIES_COUNT-1 snap_frequencies[it] = (clocks_per_second/snap_hz) * (it+1);

    for 0..TIME_HISTORY_COUNT-1 time_averager[it] = desired_frametime;
}

loop_frame_timer :: (
    $process_events:  ()        = null,
    $fixed_update:    (float) = null,
    $variable_update: (float) = null,
    $render:          (float) = null,
    $present:         ()        = null,
    $cleanup:         ()        = reset_temporary_storage
) #expand {
    using frame_timer;
    while !is_quitting {
        current_frame_time: s64;
        #if OS == .WINDOWS {
            Windows :: #import "Windows";
            success: bool;
            success = xx Windows.QueryPerformanceCounter(*current_frame_time);
            assert(success);
        }
        delta_time := current_frame_time - prev_frame_time;
        prev_frame_time = current_frame_time;

        if delta_time > desired_frametime * DEATH_SPIRAL_FACTOR then delta_time = desired_frametime;
        if delta_time < 0 then delta_time = 0;

        for 0..SNAP_FREQUENCIES_COUNT-1 if abs(delta_time - snap_frequencies[it]) < vsync_maxerror {
            delta_time = snap_frequencies[it];
            break;
        }

        for 0..TIME_HISTORY_COUNT-2 time_averager[it] = time_averager[it+1];
        time_averager[TIME_HISTORY_COUNT-1] = delta_time;

        averager_sum: s64;
        for 0..TIME_HISTORY_COUNT-1 averager_sum += time_averager[it];
        delta_time = averager_sum / TIME_HISTORY_COUNT;

        averager_residual += averager_sum % TIME_HISTORY_COUNT;
        delta_time += averager_residual / TIME_HISTORY_COUNT;
        averager_residual %= TIME_HISTORY_COUNT;

        frame_accumulator += delta_time;

        if frame_accumulator > desired_frametime*DEATH_SPIRAL_FACTOR then resync = true;

        if resync {
            frame_accumulator = 0;
            delta_time = desired_frametime;
            resync = false;
        }

        #if process_events then process_events();

        if unlock_framerate {
            consumed_delta_time := delta_time;
            while frame_accumulator >= desired_frametime {
                #if fixed_update then fixed_update(fixed_deltatime);
                if consumed_delta_time > desired_frametime {
                    #if variable_update then variable_update(fixed_deltatime);
                    consumed_delta_time -= desired_frametime;
                }
                frame_accumulator -= desired_frametime;
            }
            #if variable_update then variable_update(cast(float) consumed_delta_time / clocks_per_second);
            #if render then render(cast(float) frame_accumulator / desired_frametime);
        }
        else {
            while frame_accumulator >= desired_frametime * update_multiplicity {
                for 0..update_multiplicity-1 {
                    #if fixed_update then fixed_update(fixed_deltatime);
                    #if variable_update then variable_update(fixed_deltatime);
                    frame_accumulator -= desired_frametime;
                }
            }
            #if render then render(1.0);
        }
        #if present then present();
        #if cleanup then cleanup();
    }
}

quit_frame_timer :: () { frame_timer.is_quitting = true; }

#import "Math";