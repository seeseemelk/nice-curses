module nice.screen;

import std.stdio;

import nc = deimos.ncurses;

import nice.color_table;
import nice.config;
import nice.curses: CursesMono, CursesMulti;
import nice.exception;
import nice.util;
import nice.window;

private alias SCREEN = nc.SCREEN;

public abstract class Screen 
{
    /* ---------- Data ---------- */

    private:
        Window[] windows;
        bool echoMode_;
        uint windowId;

    protected:
        const SCREEN *ptr;
        CursesConfig cfg;
        CursesMode curMode;
        bool wasFreed;

    public:
        immutable uint id;
        ColorTable colors;

    /* ---------- Customizable behaviour ---------- */

        abstract void free();
        abstract Screen setTerm();

    /* ---------- Helpers ---------- */

        override bool opEquals(const Object other) const
        {
            if (this is other)
                return true;
            if (typeid(this) == typeid(other)) {
                Screen otherScr = cast(Screen) other;
                return this.ptr == otherScr.ptr;
            }
            return false;
        }

    package:

        this(uint id, CursesConfig cfg, SCREEN *ptr)
        {
            this.id = id;
            this.ptr = ptr;
            this.cfg = cfg;
        }

        uint nextWindowId()
        {
            return windowId++;
        }

        void setupColors()
        {
            if (cfg.useColors) {
                import std.exception: enforce;
                enforce(nc.has_colors(), "Terminal does not support colors");
                nc.start_color();
                colors = new ColorTable(this, cfg.useStdColors);
            }
        }

        void initialSetup()
        {
            echo(!cfg.disableEcho);
            setMode(cfg.mode);
            setCursor(cfg.cursLevel);
            nl(cfg.nl);
        }

        void clearWindows()
        {
            foreach (w; windows)
                w.free();
            windows = [];
        }

        const (SCREEN *) getPtr() const 
        {
            return ptr;
        }

    /* ---------- Public API ---------- */

        /* ---------- Really important things ---------- */

    public:

        bool isValid() 
        {
            return !wasFreed;
        }

        void throwUnlessValid() 
        {
            if (wasFreed) {
                throw new UseAfterFreeException(
                        "Screen with id %s was used after it was freed",
                        id);
            }
        }

        /* ---------- Window manipulation ---------- */

        Window newWindow(int nlines, int ncols, int beginY, int beginX)
        {
            mixin(switchTerms);
            WINDOW *winptr = nc.newwin(nlines, ncols, beginY, beginX);
            if (winptr is null)
                throw new NCException(
                        "Failed to create a new window in terminal %s", id);
            return new Window(this, winptr, this.cfg.initKeypad);
        }

        void deleteWindow(Window win)
        {
            import std.algorithm: countUntil, remove;
            throwUnlessValid();
            win.free();
            auto index = windows.countUntil(win);
            if (index >= 0)
                windows.remove(index);
        }

        /* ---------- General commands ---------- */

        void beep()
        {
            mixin(switchTerms);
            nc.beep();
        }

        void delayOutput(int ms)
        {
            mixin(switchTerms);
            nc.delay_output(ms);
        }

        void echo(bool set)
        {
            mixin(switchTerms);
            if (set)
                nc.echo();
            else
                nc.noecho();
            echoMode_ = set;
        }

        void flushInput()
        {
            mixin(switchTerms);
            nc.flushinp();
        }

        void nap(int ms)
        {
            mixin(switchTerms);
            nc.napms(ms);
        }

        void nl(bool set)
        {
            mixin(switchTerms);
            if (set)
                nc.nl();
            else
                nc.nonl();
        }

        void resetTTY()
        {
            mixin(switchTerms);
            nc.resetty();
        }

        void saveTTY()
        {
            mixin(switchTerms);
            nc.savetty();
        }

        void setCursor(int level)
        {
            mixin(switchTerms);
            nc.curs_set(level);
        }

