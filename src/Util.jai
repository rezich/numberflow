pad_left :: (t: $T, total_length: int, pad_char: u8 = #char " ", allocator := temp) -> string {
    #if T == string str := t;
    else            str := tprint("%", t);

    result := alloc_string(total_length, allocator);
    pad_count := result.count - str.count;
    for 0..(pad_count - 1) result[it] = pad_char;
    memcpy(result.data + pad_count, str.data, str.count);
    return result;
}
pad_right :: (t: $T, total_length: int, pad_char: u8 = #char " ", allocator := temp) -> string {
    #if T == string str := t;
    else            str := tprint("%", t);

    result := alloc_string(total_length, allocator);
    memcpy(result.data, str.data, str.count);
    for str.count..(result.count - 1) result[it] = pad_char;
    return result;
}
enum_longest_name_count :: ($T: Type) -> int {
    longest := 0;
    for enum_names(T) if it.count > longest then longest = it.count;
    return longest;
}

/////////////////////
// Simp extensions //
/////////////////////

// super inefficient but whatever for now
immediate_line :: (start: Vector2, end: Vector2, breadth: float, color: Vector4) {
    normalized := unit_vector(end-start);
    rotated_left, rotated_right := normalized;
    rotate(*rotated_left, TAU/4);
    rotate(*rotated_right, -TAU/4);
    half_breadth  := breadth/2;
    rotated_left  *= half_breadth;
    rotated_right *= half_breadth;

    Simp.set_shader_for_color(enable_blend=true);
    Simp.immediate_quad(
        start + rotated_left,
        start + rotated_right,
        end   + rotated_right,
        end   + rotated_left,
        color
    );
}

// immediate circle (using immediate lines)
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
