Number :: struct {
    #insert NUMBER_IDS;
    COUNT :: #run enum_highest_value(ID);
    #insert NUMBER_TAGS;

    Rate :: struct {
        id:   ID    = .NONE;
        rate: float = FLOAT32_INFINITY;
    }

    Relationship :: struct {
        input:  Rate;
        output: Rate;
    }

    value:    float;
    capacity: float = FLOAT32_INFINITY;
    tags:     [..] Tag;
    defined:  bool;
    unlocked: bool;
    rate_this_frame: float;
}

define :: (id: Number.ID, capacity: float, tags: ..Number.Tag) {
    using state;
    number := *numbers[id];
    number.capacity = capacity;
    number.defined  = true;
    array_add(*number.*.tags, ..tags);
}
define :: (id: Number.ID, tags: ..Number.Tag) { define(id, capacity=FLOAT32_INFINITY, ..tags); }

relate :: (relationship: Number.Relationship) { array_add(*state.relationships, relationship); }

unlock :: (id: Number.ID) { state.numbers[id].unlocked = true; }
earn :: (id: Number.ID, amount: float) { state.numbers[id].value += amount; }
spend :: (id: Number.ID, amount: float) { earn(id, -amount); }
can_spend :: (id: Number.ID, amount: float) -> bool { return state.numbers[id].value >= amount; }
expand :: (id: Number.ID, amount: float) { state.numbers[id].capacity += amount; }
contract :: (id: Number.ID, amount: float) {
    assert(state.numbers[id].capacity - amount > 0);
    expand(id, -amount);
}


simulate_number_flow :: () {
    Flow_Node :: struct {
        id: Number.ID;
        relationship: *Number.Relationship;
        children: [..] Flow_Node;
    }
    make_flow_node :: (id: Number.ID, relationship: *Number.Relationship = null) -> Flow_Node {
        flow_node := Flow_Node.{id = id, relationship = relationship};
        flow_node.children.allocator = temp;
        return flow_node;
    }
    find_flow_node_from_root :: (id: Number.ID, root_flow_nodes: [] Flow_Node) -> *Flow_Node {
        find_flow_node :: (id: Number.ID, parent: *Flow_Node) -> *Flow_Node {
            if parent.id == id then return parent;
            for * parent.children {
                if it.id == id then return it;
                found_child := find_flow_node(id, it);
                if found_child then return found_child;
            }
            return null;
        }
        for * root_flow_nodes {
            found_node := find_flow_node(id, it);
            if found_node then return found_node;
        }
        return null;
    }
    flow :: (using flow_node: Flow_Node) {
        if id == .NONE {
            for children state.numbers[it.id].rate_this_frame += it.relationship.output.rate * state.time.dt;
        }
        else {
            if !state.numbers[id].unlocked then return;
            total_desired_rate: float;
            total_outputtable_value := state.numbers[id].value + state.numbers[id].rate_this_frame;
            for children total_desired_rate += it.relationship.input.rate * state.time.dt;
            output_scale := min(total_outputtable_value / total_desired_rate, 1);
            for children {
                desired_rate := it.relationship.input.rate * state.time.dt * output_scale;
                state.numbers[it.id].rate_this_frame += desired_rate;
                state.numbers[   id].rate_this_frame -= desired_rate;
            }
            
        }
        for children flow(it);
    }
    report_flow_nodes :: (root_flow_nodes: [] Flow_Node) {
        report_flow_node :: (using flow_node: Flow_Node, indent: int = 0) {
            for 0..indent-1 print("  ");
            print("%\n", id);
            for * children report_flow_node(it, indent+1);
        }
        for root_flow_nodes report_flow_node(it);
    }

    root_flow_nodes: [..] Flow_Node;
    root_flow_nodes.allocator = temp;
    array_add(*root_flow_nodes, make_flow_node(.NONE));

    for * state.numbers { it.rate_this_frame = 0; }

    unflowed_relationships: [..] *Number.Relationship;
    unflowed_relationships.allocator = temp;
    for * state.relationships array_add(*unflowed_relationships, it);

    previous_unflowed_relationships_count: int;
    while unflowed_relationships.count > 0 {
        if previous_unflowed_relationships_count == unflowed_relationships.count {
            root_flow_node := make_flow_node(unflowed_relationships[0].input.id);
            array_add(*root_flow_node.children, make_flow_node(unflowed_relationships[0].output.id, unflowed_relationships[0]));
            array_add(*root_flow_nodes, root_flow_node);
            array_unordered_remove_by_index(*unflowed_relationships, 0);
            continue;
        }
        previous_unflowed_relationships_count = unflowed_relationships.count;
        for unflowed_relationship: unflowed_relationships {
            found_node := find_flow_node_from_root(unflowed_relationship.input.id, root_flow_nodes);
            if found_node {
                array_add(*found_node.children, make_flow_node(unflowed_relationship.output.id, unflowed_relationship));
                remove unflowed_relationship;
                continue;
            }
            found_unflowed_parent: *Number.Relationship;
            for unflowed_relationships {
                if it == unflowed_relationship then continue;
                if it.output.id == unflowed_relationship.output.id {
                    found_unflowed_parent = it;
                    break;
                }
            }
        }
    }

    //report_flow_nodes(root_flow_nodes);
    for root_flow_nodes flow(it);

    for * state.numbers it.value += it.rate_this_frame;
}

