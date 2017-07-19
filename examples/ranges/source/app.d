void main()
{
    import std.algorithm;
    import std.range;
    import std.uni;

    import nice.curses;

    auto curses = new Curses();
    scope(exit) destroy(curses);
    auto scr = curses.stdscr;

    auto a = "adsf".map!(c => c.toUpper);
    auto b = "qwer"w.map!(c => c.toUpper);
    auto c = "фыва"d.map!(c => c.toUpper);

    auto attrs = cycle([Attr.reverse, Attr.normal]);

    /* First overload. */
    scr.addnstr(0, 0, a, 4, attrs);
    scr.addnstr(1, 0, b, 3, attrs);
    scr.addnstr(2, 0, c, 2, attrs);

    /* Second overload. These should be printed on the same line. */
    scr.move(3, 0);
    scr.addnstr(a, 4, attrs);
    scr.addnstr(b, 3, attrs);
    scr.addnstr(c, 2, attrs);

    /* Third overload. */
    scr.addnstr(4, 0, a, 3, Attr.normal);
    scr.addnstr(5, 0, b, 3, Attr.reverse);
    scr.addnstr(6, 0, c, 3, Attr.normal);

    /* 4th overload. */
    scr.move(7, 0);
    scr.addnstr(a, 4, Attr.normal);
    scr.addnstr(b, 4, Attr.reverse);
    scr.addnstr(c, 4, Attr.normal);

    /* 5th overload. */
    scr.addstr(8, 0, a, attrs);
    scr.addstr(9, 0, b, attrs);
    scr.addstr(10, 0, c, attrs);

    /* 6th overload. These should be printed on the same line. */
    scr.move(0, 30);
    scr.addstr(a, attrs);
    scr.addstr(b, attrs);
    scr.addstr(c, attrs);

    /* 7th overload. */
    scr.addstr(1, 30, a, Attr.reverse);
    scr.addstr(2, 30, b, Attr.normal);
    scr.addstr(3, 30, c, Attr.reverse);

    /* 8th overload. These should be printed on the same line. */
    scr.move(4, 30);
    scr.addstr(a, Attr.normal);
    scr.addstr(b, Attr.reverse);
    scr.addstr(c, Attr.normal);

    /* Now for addAligned. */

    /* First overload. */
    scr.addAligned(5, 30, a, Align.left, attrs);
    scr.addAligned(6, 30, b, Align.left, attrs);
    scr.addAligned(7, 30, c, Align.left, attrs);

    /* Second overload. */
    scr.addAligned(8, 30, a, Align.left, Attr.normal);
    scr.addAligned(9, 30, b, Align.left, Attr.reverse);
    scr.addAligned(10, 30, c, Align.left, Attr.normal);

    /* Third overload. */
    scr.addAligned(12, a, Align.center, attrs);
    scr.addAligned(13, b, Align.center, attrs);
    scr.addAligned(14, c, Align.center, attrs);

    /* Last overload. */
    scr.addAligned(15, a, Align.center, Attr.normal);
    scr.addAligned(16, b, Align.center, Attr.reverse);
    scr.addAligned(17, c, Align.center, Attr.normal);

    scr.refresh;
    curses.update;
}
