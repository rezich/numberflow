NUMBER_IDS :: #code ID :: enum {
    A;
    B;

    NONE;
};

NUMBER_TAGS :: #code Tag :: enum {

};

state: struct {
    time: struct {
        t:  float;
        dt: float;
    }
    numbers: [Number.COUNT] Number;
    relationships: [..] Number.Relationship;
}

setup :: () {
    using state;

    define(.A);
    define(.B, capacity=3);

    log("%", numbers.count);
}

simulate_numbers :: () {
    using state;
    
}




#scope_file

define :: (id: Number.ID, capacity: float, tags: ..Number.Tag) {
    using state;
    number := *numbers[id];
    number.capacity = capacity;
    array_add(*number.*.tags, ..tags);
}

define :: (id: Number.ID, tags: ..Number.Tag) {
    define(id, capacity=FLOAT32_INFINITY, ..tags);
}

relate :: (relationship: Number.Relationship) {
    array_add(*state.relationships, relationship);
    //new_index := state.relationships.count-1;
    //if relationship.source.id != .NONE then array_add(*numbers[relationship.source.id])
}
