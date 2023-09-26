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
        fixed_update=simulate,
        variable_update=null,
        render=draw_one_frame,
        present=present
    );
}

draw_one_frame :: (dt: float) {
    Simp.clear_render_target(0, 0, 0, 1);
    Simp.set_shader_for_color();
    time := get_time();

    {
        LEFT               :: 4;
        TOP                :: 4;
        SMALL_GLYPH_SIZE   :: 5;
        GLYPH_WIDTH        :: 5;
        BAR_HEIGHT         :: SMALL_GLYPH_SIZE*2 + 3;
        TYPESETTING        :: Typesetting.{glyph.scale=.{GLYPH_WIDTH, BAR_HEIGHT}, alignment=.RIGHT};
        BAR_WIDTH_IN_CHARS :: 16;
        BAR_WIDTH          :: #run measure_text(BAR_WIDTH_IN_CHARS, typesetting=TYPESETTING).x;
        BAR_SPACING        :: 4;
        SMALL_TYPESETTING  :: Typesetting.{glyph.scale=.{SMALL_GLYPH_SIZE, SMALL_GLYPH_SIZE}, alignment=.RIGHT};

        measure_longest := measure_text(Number.LONGEST_ID_LENGTH, typesetting=TYPESETTING);

        upper_left_corner := Vector2.{0, cast(float) window_height} + Vector2.{LEFT, -TOP} + Vector2.{measure_longest.x + BAR_SPACING, 0};

        current_number_vertically := 1;

        for state.numbers {
            if !it.unlocked then continue;
            if it.capacity == FLOAT32_INFINITY then continue;

            bar_lower_left := upper_left_corner - Vector2.{0, BAR_HEIGHT * cast(float) current_number_vertically + BAR_SPACING * cast(float) (current_number_vertically-1)};
            bar_upper_right := bar_lower_left + Vector2.{BAR_WIDTH, BAR_HEIGHT};
            /*Simp.set_shader_for_color(enable_blend=true);
            Simp.immediate_quad(
                bar_lower_left.x,
                bar_lower_left.y,
                bar_upper_right.x,
                bar_upper_right.y,
            .{1,1,1,.25});*/
            push_line(bar_lower_left, bar_lower_left + Vector2.{0,BAR_HEIGHT-1});
            bar_lower_right := bar_lower_left+Vector2.{BAR_WIDTH-1,0};
            push_line(bar_lower_right, bar_lower_right + Vector2.{0, BAR_HEIGHT-1});
            bar_middle_left := bar_lower_left + Vector2.{0, BAR_HEIGHT/2};
            bar_middle_right := floor(bar_middle_left + Vector2.{BAR_WIDTH-1,0} * (it.value / it.capacity));
            push_line(bar_middle_left, bar_middle_right);

            value_text := trim(format_value(it.value));
            value_text_measurements := measure_text(value_text, SMALL_TYPESETTING);
            value_origin := bar_middle_right - SMALL_TYPESETTING.glyph.scale*.5;
            value_origin.y -= 1;
            value_origin.x = max(value_origin.x-1, bar_lower_left.x+value_text_measurements.x);
            value_typesetting := SMALL_TYPESETTING;
            push_text(value_origin, value_text, value_typesetting);
            
            label_origin := bar_lower_left + floor(TYPESETTING.glyph.scale*.5) * Vector2.{-1,1} - Vector2.{BAR_SPACING+1,0};
            label_typesetting := TYPESETTING;
            //label_typesetting.glyph.shiver = ifx it.rate_this_frame > 0 then 1;
            push_text(label_origin, tprint("%", cast(Number.ID) it_index), label_typesetting);

            rate_origin := bar_lower_right + floor(TYPESETTING.glyph.scale*.5) + Vector2.{BAR_SPACING+1, 0};
            rate_typesetting := TYPESETTING;
            rate_typesetting.alignment = .LEFT;
            //rate_typesetting.glyph.shiver = ifx it.rate_this_frame > 0 then 1;
            push_text(rate_origin, format_rate(it.rate_this_frame * 60), rate_typesetting);

            current_number_vertically += 1;
        }
        for state.numbers {
            if !it.unlocked then continue;
            if it.capacity != FLOAT32_INFINITY then continue;

            bar_lower_left := upper_left_corner - Vector2.{0, BAR_HEIGHT * cast(float) current_number_vertically + BAR_SPACING * cast(float) (current_number_vertically-1)};
            label_origin := bar_lower_left + floor(TYPESETTING.glyph.scale * .5) * Vector2.{-1,1} - Vector2.{BAR_SPACING+1,0};
            label_typesetting := TYPESETTING;
            push_text(label_origin, tprint("%", cast(Number.ID) it_index), label_typesetting);

            current_number_vertically += 1;

            value_origin := label_origin + Vector2.{BAR_SPACING + TYPESETTING.glyph.scale.x,0};
            value_typesetting := TYPESETTING;
            value_typesetting.alignment = .LEFT;
            push_text(value_origin, tprint("%", format_value(it.value)), value_typesetting);
        }
    }

    render_lines();
    flush_lines();
}

Simp  :: #import "Simp";
Input :: #import "Input";
#run {
    #if OS == .WINDOWS && BUILD == .DEPLOYING {
        (#import "Windows_Resources").disable_runtime_console();
    }
}
