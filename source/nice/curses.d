/* Main module.

   Provides Curses, Window and ColorTable classes.

   */

module nice.curses;

import std.uni;

import nc = deimos.ncurses;
public import deimos.ncurses: chtype, wint_t;

public import nice.color_table;
public import nice.config;
public import nice.screen;
public import nice.util;
public import nice.window;

final class CursesMono
{
    public:
        StdTerm term;
        Window stdscr;

        this(CursesConfig config = CursesConfig())
        {
            term = new StdTerm(config);
            stdscr = term.stdscr;
        }

}
