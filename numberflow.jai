state: struct {
    time: struct {
        t:  float;
        dt: float;
    }
    numbers: [Number.COUNT] Number;
    relationships: [..] Number.Relationship;
}

simulate :: () {
    simulate_number_flow();
    report_numbers();
    reset_temporary_storage();
}

FRAME_RATE         :: 4;
FRAMES_TO_SIMULATE :: 8;
simulate_frames :: (frames: int = FRAME_RATE) {
    using state;
    time.dt = 1.0 / xx FRAME_RATE;
    for 1..frames {
        log("=============================");
        log(" t= %\ndt= %", time.t, time.dt);
        log("-----------------------------");
        simulate();
        log("=============================\n\n\n");
        time.t += time.dt;
    }
    report_memory_leaks();
}

main :: () {
    setup();
    check_setup();
    simulate_frames(FRAMES_TO_SIMULATE);
}

#load "src/Design.jai";
#load "src/Number.jai";
#load "src/Util.jai";

#import "Basic"()(MEMORY_DEBUGGER=true);
#import "Hash_Table";
#import "Math";
#import "Tagged_Union";
