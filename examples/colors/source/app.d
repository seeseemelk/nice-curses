void main()
{
    import nice.curses;

    auto curses = new Curses();
    auto scr = curses.stdscr;
    auto colors = curses.colors;

    auto red = colors[StdColor.red, StdColor.black];
    auto blue = colors[StdColor.blue, StdColor.black];

    scr.addstr(0, 0, "This should be red", red);
    scr.addstr(1, 0, "This letter should be blue: ");
    scr.addch(CChar("A", blue));

    scr.refresh;
    curses.update;
    scr.getch;
}
