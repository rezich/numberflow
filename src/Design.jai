NUMBER_IDS :: #code ID :: enum {
    A;
    B;
    C;
    D;
    E;
    F;
    G;
    H;
    I;
    J;

    NONE;
};

NUMBER_TAGS :: #code Tag :: enum {
    VOWEL;
    COOL;
};

setup :: () {
    define(.A,
        .VOWEL,
        .COOL
    );
    unlock(.A);

    define(.B, capacity=3);
    unlock(.B);

    define(.C);
    unlock(.C);

    define(.D,
        .COOL
    );
    unlock(.D);

    define(.E,
        .VOWEL
    );
    unlock(.E);

    define(.F);
    unlock(.F);
    earn(.F, 100);

    define(.G);
    unlock(.G);

    define(.H);
    unlock(.H);
    earn(.H, 100);

    define(.I,
        .VOWEL
    );
    unlock(.I);

    define(.J);
    unlock(.J);

    relate(.{
        output=.{.A, 0.2}
    });
    relate(.{
        input =.{.A, 0.1},
        output=.{.B, 0.5}
    });
    relate(.{
        input =.{.A, 0.05},
        output=.{.C, 1}
    });
    relate(.{
        input =.{.C, 0.01},
        output=.{.D, 1}
    });
    relate(.{
        output=.{.D, 0.1}
    });
    relate(.{
        output=.{.E, 1}
    });
    relate(.{
        input =.{.F, 1},
        output=.{.G, 1}
    });
    relate(.{
        input =.{.G, 0.1},
        output=.{.I, 0.1}
    });
    relate(.{
        input =.{.H, 1},
        output=.{.J, 1}
    });
}
