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
public import nice.exception;
public import nice.screen;
public import nice.util;
public import nice.window;

private alias SCREEN = nc.SCREEN;

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
    private:
        bool wasFreed;

    package:
        uint termId;

        uint nextTermId()
        {
            return termId++;
        }

        size_t findScreenIndex(SCREEN *ptr)
        {
            import std.algorithm.searching: countUntil;
            return terms.countUntil!(a => a.getPtr == ptr);
        }

        size_t findScreenIndex(MultiTerm scr)
        {
            import std.algorithm.searching: countUntil;
            return terms.countUntil(scr);
        }

        MultiTerm findScreen(SCREEN *ptr)
        {
            return findScreen(findScreenIndex(ptr));
        }

        MultiTerm findScreen(size_t index)
        {
            return index < 0 ? null : terms[index];
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
            if (wasFreed)
                return;
            foreach (term; terms.retro) {
                term.free();
            }
            wasFreed = true;
        }

        Screen newterm(string termtype, File input, File output)
        {
            if (wasFreed)
                throw new UseAfterFreeException(
                        "Tried to call newterm after freeing the library");
            auto res = new MultiTerm(this, termtype, input, output);
            terms ~= res;
            return res;
        }

}
