DEBUG_GLYPHS :: false;

Typesetting :: struct {
    glyph: struct {
        scale:   Vector2 = .{5,9};
        spacing: int     = 1;
        shiver:  int     = 0;
    }
    alignment: enum { LEFT;    CENTER;    RIGHT; } = .LEFT;
    style:     enum { FIXED_WIDTH; PROPORTIONAL; } = .FIXED_WIDTH;
    color:     COLOR;
    proportional_space_width: int = 1;
}




immediate_line :: (start: Vector2, end: Vector2, breadth: float, color: Vector4) {
    theta := atan2(end.y-start.y, end.x-start.x);

    perpendicular := Vector2.{-sin(theta),  cos(theta)} * breadth * .5;
    parallel      := Vector2.{ cos(theta),  sin(theta)} * breadth * .5;

    Simp.set_shader_for_color(enable_blend=true);
    Simp.immediate_quad(
        start - parallel  + perpendicular,
        start - parallel  - perpendicular,
        end   + parallel  - perpendicular,
        end   + parallel  + perpendicular,
        color
    );
}

immediate_pixel_line :: inline (start: Vector2, end: Vector2, color: Vector4) {
    OFFSET :: Vector2.{.5,.5};
    immediate_line(floor(start)+OFFSET, floor(end)+OFFSET, 1, color);
}

immediate_circle :: (origin: Vector2, radius: float, breadth: float, segments: int = 12, color: Vector4) {
    delta := TAU / segments;
    for 0..segments-1 {
        next := ifx it == segments-1 then 0 else it+1;
        immediate_line(
            origin + Vector2.{cos(it * delta), sin(it * delta)} * radius,
            origin + Vector2.{cos(next*delta), sin(next*delta)} * radius,
            breadth,
            color
        );
    }
}

floor :: inline (using v: Vector2) -> Vector2 { return Vector2.{floor(x), floor(y)}; }
round_away_from_zero :: inline (f: float) -> float {
    sign: float;
    if f > 0 then sign =  1;
    if f < 0 then sign = -1;
    base: float;
    if f >= 0 then base = floor(f);
              else base =  ceil(f);
    return base + ifx frac(f) >= .5 then sign;
}
round_away_from_zero :: inline (using v: Vector2) -> Vector2 { return .{round_away_from_zero(x), round_away_from_zero(y)}; }


COLOR :: enum { BLACK; WHITE; }
COLOR_VALUES : [#run enum_highest_value(COLOR)+1] Vector4 : .[
    .{.196, .184, .157, 1},
    .{.694, .682, .655, 1}
];

Line :: struct {
    MAXIMUM :: 1000;
    start: Vector2;
    end:   Vector2;
    color: COLOR;
}
lines: [Line.MAXIMUM] Line;
next_line:  int;
frame_lines: int;
most_lines: int;

push_line :: (point: Vector2) {
    assert(next_line <= Line.MAXIMUM);
    assert(next_line > 0);
    prev_line := lines[next_line-1];
    lines[next_line] = .{prev_line.end, point, prev_line.color};
    next_line += 1;
}

push_line :: (start: Vector2, end: Vector2, color: COLOR) {
    assert(next_line <= Line.MAXIMUM);
    lines[next_line] = .{start, end, color};
    next_line += 1;
}

push_text :: (position: Vector2, text: string, typesetting: Typesetting = .{}) {
    rng :: random_get_zero_to_one;
    cursor := position;
    using typesetting;

    if alignment == {
        case .LEFT;
        case .CENTER; cursor -= Vector2.{(measure_text(text, typesetting).x-1)*.5,0};
        case .RIGHT;  cursor -= Vector2.{measure_text(text, typesetting).x - glyph.scale.x,0};
    }

    using glyph;

    glyph_scale := floor(.{
        (scale.x-1)*.5,
        (scale.y-1)*.5
    });

    for text_index: 0..text.count-1 {
        if text[text_index] == #char "\n" {
            cursor = Vector2.{position.x, cursor.y - (glyph.scale.y+spacing)};
            continue;
        }

        shiver_offset := ifx shiver != 0
            then floor(Vector2.{-shiver*.5,-shiver*.5} + Vector2.{rng(), rng()} * cast(float) shiver)
            else Vector2.{};

        glyph_strokes := *FONT[text[text_index]-FONT_ASCII_OFFSET];

        fixed_width_stride := glyph.scale.x;
        stride := fixed_width_stride;
        stride_remaining := stride;
        offset: Vector2;

        if style == .PROPORTIONAL {
            if glyph_strokes.*.count > 0 {
                leftmost, rightmost: float;
                for glyph_strokes.* {
                    start := stroke_point(it.start, glyph_scale);
                    end   := stroke_point(  it.end, glyph_scale);
                    if start.x < leftmost  then leftmost  = start.x;
                    if end.x   < leftmost  then leftmost  = end.x;
                    if start.x > rightmost then rightmost = start.x;
                    if end.x   > rightmost then rightmost = end.x;
                }
                short_stride := (rightmost-leftmost + 1);
                if short_stride < stride {
                    stride = short_stride;
                    offset.x = -(leftmost+rightmost)*.5;
                }
            } else stride = xx proportional_space_width;
            minus_stride := (stride-1)*.5;
            if text_index != 0 then cursor.x += minus_stride;
            stride_remaining = stride - minus_stride;
        }

        #if DEBUG_GLYPHS {
            stride_minus_one_over_two := (stride-1)*.5;
            lower_left  := cursor + Vector2.{-stride_minus_one_over_two, -glyph_scale.y};
            upper_right := cursor + Vector2.{ stride_minus_one_over_two,  glyph_scale.y};
            with_alpha :: (v, a) => Vector4.{v.x,v.y,v.z,a};
            C_BACKGROUND  :: Vector4.{.2,.2,.2,1};
            Simp.set_shader_for_color(enable_blend=true);
            Simp.immediate_quad(lower_left.x, lower_left.y, upper_right.x+1, upper_right.y+1, with_alpha(C_BACKGROUND, 1.0));
            //immediate_pixel_line(.{lower_left.x, cursor.y}, .{upper_right.x, cursor.y}, with_alpha(C_BACKGROUND, 0.2));
            //immediate_pixel_line(.{cursor.x, lower_left.y}, .{cursor.x, upper_right.y}, with_alpha(C_BACKGROUND, 0.2));
            
        }

        for glyph_strokes.* {
            push_line(
                cursor + stroke_point(it.start, glyph_scale) + offset + shiver_offset,
                cursor + stroke_point(  it.end, glyph_scale) + offset + shiver_offset,
                color
            );
        }
        #if DEBUG_GLYPHS then Simp.immediate_quad(cursor.x, cursor.y-glyph_scale.y-1, cursor.x+1, cursor.y-glyph_scale.y, Vector4.{1,0,0,1});

        cursor += Vector2.{stride_remaining+spacing,0};
    }
}

