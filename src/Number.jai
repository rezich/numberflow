Number :: struct {
    #insert NUMBER_IDS;
    COUNT :: #run enum_highest_value(ID);
    #insert NUMBER_TAGS;

    Relationship :: struct {
        Rate :: struct {
            id:   ID;
            rate: float;
        }
        source:      Rate;
        destination: Rate;
        rate:        float;
    }

    value:    float;
    capacity: float = FLOAT32_INFINITY;
    tags:     [..] Tag;
    //relationships: 
}
