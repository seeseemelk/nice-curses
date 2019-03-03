module tests.basic;

import dunit;
import nice.curses;

class BasicTests
{
    mixin UnitTest;

    @Test
    public void testAddch()
    {
        auto curses = new CursesMono();
        scope(exit) curses.finish();
        auto scr = curses.stdscr;

        scr.addch(10, 10, 'a');
        scr.refresh();
        curses.term.update();

        auto chars = scr.inchstr(10, 10, 1);
        scr.clear();
        scr.refresh();
        curses.term.update();

        assertEquals(chars, ['a']);
    }
}

mixin Main;
