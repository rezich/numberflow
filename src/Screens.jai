SCREEN_WIDTH  :: 400;
SCREEN_HEIGHT :: 240;
SCREEN_DIMENSIONS :: Vector2.{SCREEN_WIDTH, SCREEN_HEIGHT};
SCREEN_CENTER :: Vector2.{SCREEN_WIDTH*.5, SCREEN_HEIGHT*.5};

TRANSITION_SPEED :: 1.0/120.0;
TRANSITION_PHASE_LABEL :: .25;
TRANSITION_PHASE_ZOOM  :: #run 1.0 - TRANSITION_PHASE_LABEL;

META_SCREEN_SCALE   :: .33;
META_SCREEN_DIMENSIONS :: #run SCREEN_DIMENSIONS * META_SCREEN_SCALE;
META_SCREEN_SPACING :: 1;

Screen :: struct {
    unlocked: bool;
    meta_position: Vector2;
}
screens : [#run enum_highest_value(SCREEN_ID)+1] Screen;
define :: (id: SCREEN_ID, meta_position: Vector2) {
    screens[id] = .{meta_position=meta_position};
}
unlock :: (id: SCREEN_ID) { screens[id].unlocked = true; }

transition_render_target: *Simp.Texture;

init_screens :: () {
    transition_render_target = Simp.texture_create_render_target(SCREEN_WIDTH, SCREEN_HEIGHT, .RGBA8);
}

render_screens :: (dt: float) {
    if state.screen.transition < 1 {
        state.screen.transition = min(state.screen.transition + dt * TRANSITION_SPEED, 1);
        transition_screen := ifx state.screen.current == .META then state.screen.previous else state.screen.current;
        Simp.set_render_target(transition_render_target);
        render_screen(transition_screen);
    }
    Simp.set_render_target(my_window);
    if state.screen.current != .META && state.screen.transition < 1 then render_screen(.META);
    else render_screen(state.screen.current);
}

render_screen :: (screen: SCREEN_ID) {
    if #complete screen == {
        case .HOME;
            clear(COLOR.WHITE);
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
                SMALL_TYPESETTING  :: Typesetting.{
                    glyph.scale=.{SMALL_GLYPH_SIZE, SMALL_GLYPH_SIZE},
                    alignment=.RIGHT,
                    style=.PROPORTIONAL
                };

                measure_longest := measure_text(Number.LONGEST_ID_LENGTH, typesetting=TYPESETTING);

                upper_left_corner := Vector2.{0, cast(float) window_height} + Vector2.{LEFT, -TOP} + Vector2.{measure_longest.x + BAR_SPACING, 0};

                current_number_vertically := 1;

                for state.numbers {
                    if !it.unlocked then continue;
                    if it.capacity == FLOAT32_INFINITY then continue;

                    bar_lower_left := upper_left_corner - Vector2.{0, BAR_HEIGHT * cast(float) current_number_vertically + BAR_SPACING * cast(float) (current_number_vertically-1)};
                    bar_upper_right := bar_lower_left + Vector2.{BAR_WIDTH, BAR_HEIGHT};

                    push_line(bar_lower_left, bar_lower_left + Vector2.{0,BAR_HEIGHT-1}, COLOR.BLACK);
                    bar_lower_right := bar_lower_left+Vector2.{BAR_WIDTH-1,0};
                    push_line(bar_lower_right, bar_lower_right + Vector2.{0, BAR_HEIGHT-1}, COLOR.BLACK);
                    bar_middle_left := bar_lower_left + Vector2.{0, BAR_HEIGHT/2};
                    bar_middle_right := floor(bar_middle_left + Vector2.{BAR_WIDTH-1,0} * (it.value / it.capacity));
                    push_line(bar_middle_left, bar_middle_right, COLOR.BLACK);

                    value_text := trim(format_value(it.value));
                    value_text_measurements := measure_text(value_text, SMALL_TYPESETTING);
                    value_origin := bar_middle_right - SMALL_TYPESETTING.glyph.scale*.5;
                    value_origin.y -= 1;
                    value_origin.x = max(value_origin.x-1, bar_lower_left.x+value_text_measurements.x);
                    value_typesetting := SMALL_TYPESETTING;
                    value_typesetting.style = .PROPORTIONAL;
                    push_text(value_origin, value_text, value_typesetting);
                    
                    label_origin := bar_lower_left + floor(TYPESETTING.glyph.scale*.5) * Vector2.{-1,1} - Vector2.{BAR_SPACING+1,0};
                    label_typesetting := TYPESETTING;
                    //label_typesetting.glyph.shiver = ifx it.rate_this_frame > 0 then 1;
                    push_text(label_origin, tprint("%", cast(Number.ID) it_index), label_typesetting);

                    rate_origin := bar_lower_right + floor(TYPESETTING.glyph.scale*.5) + Vector2.{BAR_SPACING+1, 0};
                    rate_typesetting := TYPESETTING;
                    rate_typesetting.alignment = .LEFT;
                    //rate_typesetting.style = .PROPORTIONAL;
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
                    value_typesetting.style = .PROPORTIONAL;
                    push_text(value_origin, tprint("%", format_value(it.value)), value_typesetting);
                }
            }

        case .UPGRADES;
        case .DEFRAG;

        case .META;
            clear(COLOR.BLACK);
            to_meta := state.screen.current == .META;
            origin := SCREEN_CENTER;
            camera := Vector2.{};
            scale_previous_label: float = 1;
            if state.screen.transition < 1 {
                if to_meta
                then scale_previous_label = max(state.screen.transition-TRANSITION_PHASE_ZOOM, 0) / TRANSITION_PHASE_LABEL;
                else scale_previous_label = 1-min(state.screen.transition / TRANSITION_PHASE_LABEL, 1);
            }
            
            for screens {
                if state.screen.transition < 1 && (to_meta && xx it_index == state.screen.previous) || (!to_meta && xx it_index == state.screen.current) then continue;
                if it_index == xx SCREEN_ID.META then continue;
                if !it.unlocked then continue;
                render_meta_screen(xx it_index, it);
            }
            if state.screen.transition < 1 {
                render_lines();
                render_transition(to_meta);
                index := ifx to_meta then state.screen.previous else state.screen.current;
                render_meta_screen(index, screens[index]);
            }
    }
    render_lines();
}

