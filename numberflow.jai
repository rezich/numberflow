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

FRAME_RATE         :: 1;
FRAMES_TO_SIMULATE :: 8;
simulate_frames :: (frames: int = FRAME_RATE) {
    using state;
    time.dt = 1.0 / xx FRAME_RATE;
    for 1..frames {
        log("=====================================");
        log(" t= %\ndt= %", time.t, time.dt);
        log("-------------------------------------");
        simulate();
        log("=====================================\n\n\n");
        time.t += time.dt;
    }
    report_memory_leaks();
}

main :: () {
    setup();
    check_setup();
    simulate_frames(FRAMES_TO_SIMULATE);

/*{
    sb: String_Builder;
    for float.[
        0,
        1,
        -1,
        10,
        -10,
        100,
        -100,
        1000,
        -1000,
        10_000,
        -10_000
    ] {
        append(*sb, "|");
        format_rate(*sb, it);
        append(*sb, "|\n");
        log("%", builder_to_string(*sb, allocator=temp));
    }
}{
    sb: String_Builder;
    for float.[
             0,
             0.1,
             0.22,
             0.333,
             1,
            10,
           100,
           111,
           200,
           997,
           998,
           999,
           999.99,
         1_000,
         1_111,
         1_111.11,
        10_000,
    ] {
        append(*sb, "|");
        format_value(*sb, it);
        append(*sb, "|\n");
        log("%", builder_to_string(*sb, allocator=temp));
    }
}*/

    
}

#load "src/Design.jai";
#load "src/Number.jai";
#load "src/Util.jai";

#import "Basic"()(MEMORY_DEBUGGER=true);
#import "Hash_Table";
#import "Math";
#import "Tagged_Union";
