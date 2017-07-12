void main()
{
    import std.range.primitives;
    import std.uni;

    import nice.curses;

    string s = "абвгдеёжзийклмнопрстуфхцчшщъыьэюя";
    auto curses = new Curses();
    scope(exit) destroy(curses);
    auto scr = curses.stdscr;
    int x = scr.width / 2 - (cast(int) s.byGrapheme.walkLength / 2);
    int y = scr.height / 2;

    scr.addnstr(y, x, s, 33);

    scr.refresh;
    curses.update;
    scr.getch;
}