render_meta_screen :: (it_index: SCREEN_ID, it: Screen) #expand {
    this_origin := `origin + it.meta_position * Vector2.{SCREEN_WIDTH*META_SCREEN_SCALE + META_SCREEN_SPACING, SCREEN_HEIGHT*META_SCREEN_SCALE + META_SCREEN_SPACING} * `scale_previous_label;
    lower_left := this_origin - META_SCREEN_DIMENSIONS*.5;
    upper_right := this_origin + META_SCREEN_DIMENSIONS*.5;
    Simp.set_shader_for_color();
    Simp.immediate_quad(lower_left.x, lower_left.y, upper_right.x, upper_right.y, COLOR_VALUES[COLOR.WHITE]);

    label_scale: float = 1;

    is_transition_label := (`to_meta && xx it_index == state.screen.previous) || (!`to_meta && xx it_index == state.screen.current);

    if (is_transition_label && `scale_previous_label > 0) || !is_transition_label {
        push_text(this_origin , tprint("%", cast(SCREEN_ID) it_index), .{
            glyph.scale=.{9,15} * ifx is_transition_label then `scale_previous_label else 1,
            alignment=.CENTER
        });
    }
}

render_transition :: (to_meta: bool) {
    if to_meta then render_lines();
    
    scale_transition: float;
    if to_meta
    then scale_transition = 1-state.screen.transition/TRANSITION_PHASE_ZOOM;
    else scale_transition = (state.screen.transition-TRANSITION_PHASE_LABEL)/TRANSITION_PHASE_ZOOM;

    scale_vector := SCREEN_CENTER * (scale_transition*(1-META_SCREEN_SCALE) + META_SCREEN_SCALE);
    lower_left  := SCREEN_CENTER - scale_vector;
    upper_right := SCREEN_CENTER + scale_vector;
    Simp.set_shader_for_images(transition_render_target);
    Simp.immediate_quad(lower_left.x, lower_left.y, upper_right.x, upper_right.y, .{1,1,1,1});
}

clear :: (color: COLOR) {
    background := COLOR_VALUES[color];
    Simp.clear_render_target(background.x, background.y, background.z, 1);
}

screen_meta_toggle :: () {
    if state.screen.current != .META {
        state.screen.previous = state.screen.current;
        state.screen.current = .META;
    }
    else {
        state.screen.current = state.screen.previous;
        state.screen.previous = .META;
    }
    state.screen.transition = 1 - state.screen.transition;
    /*transition_screen := ifx state.screen.current == .META then state.screen.previous else state.screen.current;
    Simp.set_render_target(transition_render_target);
    render_screen(transition_screen);*/
}
