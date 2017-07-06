void main()
{
    /* Someone with a terminal that supports more than 8 colors please check if
       this actually works. */

    import nice.curses;

    auto curses = new Curses();
    scope(exit) destroy(curses);
    auto colors = curses.colors;
    auto scr = curses.stdscr;

    assert(curses.canChangeColor, "Cannot change colors on this terminal");

    chtype[] gradient;
    /* This will prepare a gradient from red to green. */
    short r = 1000;
    short g = 0;
    foreach (i; 0 .. 8) {
        short c = colors.addColor(r, g, 0);
        short pair = colors.addPair(c, StdColor.black);
        gradient ~= colors[pair];
        r = cast(short) (1000 * (8 - i) / 8);
        g = cast(short) (1000 * i / 8);
    }

    /* From green to blue. */
    g = 1000;
    short b = 0;
    foreach (i; 0 .. 8) {
        short c = colors.addColor(0, g, b);
        short pair = colors.addPair(c, StdColor.black);
        gradient ~= colors[pair];
        g = cast(short) (1000 * (8 - i) / 8);
        b = cast(short) (1000 * i / 8);
    }

    /* From blue back to red. */
    b = 1000;
    r = 0;
    foreach (i; 0 .. 8) {
        short c = colors.addColor(r, 0, b);
        short pair = colors.addPair(c, StdColor.black);
        gradient ~= colors[pair];
        b = cast(short) (1000 * (8 - i) / 8);
        r = cast(short) (1000 * i / 8);
    }

    scr.move(0, 0);
    char c = 'a';
    foreach (attr; gradient) {
        scr.addch(c, attr);
    }
    scr.refresh;
    curses.update;
}
