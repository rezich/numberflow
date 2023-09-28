my_window: Window_Type;
window_width  : s32 = 400;
window_height : s32 = 240;

ui_init :: () {
    #if OS == .WINDOWS {
        Windows :: #import "Windows";
        Windows.SetProcessDPIAware();
        // Windows is very bad at thread-switching by default unless you do this. Sad.
        Windows.timeBeginPeriod(1);
    }
    my_window = create_window(window_width, window_height, "numberflow");
    window_width, window_height = Simp.get_render_dimensions(my_window);
    Simp.set_render_target(my_window);

    init_screens();

    init_frame_timer();

    process_events :: () {
        Input.update_window_events();
        for Input.get_window_resizes() {
            Simp.update_window(it.window);  // Simp will do nothing if it doesn't care about this window.
            
            if it.window == my_window {
                should_reinit := (it.width != window_width) || (it.height != window_height);

                window_width  = it.width;
                window_height = it.height;

                //if should_reinit my_init_fonts();  // Resize the font for the new window size.
            }
        }
        for Input.events_this_frame {
            if it.type == .QUIT then quit_frame_timer();
            if it.type == {
                case .KEYBOARD;
                    if it.key_pressed && it.key_code == .ESCAPE then quit_frame_timer();
                    if it.key_pressed && it.key_code == .SPACEBAR then screen_meta_toggle();
            }
        }
    }
    present :: () { Simp.swap_buffers(my_window); }

    loop_frame_timer(
        process_events=process_events,
        fixed_update=simulate,
        variable_update=null,
        render=draw_one_frame,
        present=present
    );
}

draw_one_frame :: (dt: float) {
    render_screens(dt);
    reset_frame_lines();
}

Simp  :: #import "Simp";
Input :: #import "Input";

#run #if OS == .WINDOWS && BUILD == .DEPLOYING then (#import "Windows_Resources").disable_runtime_console();
