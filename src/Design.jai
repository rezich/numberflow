NUMBER_IDS :: #code ID :: enum {
    WOOD;
    LUMBER;

    NONE;
};

NUMBER_TAGS :: #code Tag :: enum {
    VOWEL;
    COOL;
};

setup :: () {
    define(.WOOD, capacity=10,
        .VOWEL,
        .COOL
    );
    unlock(.WOOD);
    //earn(.WOOD, 100);

    define(.LUMBER, capacity=10);
    //unlock(.LUMBER);

    relate(.{
        output=.{.WOOD, 1}
    });
    relate(.{
        input =.{.WOOD,   2},
        output=.{.LUMBER, 1}
    });
}
