simulate :: () {
    simulate_numbers();
    reset_temporary_storage();
}

FRAME_RATE :: 5;
simulate_frames :: (frames: int = FRAME_RATE) {
    using state;
    time.dt = 1.0 / xx FRAME_RATE;
    for 1..frames {
        log("==========");
        log(" t= %\ndt= %", time.t, time.dt);
        log("----------");
        simulate();
        log("==========\n\n\n");
        time.t += time.dt;
    }
    report_memory_leaks();
}

main :: () {
    setup();
    simulate_frames();
}

#load "src/Design.jai";
#load "src/Number.jai";
#load "src/Util.jai";

#import "Basic"()(MEMORY_DEBUGGER=true);
#import "Hash_Table";
#import "Math";
#import "Tagged_Union";