report_numbers :: () {
    using state;
    PADDING        :: 1;
    VALUE_WIDTH    :: 7;
    CAPACITY_WIDTH :: 11;
    RATE_WIDTH     :: 6;
    ID_WIDTH :: #run enum_longest_name_count(Number.ID) + PADDING;

    for numbers if it.unlocked {
        /*id := pad_right(cast(Number.ID)it_index, id_width);
        value := pad_left(format_value(it.value), VALUE_WIDTH);
        capacity := pad_right(ifx it.capacity != FLOAT32_INFINITY then tprint(" / %", format_value(it.capacity)), CAPACITY_WIDTH);
        rate_is_positive := it.rate_this_frame >= 0;
        rate := tprint("%1%2/s", ifx rate_is_positive then " ", pad_right(it.rate_this_frame, RATE_WIDTH - ifx rate_is_positive then 1));
        log("%1%2%3%4", id, value, capacity, rate);*/

        sb: String_Builder;
        sb.allocator = temp;
        append(*sb, pad_right(cast(Number.ID)it_index, ID_WIDTH));
        //append(*sb, "| ");
        append(*sb, format_value(it.value));
        append(*sb, ifx it.capacity != FLOAT32_INFINITY then " / " else "   ");
        append(*sb, ifx it.capacity != FLOAT32_INFINITY then format_value(it.capacity) else "       ");
        append(*sb, "  ");
        append(*sb, format_rate(it.rate_this_frame));
        append(*sb, "\n");
        print("%", builder_to_string(*sb, temp));
    }
}

check_setup :: () {
    using state;
    for numbers assert(it.defined, "number % is not defined!", cast(Number.ID) it_index);
}

format_value :: (_value: float, $USE_LEADING_SPACES := true, $USE_TRAILING_SPACES := true) -> string {
    value := _value;
    suffix := "";
    space := false;
    decimals := 2;

    suffixes := string.[
        "K",  // 1_000
        "M",  // 1_000_000
        "B",  // 1_000_000_000
        "T",  // 1_000_000_000_000
        "Qa", // 1_000_000_000_000_000
        "Qi", // 1_000_000_000_000_000_000
        "Sx", // 1_000_000_000_000_000_000_000
        "Sp", // 1_000_000_000_000_000_000_000_000
        "O",  // 1_000_000_000_000_000_000_000_000_000
        "N",  // 1_000_000_000_000_000_000_000_000_000_000
        "D"   // 1_000_000_000_000_000_000_000_000_000_000_000
    ];
    MAX_SUFFIX_LENGTH :: 2;

    for < suffixes.count-1..0 {
        comparison := pow(10, 3.0 * (it+1));
        if value >= comparison {
            value /= comparison;
            suffix = suffixes[it];
            break;
        }
    }

    if value >= 100 {
        decimals = 0;
        #if USE_LEADING_SPACES then space = true;
    }
    else if value >= 10 {
        decimals = 1;
    }

    sb: String_Builder;
    sb.allocator = temp;
    ff := FormatFloat.{
        value=value,
        trailing_width=decimals,
        zero_removal=.NO
    };
    #if USE_LEADING_SPACES then if value >= 0 append(*sb, " ");
    if space then append(*sb, " ");
    print_float(*sb, ff);
    append(*sb, suffix);
    #if USE_TRAILING_SPACES {
        for 0..MAX_SUFFIX_LENGTH-suffix.count-1 append(*sb, " ");
    }
    return builder_to_string(*sb, temp);
}
format_rate :: (rate: float) -> string {
    formatted := format_value(rate);
    if rate == 0 then formatted.data[0] = #char "±";
    else if rate > 0 then formatted.data[0] = #char "+";
    return formatted;
}
