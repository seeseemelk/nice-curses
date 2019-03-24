/* Main module.

   Provides Curses, Window and ColorTable classes.

   */

module nice.curses;

import std.stdio;
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

        void free()
        {
            term.free();
        }

}

final class CursesMulti
{
    package:
        uint termId;

        uint nextTermId()
        {
            return termId++;
        }

    public:
        MultiTerm[] terms;
        CursesConfig config;

        this(CursesConfig cfg = CursesConfig()) 
        {
            config = cfg;
        }

        void free()
        {
            import std.range: retro;
            foreach (term; terms.retro) {
                term.free();
            }
        }

        Screen newterm(string termtype, File input, File output)
        {
            auto res = new MultiTerm(this, termtype, input, output);
            terms ~= res;
            return res;
        }

}
