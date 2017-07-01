void main()
{
    import nice.curses;

    auto curses = new Curses(Curses.Config()); /* Using default configuration. */
    int y = curses.lines / 2;
    int x = curses.cols / 2;
    curses.stdscr.addstr(y, x, "Hello, world!");
    curses.stdscr.refresh;
    curses.update;
    curses.stdscr.getch();
}
