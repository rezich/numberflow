BUILD    : enum { SIMULATING; DEVELOPING; DEPLOYING; } : .DEVELOPING;
PLATFORM : enum { WINDOWS; PLAYDATE; WEBASM; }         : .WINDOWS;


DEBUG_MEMORY :: BUILD == .DEVELOPING;





simulate :: (dt: float) {
    state.time.dt = dt;
    state.time.t += dt; //TODO: fix
    
    simulate_number_flow();
    //report_numbers();
    reset_temporary_storage();
}

#if BUILD == .SIMULATING {
    FRAME_RATE         :: 1;
    FRAMES_TO_SIMULATE :: 8;
    simulate_frames :: (frames: int = FRAME_RATE) {
        using state;
        time.dt = 1.0 / xx FRAME_RATE;
        for 1..frames {
            log("=====================================");
            log(" t= %\ndt= %", time.t, time.dt);
            log("-------------------------------------");
            //simulate();
            log("=====================================\n\n\n");
            time.t += time.dt;
        }
        #if BUILD != .DEPLOYING then report_memory_leaks();
    }
}

main :: () {
    random_seed(108);
    setup();
    #if BUILD != .DEPLOYING  then check_setup();
    #if BUILD == .SIMULATING then simulate_frames(FRAMES_TO_SIMULATE);
    #if BUILD != .SIMULATING then ui_init();
    #if BUILD == .DEVELOPING {
        report_memory_leaks();
        report_numbers();
        log("most lines: %", most_lines);
    }
}

#load "src/Design.jai";
#load "src/Frame_Timer.jai";
#load "src/Line_Renderer.jai";
#load "src/Number.jai";
#load "src/Screens.jai";
#load "src/UI.jai";
#load "src/Util.jai";

#import "Basic"()(MEMORY_DEBUGGER=DEBUG_MEMORY);
#import "Hash_Table";
#import "Math";
#import "Random";
#import "String";
#import "System";
#import "Tagged_Union";
#import "Window_Creation";
