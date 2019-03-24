module tests.basic;

import dunit;
import nice.curses;

private class SanityTests
{
    mixin UnitTest;

    @Test
    public void canInitAfterFree()
    {
        auto first = new CursesMono();
        first.free();

        auto second = new CursesMono();
        second.free();
    }

    @Test
    public void useAfterFreeFails1()
    {
        auto curses = new CursesMono();

        curses.free();
        expectThrows!(UseAfterFreeException)(curses.term.newWindow(0, 0, 0, 0));
    }

    @Test
    public void useAfterFreeFails2()
    {
        auto curses = new CursesMono();
        scope(exit) curses.free();
        auto win = curses.term.newWindow(0, 0, 0, 0);
        curses.term.deleteWindow(win);
        expectThrows!(UseAfterFreeException)(win.addch('a'));
    }

}

private class BasicTests
{
    mixin UnitTest;

    @Test
    public void testAddch()
    {
        auto curses = new CursesMono();
        scope(exit) curses.free();
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
