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

define    :: (id: Number.ID, capacity: float, tags: ..Number.Tag) {
    using state;
    number := *numbers[id];
    number.capacity = capacity;
    number.defined  = true;
    array_add(*number.*.tags, ..tags);
}
define    :: (id: Number.ID, tags: ..Number.Tag) { define(id, capacity=FLOAT32_INFINITY, ..tags); }

relate    :: (relationship: Number.Relationship) -> *Number.Relationship {
    rel := array_add(*state.relationships);
    rel.* = relationship;
    return rel;
}

unlock    :: (id: Number.ID)                        { state.numbers[id].unlocked = true;        }
earn      :: (id: Number.ID, amount: float)         { state.numbers[id].value += amount;        }
spend     :: (id: Number.ID, amount: float)         { earn(id, -amount);                        }
can_spend :: (id: Number.ID, amount: float) -> bool { return state.numbers[id].value >= amount; }
expand    :: (id: Number.ID, amount: float)         { state.numbers[id].capacity += amount;     }
contract  :: (id: Number.ID, amount: float)         {
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
            // this is where there's room for improvement
            total_outputtable_value := state.numbers[id].value + state.numbers[id].rate_this_frame;
            total_desired_rate: float;
            for children {
                capacity := state.numbers[it.relationship.output.id].capacity;
                capacity_minus_value := capacity - state.numbers[it.id].value;
                total_desired_rate += min(it.relationship.input.rate, ifx capacity != FLOAT32_INFINITY then capacity_minus_value else FLOAT32_INFINITY);
            }
            total_desired_rate *= state.time.dt;
            rate_of_actual_ability_to_deliver := min(total_outputtable_value / total_desired_rate, 1);
            for children {
                child_number := *state.numbers[it.id];
                delivery_rate := rate_of_actual_ability_to_deliver;
                if child_number.capacity != FLOAT32_INFINITY {
                    difference_between_value_and_capacity := child_number.capacity-child_number.value;
                    if difference_between_value_and_capacity > 0 {
                        rate_to_fill := difference_between_value_and_capacity / it.relationship.input.rate / it.relationship.output.rate;
                        if rate_to_fill < delivery_rate {
                            delivery_rate = rate_to_fill;
                        }
                    } else delivery_rate = 0;
                }
                state.numbers[it.id].rate_this_frame += it.relationship.output.rate * delivery_rate;
                state.numbers[   id].rate_this_frame -= it.relationship.input .rate * delivery_rate;
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

    for * state.numbers it.rate_this_frame = 0;

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

    //for * state.numbers it.value = min(it.value + it.rate_this_frame, it.capacity);
    for * state.numbers {
        it.value = max(it.value + it.rate_this_frame, 0);
        if it.capacity != FLOAT32_INFINITY then it.value = min(it.value, it.capacity);
    }
}

report_numbers :: () {
    using state;
    PADDING        :: 1;
    ID_WIDTH :: #run enum_longest_name_count(Number.ID) + PADDING;

    for numbers if it.unlocked {
        sb: String_Builder;
        sb.allocator = temp;
        append(*sb, pad_right(cast(Number.ID)it_index, ID_WIDTH));
        format_value(*sb, it.value);
        append(*sb, ifx it.capacity != FLOAT32_INFINITY then " / " else "   ");
        if it.capacity != FLOAT32_INFINITY then format_value(*sb, it.capacity);
        else append(*sb, "         ");
        for 1..PADDING append(*sb, " ");
        format_rate(*sb, it.rate_this_frame);
        append(*sb, "\n");
        print("%", builder_to_string(*sb, temp));
    }
}

check_setup :: () {
    using state;
    for numbers assert(it.defined, "number % is not defined!", cast(Number.ID) it_index);
}

format_value :: (builder: *String_Builder, _value: float) {
    //TODO: Clean up!
    value := _value;
    suffix := "  ";

    suffixes := string.[
        "K ", // 1_000
        "M ", // 1_000_000
        "B ", // 1_000_000_000
        "T ", // 1_000_000_000_000
        "Qa", // 1_000_000_000_000_000
        "Qi", // 1_000_000_000_000_000_000
        "Sx", // 1_000_000_000_000_000_000_000
        "Sp", // 1_000_000_000_000_000_000_000_000
        "O ", // 1_000_000_000_000_000_000_000_000_000
        "N ", // 1_000_000_000_000_000_000_000_000_000_000
        //"D "  // 1_000_000_000_000_000_000_000_000_000_000_000
    ];

    for < suffixes.count-1..0 {
        comparison := pow(10, 3.0 * (it+1));
        if value >= comparison {
            value /= comparison;
            suffix = suffixes[it];
            break;
        }
    }

    print_float(builder, FormatFloat.{
        value=value,
        width=6,
        trailing_width=2,
        zero_removal=.NO
    });
    append(builder, " ");
    append(builder, suffix);
}
format_value :: (value: float) -> string {
    builder: String_Builder;
    builder.allocator = temp;
    format_value(*builder, value);
    return builder_to_string(*builder, allocator=temp);
}
format_rate :: (builder: *String_Builder, rate: float) {
         if rate == 0 then append(builder, "±");
    else if rate <  0 then append(builder, "-");
    else if rate >  0 then append(builder, "+");

    format_value(builder, abs(rate));
}
format_rate :: (rate: float) -> string {
    builder: String_Builder;
    builder.allocator = temp;
    format_rate(*builder, rate);
    return builder_to_string(*builder, allocator=temp);
}

/*
TODO:

clean up format_value()

handle the case where number A flows to B and C, but if C is full, then the
C-flow goes to B instead! (complicated)

*/