        void setMode(CursesMode mode, int delayForHD = 1)
        {
            mixin(switchTerms);
            final switch (mode) {
                case CursesMode.cbreak: nc.cbreak(); break;
                case CursesMode.halfdelay: nc.halfdelay(delayForHD); break;
                case CursesMode.normal: break;
                case CursesMode.raw: nc.raw(); break;
            }
            curMode = mode;
        }

        void ungetch(int ch)
        {
            mixin(switchTerms);
            nc.ungetch(ch);
        }

        void update()
        {
            mixin(switchTerms);
            nc.doupdate();
        }

        /* ---------- Constants ---------- */

        int lines()
        {
            mixin(switchTerms);
            return nc.LINES;
        }

        int cols()
        {
            mixin(switchTerms);
            return nc.COLS;
        }

        int maxColors()
        {
            mixin(switchTerms);
            return nc.COLORS;
        }

        int maxColorPairs()
        {
            mixin(switchTerms);
            return nc.COLOR_PAIRS;
        }

        int tabSize()
        {
            mixin(switchTerms);
            return nc.TABSIZE;
        }

        int escDelay()
        {
            mixin(switchTerms);
            return nc.ESCDELAY;
        }

        /* ---------- Other queries ---------- */

        int baudrate()
        {
            mixin(switchTerms);
            return nc.baudrate();
        }

        bool canChangeColor()
        {
            mixin(switchTerms);
            return nc.can_change_color();
        }

        RGB colorContent(short color)
        {
            mixin(switchTerms);
            short r, g, b;
            nc.color_content(color, &r, &g, &b);
            return RGB(r, g, b);
        }

        bool echoMode()
        {
            mixin(switchTerms);
            return echoMode_;
        }

        bool hasColors()
        {
            mixin(switchTerms);
            return nc.has_colors();
        }

        string keyName(int key)
        {
            import std.string: fromStringz;
            mixin(switchTerms);
            char* res = nc.keyname(key);
            if (res == null)
                throw new NCException("Unknown key %s", key);
            return res.fromStringz.idup;
        }

}

package final class StdTerm: Screen
{
    package:
        Window stdscr;

        this(CursesConfig config) 
        {
            super(0, config, null);
            WINDOW *scr = nc.initscr();
            if (scr is null) {
                throw new NCException("Failed to initialize ncurses library");
            }
            initialSetup();
            setupColors();
            stdscr = new Window(this, scr, config.initKeypad);
        }

        /* --- Overrides --- */

    public:
        override Screen setTerm() 
        {
            throwUnlessValid();
            return this;
        }

        override void free()
        {
            if (wasFreed)
                return;
            clearWindows();
            stdscr.free(true);
            nc.doupdate();
            nc.endwin();
            wasFreed = true;
        }

}

package final class MultiTerm: Screen
{
    private:
        File input;
        File output;
        CursesMulti curses;

    package:

        this(CursesMulti curses, string termtype, File input, File output) 
        {
            import std.string: toStringz;
            SCREEN *ptr = nc.newterm(cast(char *) termtype.toStringz, 
                    input.getFP, 
                    output.getFP);
            if (ptr is null) {
                throw new NCException("Failed to create a new terminal");
            }
            super(curses.nextTermId, curses.config, ptr);
            this.curses = curses;
            this.input = input;
            this.output = output;
            initialSetup();
            setupColors();
        }

    public:

        override Screen setTerm()
        {
            import std.algorithm.searching: find;
            throwUnlessValid();
            SCREEN *oldPtr = nc.set_term(cast(SCREEN *) ptr);
            return curses.findScreen(oldPtr);
        }

        override void free()
        {
            import std.algorithm.mutation: remove;
            if (wasFreed)
                return;
            mixin(switchTerms);
            clearWindows();
            nc.endwin();
            nc.delscreen(cast(SCREEN *) ptr);
            curses.terms.remove(curses.findScreenIndex(this));
            wasFreed = true;
        }

}

package string
switchTerms(string cur = "this") pure
{
    string set = "Screen old = " ~ cur ~ ".setTerm();\n";
    string unset = "scope(exit) { if (old !is null) old.setTerm(); }";
    return set ~ unset;
}
