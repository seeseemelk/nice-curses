void main()
{
    import nice.curses;

    auto curses = new Curses();
    scope(exit) destroy(curses);
    auto scr = curses.stdscr;
    int lines = scr.height;
    int cols = scr.width;

    scr.timeout(0);
    int fill = 0;
    int max = 10;
    CChar draw = CChar('-');

    /* Draws a simple progress bar, incrementing its value by 1 every 500 
       milliseconds. If the user presses a key, changes displayed portion of 
       the progress bar to be filled with the pressed key. */
    while (true) {
        int baseX = cols / 2 - max / 2;
        int baseY = lines / 2;

        scr.erase;
        scr.addch(baseY, baseX - 1, 'X');
        scr.addch(baseY, baseX + max, 'X');
        scr.addAligned(baseY + 2, "Press any key to change the progress bar", 
                Align.center);
        foreach (i; 0 .. fill) 
            scr.addch(baseY, baseX + i, draw);
        scr.refresh;
        curses.update;
        curses.nap(500);

        try {
            auto newDraw = scr.getwch();
            if (!newDraw.isSpecialKey)
                draw = CChar(newDraw.chr);
        } catch (NCException e) {
            /* No-op. */
        }
        fill++;
        if (fill > max) fill = 0;
    }
}