measure_text :: (text: string, using typesetting: Typesetting = .{}) -> Vector2 {
    lines := 0;
    if #complete style == {
        case .FIXED_WIDTH;
            handle_end_of_line :: () #expand {
                if `chars_this_line > `max_chars_per_line then `max_chars_per_line = `chars_this_line;
                `chars_this_line = 0;
                `lines += 1;
            }
            chars_this_line: int;
            max_chars_per_line: int;
            for text_index: 0..text.count-1 {
                if text[text_index] == #char "\n" {
                    handle_end_of_line();
                    continue;
                } else chars_this_line += 1;
            }
            handle_end_of_line();
            return measure_text(max_chars_per_line, lines, typesetting);
        case .PROPORTIONAL;
            handle_end_of_line :: () #expand {
                if `stride_this_line > `max_stride_per_line then `max_stride_per_line = `stride_this_line;
                `stride_this_line = 0;
                `lines += 1;
            }
            glyph_scale := floor(.{
                (glyph.scale.x-1)*.5,
                (glyph.scale.y-1)*.5
            });
            stride_this_line: float;
            max_stride_per_line: float;
            for text_index: 0..text.count-1 {
                if text[text_index] == #char "\n" {
                    handle_end_of_line();
                    continue;
                }
                stride := glyph.scale.x;
                stride_remaining := stride;
                glyph_strokes := *FONT[text[text_index]-FONT_ASCII_OFFSET];
                if glyph_strokes.*.count > 0 {
                    leftmost, rightmost: float;
                    for glyph_strokes.* {
                        start := stroke_point(it.start, glyph_scale);
                        end   := stroke_point(  it.end, glyph_scale);
                        if start.x < leftmost  then leftmost  = start.x;
                        if end.x   < leftmost  then leftmost  = end.x;
                        if start.x > rightmost then rightmost = start.x;
                        if end.x   > rightmost then rightmost = end.x;
                    }
                    short_stride := (rightmost-leftmost + 1);
                    if short_stride < stride then stride = short_stride;
                } else stride = xx proportional_space_width;
                minus_stride := (stride-1)*.5;
                /*if text_index != 0 then*/ stride_this_line += minus_stride;
                stride_remaining = stride - minus_stride;
                stride_this_line += stride_remaining + ifx text_index != text.count-1 then glyph.spacing;
            }
            handle_end_of_line();
            return Vector2.{max_stride_per_line, lines*glyph.scale.y+max(lines-1, 0)*cast(float) glyph.spacing};
    }
}

measure_text :: (columns: int, rows: int = 1, using typesetting: Typesetting = .{}) -> Vector2 {
    assert(style != .PROPORTIONAL, "Can't use this form of measure_text() with proportional typesetting!");
    return Vector2.{
        cast(float) columns * glyph.scale.x + max(columns-1, 0) * cast(float) glyph.spacing,
        cast(float) rows    * glyph.scale.y + max(rows   -1, 0) * cast(float) glyph.spacing
    };
}

render_lines :: () {
    Simp.set_shader_for_color();
    for 0..next_line-1 immediate_pixel_line(lines[it].start, lines[it].end, COLOR_VALUES[lines[it].color]);
    flush_lines();
}

flush_lines :: () { frame_lines += next_line; next_line = 0; }

reset_frame_lines :: () { if frame_lines > most_lines then most_lines = frame_lines; frame_lines = 0; }



#scope_file



BASIC_ASCII_COUNT :: 128;
FONT_ASCII_OFFSET :: 32;
Stroke :: struct {
    Point :: struct {
        Coord :: enum {
            NEGATIVE_ONE;
            NEGATIVE_HALF;
            ZERO;
            POSITIVE_HALF;
            POSITIVE_ONE;
        }
        x: Coord;
        y: Coord;
    }
    start: Point;
    end:   Point;
}

stroke_point :: (sp: Stroke.Point, glyph_scale: Vector2) -> Vector2 {
    v: Vector2;
    if sp.x == {
        case .NEGATIVE_ONE;  v.x = -glyph_scale.x;
        case .NEGATIVE_HALF; v.x = round_away_from_zero(-glyph_scale.x * .5);
        case .ZERO;          v.x = 0;
        case .POSITIVE_HALF; v.x = round_away_from_zero(glyph_scale.x * .5);
        case .POSITIVE_ONE;  v.x = glyph_scale.x;
    }
    if sp.y == {
        case .NEGATIVE_ONE;  v.y = -glyph_scale.y;
        case .NEGATIVE_HALF; v.y = round_away_from_zero(-glyph_scale.y * .5);
        case .ZERO;          v.y = 0;
        case .POSITIVE_HALF; v.y = round_away_from_zero(glyph_scale.y * .5);
        case .POSITIVE_ONE;  v.y = glyph_scale.y;
    }
    return v;
}

