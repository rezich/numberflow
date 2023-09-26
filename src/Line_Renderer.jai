RENDER_GLYPH_BACKGROUNDS :: true;




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




Line :: struct {
    MAXIMUM :: 1000;
    COLOR   :: Vector4.{1,1,1,1};
    start: Vector2;
    end:   Vector2;
}
lines: [Line.MAXIMUM] Line;
next_line:  int;
most_lines: int;

push_line :: (point: Vector2) {
    assert(next_line <= Line.MAXIMUM);
    assert(next_line > 0);
    lines[next_line] = .{lines[next_line-1].end, point};
    next_line += 1;
}

push_line :: (start: Vector2, end: Vector2) {
    assert(next_line <= Line.MAXIMUM);
    lines[next_line] = .{start, end};
    next_line += 1;
}

Typesetting :: struct {
    glyph: struct {
        scale:   Vector2 = .{5,9};
        spacing: int     = 1;
        shiver:  int     = 0;
    }
    alignment: enum {LEFT; CENTER; RIGHT;} = .LEFT;
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

    for 0..text.count-1 {
        stroke_point :: (sp: Stroke.Point) -> Vector2 #expand {
            v: Vector2;
            if sp.x == {
                case .NEGATIVE_ONE;  v.x = -`glyph_scale.x;
                case .NEGATIVE_HALF; v.x = round_away_from_zero(-`glyph_scale.x * .5);
                case .ZERO;          v.x = 0;
                case .POSITIVE_HALF; v.x = round_away_from_zero(`glyph_scale.x * .5);
                case .POSITIVE_ONE;  v.x = `glyph_scale.x;
            }
            if sp.y == {
                case .NEGATIVE_ONE;  v.y = -`glyph_scale.y;
                case .NEGATIVE_HALF; v.y = round_away_from_zero(-`glyph_scale.y * .5);
                case .ZERO;          v.y = 0;
                case .POSITIVE_HALF; v.y = round_away_from_zero(`glyph_scale.y * .5);
                case .POSITIVE_ONE;  v.y = `glyph_scale.y;
            }
            return `cursor + v;
        }

        if text[it] == #char "\n" {
            cursor = Vector2.{position.x, cursor.y - (glyph.scale.y+spacing)};
            continue;
        }

        lower_left  := stroke_point(.{.NEGATIVE_ONE, .NEGATIVE_ONE});
        upper_right := stroke_point(.{.POSITIVE_ONE, .POSITIVE_ONE});
        #if RENDER_GLYPH_BACKGROUNDS {
            with_alpha :: (v, a) => Vector4.{v.x,v.y,v.z,a};
            C_BACKGROUND  :: Vector4.{.2,.2,.2,1};
            //C_CENTER      :: Vector4.{ 1, 1, 1,1};
            Simp.set_shader_for_color(enable_blend=true);
            Simp.immediate_quad(lower_left.x, lower_left.y, upper_right.x+1, upper_right.y+1, with_alpha(C_BACKGROUND, 0.2));
            //immediate_pixel_line(.{lower_left.x, cursor.y}, .{upper_right.x, cursor.y}, with_alpha(C_BACKGROUND, 0.2));
            //immediate_pixel_line(.{cursor.x, lower_left.y}, .{cursor.x, upper_right.y}, with_alpha(C_BACKGROUND, 0.2));
            //Simp.immediate_quad(cursor.x, cursor.y, cursor.x+1, cursor.y+1, C_CENTER);
        }

        shiver_offset := ifx shiver != 0
            then floor(Vector2.{-shiver*.5,-shiver*.5} + Vector2.{rng(), rng()} * cast(float) shiver)
            else Vector2.{};
        for FONT[text[it] - FONT_ASCII_OFFSET] {
            push_line(
                stroke_point(it.start) + shiver_offset,
                stroke_point(it.end)   + shiver_offset
            );
        }
        cursor += Vector2.{glyph.scale.x+spacing,0};
    }
}

measure_text :: (text: string, using typesetting: Typesetting = .{}) -> Vector2 {
    handle_end_of_line :: () #expand {
        if `chars_this_line > `max_chars_per_line then `max_chars_per_line = `chars_this_line;
        `chars_this_line = 0;
        `lines += 1;
    }
    lines := 0;
    chars_this_line: int;
    max_chars_per_line: int;
    for 0..text.count-1 {
        if text[it] == #char "\n" {
            handle_end_of_line();
            continue;
        } else chars_this_line += 1;
    }
    handle_end_of_line();
    return measure_text(max_chars_per_line, lines, typesetting);
}

measure_text :: (columns: int, rows: int = 1, using typesetting: Typesetting = .{}) -> Vector2 {
    return Vector2.{
        cast(float) columns * glyph.scale.x + max(columns-1, 0) * cast(float) glyph.spacing,
        cast(float) rows    * glyph.scale.y + max(rows   -1, 0) * cast(float) glyph.spacing
    };
}

render_lines :: () {
    for 0..next_line-1 immediate_pixel_line(lines[it].start, lines[it].end, Line.COLOR);
}

flush_lines :: () { if next_line > most_lines then most_lines = next_line; next_line = 0; }



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