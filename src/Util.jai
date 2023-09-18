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
