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
    K;

    NONE;
};

NUMBER_TAGS :: #code Tag :: enum {
    VOWEL;
    COOL;
};

setup :: () {
    define(.A, capacity=10,
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
    //unlock(.D);

    define(.E,
        .VOWEL
    );
    //unlock(.E);

    define(.F, capacity=100);
    //unlock(.F);
    earn(.F, 100);

    define(.G);
    //unlock(.G);

    define(.H);
    //unlock(.H);
    earn(.H, 100);

    define(.I,
        .VOWEL
    );
    //unlock(.I);

    define(.J, capacity=1_234);
    //unlock(.J);

    define(.K);
    //unlock(.K);

    relate(.{
        output=.{.A, 1}
    });
    /*relate(.{
        input =.{.A, 1.0},
        output=.{.B, 10}
    });
    relate(.{
        input =.{.A, 2.0},
        output=.{.C, 10}
    });*/
}
