void main()
{
    import nice.curses;

    auto curses = new Curses(Curses.Config()); /* Using default configuration. */
    int y = curses.lines / 2;
    int x = curses.cols / 2;
    string str = "Hello, world!";
    curses.stdscr.addstr(y, cast(int) (x - str.length / 2), str);
    curses.stdscr.refresh;
    curses.update;
    curses.stdscr.getch();
}
