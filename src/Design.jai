NUMBER_IDS :: #code ID :: enum {
    MANA;

    WOOD;
    LUMBER;

    GEMS;

    NONE;
};

NUMBER_TAGS :: #code Tag :: enum {
    MAGICAL;
};

setup :: () {
    define(.MANA, capacity=10,
        .MAGICAL
    );
    unlock(.MANA);
    

    define(.WOOD, capacity=100);
    unlock(.WOOD);
    earn(.WOOD, 37);

    define(.LUMBER, capacity=10);
    unlock(.LUMBER);

    define(.GEMS);
    unlock(.GEMS);
    earn(.GEMS, 123456);

    relate(.{
        output=.{.MANA, 1}
    });
}
