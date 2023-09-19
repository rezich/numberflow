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
    assert(next_line+1 <= Line.MAXIMUM);
    assert(next_line > 0);
    next_line += 1;
    lines[next_line] = .{lines[next_line-1].end, point};
}

push_line :: (start: Vector2, end: Vector2) {
    assert(next_line+1 <= Line.MAXIMUM);
    next_line += 1;
    lines[next_line] = .{start, end};
}

push_text :: (_origin: Vector2, text: string, scale: Vector2 = .{2,3}, spacing: float = 0, shiver: float = 0) {
    rng :: random_get_zero_to_one;
    origin := _origin;
    for 0..text.count-1 {
        offset := ifx shiver != 0
            then Vector2.{-shiver*0.5,-shiver*.5} + Vector2.{rng(), rng()} * shiver
            else Vector2.{};
        for FONT[text[it] - FONT_ASCII_OFFSET] push_line(
            origin+ it.start*scale +offset,
            origin+ it.end  *scale +offset
        );
        origin += Vector2.{scale.x*2+spacing,0};
    }
}

render_lines :: () {
    for 0..next_line immediate_line(lines[it].start, lines[it].end, 1, Line.COLOR);
}

flush_lines :: () { if next_line-1 > most_lines then most_lines = next_line-1; next_line = 0; }