Glyph :: #type [..] Stroke;
FONT : [BASIC_ASCII_COUNT-FONT_ASCII_OFFSET] Glyph : .[
    // Space
    .[],
    // Exclamation mark
    .[
        .{.{.ZERO, .ZERO}, .{.ZERO, .POSITIVE_ONE}},
        .{.{.ZERO, .NEGATIVE_HALF}, .{.ZERO, .NEGATIVE_ONE}},
    ],
    // Quotation mark
    .[
        .{.{.NEGATIVE_HALF, .POSITIVE_HALF}, .{.ZERO, .POSITIVE_ONE}},
        .{.{.ZERO, .POSITIVE_HALF}, .{.POSITIVE_HALF, .POSITIVE_ONE}},
    ],
    // Number sign
    .[
        .{.{.NEGATIVE_ONE, .POSITIVE_HALF}, .{.POSITIVE_ONE, .POSITIVE_HALF}},
        .{.{.NEGATIVE_HALF, .POSITIVE_ONE}, .{.NEGATIVE_HALF, .NEGATIVE_ONE}},
        .{.{.POSITIVE_HALF, .POSITIVE_ONE}, .{.POSITIVE_HALF, .NEGATIVE_ONE}},
        .{.{.NEGATIVE_ONE, .NEGATIVE_HALF}, .{.POSITIVE_ONE, .NEGATIVE_HALF}},
    ],
    // Dollar sign
    .[
        .{.{.NEGATIVE_HALF, .NEGATIVE_HALF}, .{.POSITIVE_HALF, .NEGATIVE_HALF}},
        .{.{.POSITIVE_HALF, .NEGATIVE_HALF}, .{.POSITIVE_HALF, .ZERO}},
        .{.{.POSITIVE_HALF, .ZERO}, .{.NEGATIVE_HALF, .ZERO}},
        .{.{.NEGATIVE_HALF, .ZERO}, .{.NEGATIVE_HALF, .POSITIVE_HALF}},
        .{.{.NEGATIVE_HALF, .POSITIVE_HALF}, .{.POSITIVE_HALF, .POSITIVE_HALF}},
        .{.{.ZERO, .POSITIVE_ONE}, .{.ZERO, .NEGATIVE_ONE}},
    ],
    // Percent sign
    .[
        .{.{.NEGATIVE_ONE, .POSITIVE_ONE}, .{.NEGATIVE_ONE, .POSITIVE_HALF}},
        .{.{.POSITIVE_ONE, .POSITIVE_ONE}, .{.NEGATIVE_ONE, .NEGATIVE_ONE}},
        .{.{.POSITIVE_ONE, .NEGATIVE_HALF}, .{.POSITIVE_ONE, .NEGATIVE_ONE}},
    ],
    // Ampersand
    .[
        .{.{.ZERO, .NEGATIVE_ONE}, .{.ZERO, .POSITIVE_ONE}},
        .{.{.ZERO, .POSITIVE_ONE}, .{.POSITIVE_ONE, .POSITIVE_ONE}},
        .{.{.POSITIVE_ONE, .POSITIVE_ONE}, .{.POSITIVE_ONE, .ZERO}},
        .{.{.POSITIVE_ONE, .ZERO}, .{.NEGATIVE_ONE, .ZERO}},
        .{.{.NEGATIVE_ONE, .ZERO}, .{.NEGATIVE_ONE, .NEGATIVE_ONE}},
        .{.{.NEGATIVE_ONE, .NEGATIVE_ONE}, .{.POSITIVE_ONE, .NEGATIVE_ONE}},
    ],
    // Apostrophe
    .[
        .{.{.ZERO, .POSITIVE_HALF}, .{.ZERO, .POSITIVE_ONE}},
    ],
    // Left parenthesis
    .[
        .{.{.POSITIVE_HALF, .POSITIVE_ONE}, .{.NEGATIVE_HALF, .POSITIVE_HALF}},
        .{.{.NEGATIVE_HALF, .POSITIVE_HALF}, .{.NEGATIVE_HALF, .NEGATIVE_HALF}},
        .{.{.NEGATIVE_HALF, .NEGATIVE_HALF}, .{.POSITIVE_HALF, .NEGATIVE_ONE}},
    ],
    // Right parenthesis
    .[
        .{.{.NEGATIVE_HALF, .POSITIVE_ONE}, .{.POSITIVE_HALF, .POSITIVE_HALF}},
        .{.{.POSITIVE_HALF, .POSITIVE_HALF}, .{.POSITIVE_HALF, .NEGATIVE_HALF}},
        .{.{.POSITIVE_HALF, .NEGATIVE_HALF}, .{.NEGATIVE_HALF, .NEGATIVE_ONE}},
    ],
    // Asterisk
    .[
        .{.{.NEGATIVE_HALF, .ZERO}, .{.POSITIVE_HALF, .POSITIVE_ONE}},
        .{.{.ZERO, .ZERO}, .{.ZERO, .POSITIVE_ONE}},
        .{.{.NEGATIVE_HALF, .POSITIVE_ONE}, .{.POSITIVE_HALF, .ZERO}},
    ],
    // Plus sign
    .[
        .{.{.NEGATIVE_HALF, .ZERO}, .{.POSITIVE_HALF, .ZERO}},
        .{.{.ZERO, .POSITIVE_HALF}, .{.ZERO, .NEGATIVE_HALF}},
    ],
    // Comma
    .[
        .{.{.NEGATIVE_HALF, .NEGATIVE_ONE}, .{.ZERO, .NEGATIVE_HALF}},
    ],
    // Hyphen-minus
    .[
        .{.{.NEGATIVE_ONE, .ZERO}, .{.POSITIVE_ONE, .ZERO}},
    ],
    // Full stop
    .[
        .{.{.ZERO, .NEGATIVE_ONE}, .{.ZERO, .NEGATIVE_HALF}},
    ],
    // Slash
    .[
        .{.{.NEGATIVE_ONE, .NEGATIVE_ONE}, .{.POSITIVE_ONE, .POSITIVE_ONE}},
    ],
    // Digit Zero
    .[
        .{.{.NEGATIVE_ONE, .NEGATIVE_ONE}, .{.NEGATIVE_ONE, .POSITIVE_ONE}},
        .{.{.NEGATIVE_ONE, .POSITIVE_ONE}, .{.POSITIVE_ONE, .POSITIVE_ONE}},
        .{.{.POSITIVE_ONE, .POSITIVE_ONE}, .{.NEGATIVE_ONE, .NEGATIVE_ONE}},
        .{.{.NEGATIVE_ONE, .NEGATIVE_ONE}, .{.POSITIVE_ONE, .NEGATIVE_ONE}},
        .{.{.POSITIVE_ONE, .NEGATIVE_ONE}, .{.POSITIVE_ONE, .POSITIVE_ONE}},
    ],
    // Digit One
    .[
        .{.{.NEGATIVE_ONE, .POSITIVE_HALF}, .{.ZERO, .POSITIVE_ONE}},
        .{.{.ZERO, .POSITIVE_ONE}, .{.ZERO, .NEGATIVE_ONE}},
        .{.{.NEGATIVE_ONE, .NEGATIVE_ONE}, .{.POSITIVE_ONE, .NEGATIVE_ONE}},
    ],
    // Digit Two
    .[
        .{.{.NEGATIVE_ONE, .ZERO}, .{.ZERO, .POSITIVE_ONE}},
        .{.{.ZERO, .POSITIVE_ONE}, .{.POSITIVE_ONE, .ZERO}},
        .{.{.POSITIVE_ONE, .ZERO}, .{.NEGATIVE_ONE, .NEGATIVE_ONE}},
        .{.{.NEGATIVE_ONE, .NEGATIVE_ONE}, .{.POSITIVE_ONE, .NEGATIVE_ONE}},
    ],
    // Digit Three
    .[
        .{.{.NEGATIVE_ONE, .POSITIVE_ONE}, .{.POSITIVE_ONE, .POSITIVE_ONE}},
        .{.{.POSITIVE_ONE, .POSITIVE_ONE}, .{.POSITIVE_ONE, .NEGATIVE_ONE}},
        .{.{.POSITIVE_ONE, .NEGATIVE_ONE}, .{.NEGATIVE_ONE, .NEGATIVE_ONE}},
        .{.{.NEGATIVE_HALF, .ZERO}, .{.POSITIVE_ONE, .ZERO}},
    ],
    // Digit Four
    .[
        .{.{.NEGATIVE_ONE, .POSITIVE_ONE}, .{.NEGATIVE_ONE, .ZERO}},
        .{.{.NEGATIVE_ONE, .ZERO}, .{.POSITIVE_ONE, .ZERO}},
        .{.{.POSITIVE_ONE, .POSITIVE_ONE}, .{.POSITIVE_ONE, .NEGATIVE_ONE}},
    ],
    // Digit Five
    .[
        .{.{.NEGATIVE_ONE, .NEGATIVE_ONE}, .{.POSITIVE_ONE, .ZERO}},
        .{.{.POSITIVE_ONE, .ZERO}, .{.NEGATIVE_ONE, .ZERO}},
        .{.{.NEGATIVE_ONE, .ZERO}, .{.NEGATIVE_ONE, .POSITIVE_ONE}},
        .{.{.NEGATIVE_ONE, .POSITIVE_ONE}, .{.POSITIVE_ONE, .POSITIVE_ONE}},
    ],
    // Digit Six
    .[
        .{.{.NEGATIVE_ONE, .ZERO}, .{.POSITIVE_ONE, .ZERO}},
        .{.{.POSITIVE_ONE, .ZERO}, .{.POSITIVE_ONE, .NEGATIVE_ONE}},
        .{.{.POSITIVE_ONE, .NEGATIVE_ONE}, .{.NEGATIVE_ONE, .NEGATIVE_ONE}},
        .{.{.NEGATIVE_ONE, .NEGATIVE_ONE}, .{.NEGATIVE_ONE, .ZERO}},
        .{.{.NEGATIVE_ONE, .ZERO}, .{.POSITIVE_ONE, .POSITIVE_ONE}},
    ],
    // Digit Seven
    .[
        .{.{.NEGATIVE_ONE, .POSITIVE_ONE}, .{.POSITIVE_ONE, .POSITIVE_ONE}},
        .{.{.POSITIVE_ONE, .POSITIVE_ONE}, .{.NEGATIVE_ONE, .NEGATIVE_ONE}},
    ],
    // Digit Eight
    .[
        .{.{.NEGATIVE_HALF, .ZERO}, .{.NEGATIVE_HALF, .POSITIVE_ONE}},
        .{.{.NEGATIVE_HALF, .POSITIVE_ONE}, .{.POSITIVE_HALF, .POSITIVE_ONE}},
        .{.{.POSITIVE_HALF, .POSITIVE_ONE}, .{.POSITIVE_HALF, .ZERO}},
        .{.{.POSITIVE_ONE, .ZERO}, .{.NEGATIVE_ONE, .ZERO}},
        .{.{.NEGATIVE_ONE, .ZERO}, .{.NEGATIVE_ONE, .NEGATIVE_ONE}},
        .{.{.NEGATIVE_ONE, .NEGATIVE_ONE}, .{.POSITIVE_ONE, .NEGATIVE_ONE}},
        .{.{.POSITIVE_ONE, .NEGATIVE_ONE}, .{.POSITIVE_ONE, .ZERO}},
    ],
    // Digit Nine
    .[
        .{.{.NEGATIVE_ONE, .NEGATIVE_ONE}, .{.POSITIVE_ONE, .ZERO}},
        .{.{.POSITIVE_ONE, .ZERO}, .{.POSITIVE_ONE, .POSITIVE_ONE}},
        .{.{.POSITIVE_ONE, .POSITIVE_ONE}, .{.NEGATIVE_ONE, .POSITIVE_ONE}},
        .{.{.NEGATIVE_ONE, .POSITIVE_ONE}, .{.NEGATIVE_ONE, .ZERO}},
        .{.{.NEGATIVE_ONE, .ZERO}, .{.POSITIVE_ONE, .ZERO}},
    ],
    // Colon
    .[
        .{.{.ZERO, .NEGATIVE_ONE}, .{.ZERO, .NEGATIVE_HALF}},
        .{.{.ZERO, .POSITIVE_HALF}, .{.ZERO, .POSITIVE_ONE}},
    ],
    // Semicolon
    .[
        .{.{.NEGATIVE_HALF, .NEGATIVE_ONE}, .{.ZERO, .NEGATIVE_HALF}},
        .{.{.ZERO, .POSITIVE_HALF}, .{.ZERO, .POSITIVE_ONE}},
    ],
    // Less-than sign
    .[
        .{.{.POSITIVE_ONE, .POSITIVE_HALF}, .{.NEGATIVE_ONE, .ZERO}},
        .{.{.NEGATIVE_ONE, .ZERO}, .{.POSITIVE_ONE, .NEGATIVE_HALF}},
    ],
    // Equal sign
    .[
        .{.{.NEGATIVE_ONE, .POSITIVE_HALF}, .{.POSITIVE_ONE, .POSITIVE_HALF}},
        .{.{.NEGATIVE_ONE, .NEGATIVE_HALF}, .{.POSITIVE_ONE, .NEGATIVE_HALF}},
    ],
    // Greater-than sign
    .[
        .{.{.NEGATIVE_ONE, .POSITIVE_HALF}, .{.POSITIVE_ONE, .ZERO}},
        .{.{.POSITIVE_ONE, .ZERO}, .{.NEGATIVE_ONE, .NEGATIVE_HALF}},
    ],
    // Question mark
    .[
        .{.{.NEGATIVE_ONE, .POSITIVE_ONE}, .{.POSITIVE_ONE, .POSITIVE_ONE}},
        .{.{.POSITIVE_ONE, .POSITIVE_ONE}, .{.POSITIVE_ONE, .POSITIVE_HALF}},
        .{.{.POSITIVE_ONE, .POSITIVE_HALF}, .{.ZERO, .POSITIVE_HALF}},
        .{.{.ZERO, .POSITIVE_HALF}, .{.ZERO, .ZERO}},
        .{.{.ZERO, .NEGATIVE_HALF}, .{.ZERO, .NEGATIVE_ONE}},
    ],
    // At sign
    .[
        .{.{.POSITIVE_HALF, .NEGATIVE_HALF}, .{.POSITIVE_HALF, .POSITIVE_HALF}},
        .{.{.POSITIVE_HALF, .POSITIVE_HALF}, .{.NEGATIVE_HALF, .POSITIVE_HALF}},
        .{.{.NEGATIVE_HALF, .POSITIVE_HALF}, .{.NEGATIVE_HALF, .NEGATIVE_HALF}},
        .{.{.NEGATIVE_HALF, .NEGATIVE_HALF}, .{.POSITIVE_ONE, .NEGATIVE_HALF}},
        .{.{.POSITIVE_ONE, .NEGATIVE_HALF}, .{.POSITIVE_ONE, .POSITIVE_ONE}},
        .{.{.POSITIVE_ONE, .POSITIVE_ONE}, .{.NEGATIVE_ONE, .POSITIVE_ONE}},
        .{.{.NEGATIVE_ONE, .POSITIVE_ONE}, .{.NEGATIVE_ONE, .NEGATIVE_ONE}},
        .{.{.NEGATIVE_ONE, .NEGATIVE_ONE}, .{.POSITIVE_ONE, .NEGATIVE_ONE}},
    ],
    // Latin Capital letter A
    .[
        .{.{.NEGATIVE_ONE, .NEGATIVE_ONE}, .{.ZERO, .POSITIVE_ONE}},
        .{.{.ZERO, .POSITIVE_ONE}, .{.POSITIVE_ONE, .NEGATIVE_ONE}},
        .{.{.NEGATIVE_HALF, .ZERO}, .{.POSITIVE_HALF, .ZERO}},
    ],
    // Latin Capital letter B
    .[
        .{.{.NEGATIVE_ONE, .ZERO}, .{.POSITIVE_ONE, .ZERO}},
        .{.{.POSITIVE_ONE, .ZERO}, .{.POSITIVE_ONE, .NEGATIVE_ONE}},
        .{.{.POSITIVE_ONE, .NEGATIVE_ONE}, .{.NEGATIVE_ONE, .NEGATIVE_ONE}},
        .{.{.NEGATIVE_ONE, .NEGATIVE_ONE}, .{.NEGATIVE_ONE, .POSITIVE_ONE}},
        .{.{.NEGATIVE_ONE, .POSITIVE_ONE}, .{.POSITIVE_HALF, .POSITIVE_ONE}},
        .{.{.POSITIVE_HALF, .POSITIVE_ONE}, .{.POSITIVE_HALF, .ZERO}},
    ],
    // Latin Capital letter C
    .[
        .{.{.POSITIVE_ONE, .POSITIVE_ONE}, .{.NEGATIVE_ONE, .POSITIVE_ONE}},
        .{.{.NEGATIVE_ONE, .POSITIVE_ONE}, .{.NEGATIVE_ONE, .NEGATIVE_ONE}},
        .{.{.NEGATIVE_ONE, .NEGATIVE_ONE}, .{.POSITIVE_ONE, .NEGATIVE_ONE}},
    ],
    // Latin Capital letter D
    .[
        .{.{.POSITIVE_ONE, .ZERO}, .{.NEGATIVE_ONE, .NEGATIVE_ONE}},
        .{.{.NEGATIVE_ONE, .NEGATIVE_ONE}, .{.NEGATIVE_ONE, .POSITIVE_ONE}},
        .{.{.NEGATIVE_ONE, .POSITIVE_ONE}, .{.POSITIVE_ONE, .POSITIVE_ONE}},
        .{.{.POSITIVE_ONE, .POSITIVE_ONE}, .{.POSITIVE_ONE, .ZERO}},
    ],
    // Latin Capital letter E
    .[
        .{.{.POSITIVE_ONE, .NEGATIVE_ONE}, .{.NEGATIVE_ONE, .NEGATIVE_ONE}},
        .{.{.NEGATIVE_ONE, .NEGATIVE_ONE}, .{.NEGATIVE_ONE, .POSITIVE_ONE}},
        .{.{.NEGATIVE_ONE, .POSITIVE_ONE}, .{.POSITIVE_ONE, .POSITIVE_ONE}},
        .{.{.NEGATIVE_ONE, .ZERO}, .{.POSITIVE_HALF, .ZERO}},
    ],
    // Latin Capital letter F
    .[
        .{.{.NEGATIVE_ONE, .NEGATIVE_ONE}, .{.NEGATIVE_ONE, .POSITIVE_ONE}},
        .{.{.NEGATIVE_ONE, .POSITIVE_ONE}, .{.POSITIVE_ONE, .POSITIVE_ONE}},
        .{.{.NEGATIVE_ONE, .ZERO}, .{.POSITIVE_HALF, .ZERO}},
    ],
    // Latin Capital letter G
    .[
        .{.{.POSITIVE_ONE, .POSITIVE_ONE}, .{.NEGATIVE_ONE, .POSITIVE_ONE}},
        .{.{.NEGATIVE_ONE, .POSITIVE_ONE}, .{.NEGATIVE_ONE, .NEGATIVE_ONE}},
        .{.{.NEGATIVE_ONE, .NEGATIVE_ONE}, .{.POSITIVE_ONE, .NEGATIVE_ONE}},
        .{.{.POSITIVE_ONE, .NEGATIVE_ONE}, .{.POSITIVE_ONE, .ZERO}},
        .{.{.POSITIVE_ONE, .ZERO}, .{.ZERO, .ZERO}},
    ],
    // Latin Capital letter H
    .[
        .{.{.NEGATIVE_ONE, .POSITIVE_ONE}, .{.NEGATIVE_ONE, .NEGATIVE_ONE}},
        .{.{.POSITIVE_ONE, .ZERO}, .{.NEGATIVE_ONE, .ZERO}},
        .{.{.POSITIVE_ONE, .POSITIVE_ONE}, .{.POSITIVE_ONE, .NEGATIVE_ONE}},
    ],
    // Latin Capital letter I
    .[
        .{.{.ZERO, .POSITIVE_ONE}, .{.ZERO, .NEGATIVE_ONE}},
    ],
    // Latin Capital letter J
    .[
        .{.{.NEGATIVE_ONE, .NEGATIVE_HALF}, .{.NEGATIVE_ONE, .NEGATIVE_ONE}},
        .{.{.NEGATIVE_ONE, .NEGATIVE_ONE}, .{.POSITIVE_ONE, .NEGATIVE_ONE}},
        .{.{.POSITIVE_ONE, .NEGATIVE_ONE}, .{.POSITIVE_ONE, .POSITIVE_ONE}},
    ],
    // Latin Capital letter K
    .[
        .{.{.NEGATIVE_ONE, .POSITIVE_ONE}, .{.NEGATIVE_ONE, .NEGATIVE_ONE}},
        .{.{.POSITIVE_ONE, .POSITIVE_ONE}, .{.NEGATIVE_ONE, .ZERO}},
        .{.{.NEGATIVE_ONE, .ZERO}, .{.POSITIVE_ONE, .NEGATIVE_ONE}},
    ],
    // Latin Capital letter L
    .[
        .{.{.NEGATIVE_ONE, .POSITIVE_ONE}, .{.NEGATIVE_ONE, .NEGATIVE_ONE}},
        .{.{.NEGATIVE_ONE, .NEGATIVE_ONE}, .{.POSITIVE_ONE, .NEGATIVE_ONE}},
    ],
    // Latin Capital letter M
    .[
        .{.{.NEGATIVE_ONE, .NEGATIVE_ONE}, .{.NEGATIVE_ONE, .POSITIVE_ONE}},
        .{.{.NEGATIVE_ONE, .POSITIVE_ONE}, .{.ZERO, .ZERO}},
        .{.{.ZERO, .ZERO}, .{.POSITIVE_ONE, .POSITIVE_ONE}},
        .{.{.POSITIVE_ONE, .POSITIVE_ONE}, .{.POSITIVE_ONE, .NEGATIVE_ONE}},
    ],
    // Latin Capital letter N
    .[
        .{.{.NEGATIVE_ONE, .NEGATIVE_ONE}, .{.NEGATIVE_ONE, .POSITIVE_ONE}},
        .{.{.NEGATIVE_ONE, .POSITIVE_ONE}, .{.POSITIVE_ONE, .NEGATIVE_ONE}},
        .{.{.POSITIVE_ONE, .NEGATIVE_ONE}, .{.POSITIVE_ONE, .POSITIVE_ONE}},
    ],
    // Latin Capital letter O
    .[
        .{.{.POSITIVE_ONE, .NEGATIVE_ONE}, .{.NEGATIVE_ONE, .NEGATIVE_ONE}},
        .{.{.NEGATIVE_ONE, .NEGATIVE_ONE}, .{.NEGATIVE_ONE, .POSITIVE_ONE}},
        .{.{.NEGATIVE_ONE, .POSITIVE_ONE}, .{.POSITIVE_ONE, .POSITIVE_ONE}},
        .{.{.POSITIVE_ONE, .POSITIVE_ONE}, .{.POSITIVE_ONE, .NEGATIVE_ONE}},
    ],
    // Latin Capital letter P
    .[
        .{.{.NEGATIVE_ONE, .NEGATIVE_ONE}, .{.NEGATIVE_ONE, .POSITIVE_ONE}},
        .{.{.NEGATIVE_ONE, .POSITIVE_ONE}, .{.POSITIVE_ONE, .POSITIVE_ONE}},
        .{.{.POSITIVE_ONE, .POSITIVE_ONE}, .{.POSITIVE_ONE, .ZERO}},
        .{.{.POSITIVE_ONE, .ZERO}, .{.NEGATIVE_ONE, .ZERO}},
    ],
    // Latin Capital letter Q
    .[
        .{.{.POSITIVE_ONE, .NEGATIVE_ONE}, .{.NEGATIVE_ONE, .NEGATIVE_ONE}},
        .{.{.NEGATIVE_ONE, .NEGATIVE_ONE}, .{.NEGATIVE_ONE, .POSITIVE_ONE}},
        .{.{.NEGATIVE_ONE, .POSITIVE_ONE}, .{.POSITIVE_ONE, .POSITIVE_ONE}},
        .{.{.POSITIVE_ONE, .POSITIVE_ONE}, .{.POSITIVE_ONE, .NEGATIVE_ONE}},
        .{.{.POSITIVE_ONE, .NEGATIVE_ONE}, .{.ZERO, .ZERO}},
    ],
    // Latin Capital letter R
    .[
        .{.{.NEGATIVE_ONE, .NEGATIVE_ONE}, .{.NEGATIVE_ONE, .POSITIVE_ONE}},
        .{.{.NEGATIVE_ONE, .POSITIVE_ONE}, .{.POSITIVE_ONE, .POSITIVE_ONE}},
        .{.{.POSITIVE_ONE, .POSITIVE_ONE}, .{.POSITIVE_ONE, .ZERO}},
        .{.{.POSITIVE_ONE, .ZERO}, .{.NEGATIVE_ONE, .ZERO}},
        .{.{.NEGATIVE_ONE, .ZERO}, .{.POSITIVE_ONE, .NEGATIVE_ONE}},
    ],
    // Latin Capital letter S
    .[
        .{.{.NEGATIVE_ONE, .NEGATIVE_ONE}, .{.POSITIVE_ONE, .NEGATIVE_ONE}},
        .{.{.POSITIVE_ONE, .NEGATIVE_ONE}, .{.POSITIVE_ONE, .ZERO}},
        .{.{.POSITIVE_ONE, .ZERO}, .{.NEGATIVE_ONE, .ZERO}},
        .{.{.NEGATIVE_ONE, .ZERO}, .{.NEGATIVE_ONE, .POSITIVE_ONE}},
        .{.{.NEGATIVE_ONE, .POSITIVE_ONE}, .{.POSITIVE_ONE, .POSITIVE_ONE}},
    ],
    // Latin Capital letter T
    .[
        .{.{.ZERO, .NEGATIVE_ONE}, .{.ZERO, .POSITIVE_ONE}},
        .{.{.NEGATIVE_ONE, .POSITIVE_ONE}, .{.POSITIVE_ONE, .POSITIVE_ONE}},
    ],
    // Latin Capital letter U
    .[
        .{.{.NEGATIVE_ONE, .POSITIVE_ONE}, .{.NEGATIVE_ONE, .NEGATIVE_ONE}},
        .{.{.NEGATIVE_ONE, .NEGATIVE_ONE}, .{.POSITIVE_ONE, .NEGATIVE_ONE}},
        .{.{.POSITIVE_ONE, .NEGATIVE_ONE}, .{.POSITIVE_ONE, .POSITIVE_ONE}},
    ],
    // Latin Capital letter V
    .[
        .{.{.NEGATIVE_ONE, .POSITIVE_ONE}, .{.ZERO, .NEGATIVE_ONE}},
        .{.{.ZERO, .NEGATIVE_ONE}, .{.POSITIVE_ONE, .POSITIVE_ONE}},
    ],
    // Latin Capital letter W
    .[
        .{.{.NEGATIVE_ONE, .POSITIVE_ONE}, .{.NEGATIVE_ONE, .NEGATIVE_ONE}},
        .{.{.NEGATIVE_ONE, .NEGATIVE_ONE}, .{.ZERO, .ZERO}},
        .{.{.ZERO, .ZERO}, .{.POSITIVE_ONE, .NEGATIVE_ONE}},
        .{.{.POSITIVE_ONE, .NEGATIVE_ONE}, .{.POSITIVE_ONE, .POSITIVE_ONE}},
    ],
    // Latin Capital letter X
    .[
        .{.{.POSITIVE_ONE, .POSITIVE_ONE}, .{.NEGATIVE_ONE, .NEGATIVE_ONE}},
        .{.{.NEGATIVE_ONE, .POSITIVE_ONE}, .{.POSITIVE_ONE, .NEGATIVE_ONE}},
    ],
    // Latin Capital letter Y
    .[
        .{.{.NEGATIVE_ONE, .POSITIVE_ONE}, .{.ZERO, .ZERO}},
        .{.{.ZERO, .NEGATIVE_ONE}, .{.ZERO, .ZERO}},
        .{.{.ZERO, .ZERO}, .{.POSITIVE_ONE, .POSITIVE_ONE}},
    ],
    // Latin Capital letter Z
    .[
        .{.{.NEGATIVE_ONE, .POSITIVE_ONE}, .{.POSITIVE_ONE, .POSITIVE_ONE}},
        .{.{.POSITIVE_ONE, .POSITIVE_ONE}, .{.NEGATIVE_ONE, .NEGATIVE_ONE}},
        .{.{.NEGATIVE_ONE, .NEGATIVE_ONE}, .{.POSITIVE_ONE, .NEGATIVE_ONE}},
    ],
    // Left square bracket
    .[
        .{.{.POSITIVE_HALF, .POSITIVE_ONE}, .{.NEGATIVE_HALF, .POSITIVE_ONE}},
        .{.{.NEGATIVE_HALF, .POSITIVE_ONE}, .{.NEGATIVE_HALF, .NEGATIVE_ONE}},
        .{.{.NEGATIVE_HALF, .NEGATIVE_ONE}, .{.POSITIVE_HALF, .NEGATIVE_ONE}},
    ],
    // Backslash
    .[
        .{.{.NEGATIVE_ONE, .POSITIVE_ONE}, .{.POSITIVE_ONE, .NEGATIVE_ONE}},
    ],
    // Right square bracket
    .[
        .{.{.NEGATIVE_HALF, .POSITIVE_ONE}, .{.POSITIVE_HALF, .POSITIVE_ONE}},
        .{.{.POSITIVE_HALF, .POSITIVE_ONE}, .{.POSITIVE_HALF, .NEGATIVE_ONE}},
        .{.{.POSITIVE_HALF, .NEGATIVE_ONE}, .{.NEGATIVE_HALF, .NEGATIVE_ONE}},
    ],
    // Circumflex accent (caret)
    .[
        .{.{.NEGATIVE_HALF, .POSITIVE_HALF}, .{.ZERO, .POSITIVE_ONE}},
        .{.{.ZERO, .POSITIVE_ONE}, .{.POSITIVE_HALF, .POSITIVE_HALF}},
    ],
    // Low line (underscore)
    .[
        .{.{.NEGATIVE_ONE, .NEGATIVE_ONE}, .{.POSITIVE_ONE, .NEGATIVE_ONE}},
    ],
    // Grave accent (backtick)
    .[
        .{.{.NEGATIVE_HALF, .POSITIVE_ONE}, .{.ZERO, .POSITIVE_HALF}},
    ],
    // Latin Small Letter A
    .[
        .{.{.NEGATIVE_HALF, .ZERO}, .{.POSITIVE_HALF, .ZERO}},
        .{.{.POSITIVE_HALF, .ZERO}, .{.POSITIVE_HALF, .NEGATIVE_ONE}},
        .{.{.POSITIVE_HALF, .NEGATIVE_ONE}, .{.NEGATIVE_HALF, .NEGATIVE_ONE}},
        .{.{.NEGATIVE_HALF, .NEGATIVE_ONE}, .{.NEGATIVE_HALF, .NEGATIVE_HALF}},
        .{.{.NEGATIVE_HALF, .NEGATIVE_HALF}, .{.POSITIVE_HALF, .NEGATIVE_HALF}},
    ],
    // Latin Small Letter B
    .[
        .{.{.NEGATIVE_HALF, .POSITIVE_ONE}, .{.NEGATIVE_HALF, .NEGATIVE_ONE}},
        .{.{.NEGATIVE_HALF, .NEGATIVE_ONE}, .{.POSITIVE_HALF, .NEGATIVE_ONE}},
        .{.{.POSITIVE_HALF, .NEGATIVE_ONE}, .{.POSITIVE_HALF, .ZERO}},
        .{.{.POSITIVE_HALF, .ZERO}, .{.NEGATIVE_HALF, .ZERO}},
    ],
    // Latin Small Letter C
    .[
        .{.{.POSITIVE_HALF, .NEGATIVE_ONE}, .{.NEGATIVE_HALF, .NEGATIVE_ONE}},
        .{.{.NEGATIVE_HALF, .NEGATIVE_ONE}, .{.NEGATIVE_HALF, .ZERO}},
        .{.{.NEGATIVE_HALF, .ZERO}, .{.POSITIVE_HALF, .ZERO}},
    ],
    // Latin Small Letter D
    .[
        .{.{.POSITIVE_HALF, .ZERO}, .{.NEGATIVE_HALF, .ZERO}},
        .{.{.NEGATIVE_HALF, .ZERO}, .{.NEGATIVE_HALF, .NEGATIVE_ONE}},
        .{.{.NEGATIVE_HALF, .NEGATIVE_ONE}, .{.POSITIVE_HALF, .NEGATIVE_ONE}},
        .{.{.POSITIVE_HALF, .NEGATIVE_ONE}, .{.POSITIVE_HALF, .POSITIVE_ONE}},
    ],
    // Latin Small Letter E
    .[
        .{.{.NEGATIVE_HALF, .NEGATIVE_HALF}, .{.POSITIVE_HALF, .NEGATIVE_HALF}},
        .{.{.POSITIVE_HALF, .NEGATIVE_HALF}, .{.POSITIVE_HALF, .ZERO}},
        .{.{.POSITIVE_HALF, .ZERO}, .{.NEGATIVE_HALF, .ZERO}},
        .{.{.NEGATIVE_HALF, .ZERO}, .{.NEGATIVE_HALF, .NEGATIVE_ONE}},
        .{.{.NEGATIVE_HALF, .NEGATIVE_ONE}, .{.POSITIVE_HALF, .NEGATIVE_ONE}},
    ],
    // Latin Small Letter F
    .[
        .{.{.POSITIVE_ONE, .POSITIVE_HALF}, .{.ZERO, .POSITIVE_HALF}},
        .{.{.ZERO, .POSITIVE_HALF}, .{.ZERO, .NEGATIVE_ONE}},
        .{.{.NEGATIVE_HALF, .ZERO}, .{.POSITIVE_HALF, .ZERO}},
    ],
    // Latin Small Letter G
    .[
        .{.{.NEGATIVE_HALF, .NEGATIVE_ONE}, .{.POSITIVE_HALF, .NEGATIVE_ONE}},
        .{.{.POSITIVE_HALF, .NEGATIVE_ONE}, .{.POSITIVE_HALF, .ZERO}},
        .{.{.POSITIVE_HALF, .ZERO}, .{.NEGATIVE_HALF, .ZERO}},
        .{.{.NEGATIVE_HALF, .ZERO}, .{.NEGATIVE_HALF, .NEGATIVE_HALF}},
        .{.{.NEGATIVE_HALF, .NEGATIVE_HALF}, .{.POSITIVE_HALF, .NEGATIVE_HALF}},
    ],
    // Latin Small Letter H
    .[
        .{.{.NEGATIVE_HALF, .NEGATIVE_ONE}, .{.NEGATIVE_HALF, .POSITIVE_ONE}},
        .{.{.NEGATIVE_HALF, .ZERO}, .{.POSITIVE_HALF, .ZERO}},
        .{.{.POSITIVE_HALF, .ZERO}, .{.POSITIVE_HALF, .NEGATIVE_ONE}},
    ],
    // Latin Small Letter I
    .[
        .{.{.ZERO, .NEGATIVE_ONE}, .{.ZERO, .ZERO}},
        .{.{.ZERO, .POSITIVE_ONE}, .{.ZERO, .POSITIVE_HALF}},
    ],
    // Latin Small Letter J
    .[
        .{.{.NEGATIVE_ONE, .NEGATIVE_ONE}, .{.ZERO, .NEGATIVE_ONE}},
        .{.{.ZERO, .NEGATIVE_ONE}, .{.ZERO, .ZERO}},
        .{.{.ZERO, .POSITIVE_ONE}, .{.ZERO, .POSITIVE_HALF}},
    ],
    // Latin Small Letter K
    .[
        .{.{.NEGATIVE_HALF, .POSITIVE_ONE}, .{.NEGATIVE_HALF, .NEGATIVE_ONE}},
        .{.{.POSITIVE_HALF, .ZERO}, .{.NEGATIVE_HALF, .NEGATIVE_HALF}},
        .{.{.NEGATIVE_HALF, .NEGATIVE_HALF}, .{.POSITIVE_HALF, .NEGATIVE_ONE}},
    ],
    // Latin Small Letter L
    .[
        .{.{.NEGATIVE_HALF, .POSITIVE_ONE}, .{.ZERO, .POSITIVE_ONE}},
        .{.{.ZERO, .POSITIVE_ONE}, .{.ZERO, .NEGATIVE_ONE}},
    ],
    // Latin Small Letter M
    .[
        .{.{.NEGATIVE_ONE, .NEGATIVE_ONE}, .{.NEGATIVE_ONE, .ZERO}},
        .{.{.NEGATIVE_ONE, .ZERO}, .{.POSITIVE_ONE, .ZERO}},
        .{.{.POSITIVE_ONE, .ZERO}, .{.POSITIVE_ONE, .NEGATIVE_ONE}},
        .{.{.ZERO, .ZERO}, .{.ZERO, .NEGATIVE_ONE}},
    ],
    // Latin Small Letter N
    .[
        .{.{.NEGATIVE_HALF, .NEGATIVE_ONE}, .{.NEGATIVE_HALF, .ZERO}},
        .{.{.NEGATIVE_HALF, .ZERO}, .{.POSITIVE_HALF, .ZERO}},
        .{.{.POSITIVE_HALF, .ZERO}, .{.POSITIVE_HALF, .NEGATIVE_ONE}},
    ],
    // Latin Small Letter O
    .[
        .{.{.POSITIVE_HALF, .NEGATIVE_ONE}, .{.POSITIVE_HALF, .ZERO}},
        .{.{.POSITIVE_HALF, .ZERO}, .{.NEGATIVE_HALF, .ZERO}},
        .{.{.NEGATIVE_HALF, .ZERO}, .{.NEGATIVE_HALF, .NEGATIVE_ONE}},
        .{.{.NEGATIVE_HALF, .NEGATIVE_ONE}, .{.POSITIVE_HALF, .NEGATIVE_ONE}},
    ],
    // Latin Small Letter P
    .[
        .{.{.NEGATIVE_HALF, .NEGATIVE_ONE}, .{.NEGATIVE_HALF, .ZERO}},
        .{.{.NEGATIVE_HALF, .ZERO}, .{.POSITIVE_HALF, .ZERO}},
        .{.{.POSITIVE_HALF, .ZERO}, .{.POSITIVE_HALF, .NEGATIVE_HALF}},
        .{.{.POSITIVE_HALF, .NEGATIVE_HALF}, .{.NEGATIVE_HALF, .NEGATIVE_HALF}},
    ],
    // Latin Small Letter Q
    .[
        .{.{.POSITIVE_HALF, .NEGATIVE_HALF}, .{.NEGATIVE_HALF, .NEGATIVE_HALF}},
        .{.{.NEGATIVE_HALF, .NEGATIVE_HALF}, .{.NEGATIVE_HALF, .ZERO}},
        .{.{.NEGATIVE_HALF, .ZERO}, .{.POSITIVE_HALF, .ZERO}},
        .{.{.POSITIVE_HALF, .ZERO}, .{.POSITIVE_HALF, .NEGATIVE_ONE}},
    ],
    // Latin Small Letter R
    .[
        .{.{.NEGATIVE_HALF, .NEGATIVE_ONE}, .{.NEGATIVE_HALF, .ZERO}},
        .{.{.NEGATIVE_HALF, .ZERO}, .{.POSITIVE_HALF, .ZERO}},
    ],
    // Latin Small Letter S
    .[
        .{.{.NEGATIVE_HALF, .NEGATIVE_ONE}, .{.POSITIVE_HALF, .NEGATIVE_ONE}},
        .{.{.POSITIVE_HALF, .NEGATIVE_ONE}, .{.POSITIVE_HALF, .NEGATIVE_HALF}},
        .{.{.POSITIVE_HALF, .NEGATIVE_HALF}, .{.NEGATIVE_HALF, .NEGATIVE_HALF}},
        .{.{.NEGATIVE_HALF, .NEGATIVE_HALF}, .{.NEGATIVE_HALF, .ZERO}},
        .{.{.NEGATIVE_HALF, .ZERO}, .{.POSITIVE_HALF, .ZERO}},
    ],
    // Latin Small Letter T
    .[
        .{.{.ZERO, .POSITIVE_HALF}, .{.ZERO, .NEGATIVE_ONE}},
        .{.{.ZERO, .NEGATIVE_ONE}, .{.POSITIVE_HALF, .NEGATIVE_ONE}},
        .{.{.NEGATIVE_HALF, .ZERO}, .{.POSITIVE_HALF, .ZERO}},
    ],
    // Latin Small Letter U
    .[
        .{.{.NEGATIVE_HALF, .ZERO}, .{.NEGATIVE_HALF, .NEGATIVE_ONE}},
        .{.{.NEGATIVE_HALF, .NEGATIVE_ONE}, .{.POSITIVE_HALF, .NEGATIVE_ONE}},
        .{.{.POSITIVE_HALF, .NEGATIVE_ONE}, .{.POSITIVE_HALF, .ZERO}},
    ],
    // Latin Small Letter V
    .[
        .{.{.NEGATIVE_HALF, .ZERO}, .{.ZERO, .NEGATIVE_ONE}},
        .{.{.ZERO, .NEGATIVE_ONE}, .{.POSITIVE_HALF, .ZERO}},
    ],
    // Latin Small Letter W
    .[
        .{.{.NEGATIVE_ONE, .ZERO}, .{.NEGATIVE_ONE, .NEGATIVE_ONE}},
        .{.{.NEGATIVE_ONE, .NEGATIVE_ONE}, .{.POSITIVE_ONE, .NEGATIVE_ONE}},
        .{.{.POSITIVE_ONE, .NEGATIVE_ONE}, .{.POSITIVE_ONE, .ZERO}},
        .{.{.ZERO, .NEGATIVE_ONE}, .{.ZERO, .ZERO}},
    ],
    // Latin Small Letter X
    .[
        .{.{.POSITIVE_HALF, .ZERO}, .{.NEGATIVE_HALF, .NEGATIVE_ONE}},
        .{.{.NEGATIVE_HALF, .ZERO}, .{.POSITIVE_HALF, .NEGATIVE_ONE}},
    ],
    // Latin Small Letter Y
    .[
        .{.{.NEGATIVE_HALF, .ZERO}, .{.ZERO, .NEGATIVE_HALF}},
        .{.{.NEGATIVE_HALF, .NEGATIVE_ONE}, .{.POSITIVE_HALF, .ZERO}},
    ],
    // Latin Small Letter Z
    .[
        .{.{.NEGATIVE_HALF, .ZERO}, .{.POSITIVE_HALF, .ZERO}},
        .{.{.POSITIVE_HALF, .ZERO}, .{.NEGATIVE_HALF, .NEGATIVE_ONE}},
        .{.{.NEGATIVE_HALF, .NEGATIVE_ONE}, .{.POSITIVE_HALF, .NEGATIVE_ONE}},
    ],
    // Left curly bracket
    .[
        .{.{.POSITIVE_HALF, .POSITIVE_ONE}, .{.ZERO, .POSITIVE_ONE}},
        .{.{.ZERO, .POSITIVE_ONE}, .{.ZERO, .POSITIVE_HALF}},
        .{.{.ZERO, .POSITIVE_HALF}, .{.NEGATIVE_HALF, .ZERO}},
        .{.{.NEGATIVE_HALF, .ZERO}, .{.ZERO, .NEGATIVE_HALF}},
        .{.{.ZERO, .NEGATIVE_HALF}, .{.ZERO, .NEGATIVE_ONE}},
        .{.{.ZERO, .NEGATIVE_ONE}, .{.POSITIVE_HALF, .NEGATIVE_ONE}},
    ],
    // Vertical bar
    .[
        .{.{.ZERO, .POSITIVE_HALF}, .{.ZERO, .NEGATIVE_HALF}},
    ],
    // Right curly bracket
    .[
        .{.{.NEGATIVE_HALF, .POSITIVE_ONE}, .{.ZERO, .POSITIVE_ONE}},
        .{.{.ZERO, .POSITIVE_ONE}, .{.ZERO, .POSITIVE_HALF}},
        .{.{.ZERO, .POSITIVE_HALF}, .{.POSITIVE_HALF, .ZERO}},
        .{.{.POSITIVE_HALF, .ZERO}, .{.ZERO, .NEGATIVE_HALF}},
        .{.{.ZERO, .NEGATIVE_HALF}, .{.ZERO, .NEGATIVE_ONE}},
        .{.{.ZERO, .NEGATIVE_ONE}, .{.NEGATIVE_HALF, .NEGATIVE_ONE}},
    ],
    // Tilde
    .[
        .{.{.NEGATIVE_ONE, .ZERO}, .{.NEGATIVE_HALF, .POSITIVE_HALF}},
        .{.{.NEGATIVE_HALF, .POSITIVE_HALF}, .{.POSITIVE_HALF, .ZERO}},
        .{.{.POSITIVE_HALF, .ZERO}, .{.POSITIVE_ONE, .POSITIVE_HALF}},
    ],
    // Non-breaking space
    .[]
];