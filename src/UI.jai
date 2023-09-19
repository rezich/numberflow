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
            }
        }
    }
    present :: () { Simp.swap_buffers(my_window); }

    loop_frame_timer(
        process_events=process_events,
        fixed_update=null,
        variable_update=simulate,
        render=draw_one_frame,
        present=present
    );
}

draw_one_frame :: (dt: float) {
    Simp.clear_render_target(0, 0, 0, 1);
    Simp.set_shader_for_color();
    time := get_time();

    BAR_HEIGHT :: 12;
    BAR_MARGIN :: 8;
    BAR_WIDTH  :: 100;
    offset: float = BAR_MARGIN;
    upper_left_corner := Vector2.{10, cast(float) window_height - BAR_HEIGHT};
    BAR_LABEL_SCALE :: Vector2.{8, BAR_HEIGHT};
    for state.numbers {
        if it.capacity == FLOAT32_INFINITY then continue;
        lower_left := upper_left_corner - Vector2.{BAR_MARGIN, offset};
        push_text(lower_left + .{0, BAR_LABEL_SCALE.y}, "AAA");
        /*push_line(lower_left, lower_left + .{0, BAR_HEIGHT});
        lower_right := lower_left + .{BAR_WIDTH, 0};
        push_line(lower_right, lower_right + .{0, BAR_HEIGHT});
        middle_left := lower_left + .{0, BAR_HEIGHT/2};
        push_line(middle_left, middle_left + .{(it.value / it.capacity) * BAR_WIDTH, 0});*/
        
        //immediate_line(.{0,offset}, .{100 * (it.value / it.capacity),offset}, 4, .{1,1,1,1});
        offset += BAR_HEIGHT + BAR_MARGIN;
    }

    push_text(.{100, 100}, "Hello, world!",
        //scale=.{4,2}
        //scale=.{4 + 2*cast(float) cos(time), 8},
        //shiver=3
    );
    render_lines();
    flush_lines();
}

Simp  :: #import "Simp";
Input :: #import "Input";
#run {
    #if OS == .WINDOWS {
        WR :: #import "Windows_Resources";
        //WR.disable_runtime_console();
    }
}
