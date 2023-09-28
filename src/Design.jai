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

SCREEN_ID :: enum {
    HOME;
    UPGRADES;
    DEFRAG;

    META;
};

state: struct {
    time: struct { t:  float; dt: float; }
    numbers: [Number.COUNT] Number;
    relationships: [..] Number.Relationship;
    screen: struct {
        current:    SCREEN_ID;
        previous:   SCREEN_ID;
        transition: float = 1;
    }
}

setup :: () {
    // Screens
    define(.HOME, .{0,0});
    unlock(.HOME);

    define(.UPGRADES, .{1,0});
    unlock(.UPGRADES);

    define(.META, .{0,0});
    unlock(.META);



    // Numbers
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
