module nice.screen;

import deimos.ncurses;

package alias nc = deimos.ncurses;

import nice.color_table;
import nice.config;
import nice.curses: CursesMono;
import nice.util;
import nice.window;

public abstract class Screen 
{
    /* ---------- Data ---------- */

    private:
        Window[] windows;
        bool echoMode_;

    protected:
        CursesConfig cfg;
        CursesMode curMode;

    public:
        ColorTable colors;

    /* ---------- Customizable behaviour ---------- */

    protected:
        abstract void unsetTerm();
        abstract void finish();
    
    public:
        abstract void setTerm();

    package:
        void unsetTermPkg()
        {
            unsetTerm();
        }

        void finishPkg()
        {
            finish();
        }

    /* ---------- Public API ---------- */

    public:

        /* ---------- Window manipulation ---------- */

        Window newWindow(int nlines, int ncols, int beginY, int beginX)
        {
            return null;
        }

        /* ---------- General commands ---------- */

        void beep()
        {
            setTerm();
            nc.beep();
            unsetTerm();
        }

        void delayOutput(int ms)
        {
            setTerm();
            nc.delay_output(ms);
            unsetTerm();
        }

        void echo(bool set)
        {
            setTerm();
            if (set)
                nc.echo();
            else
                nc.noecho();
            echoMode_ = set;
            unsetTerm();
        }

        void flushInput()
        {
            setTerm();
            nc.flushinp();
            unsetTerm();
        }

        void nap(int ms)
        {
            setTerm();
            nc.napms(ms);
            unsetTerm();
        }

        void nl(bool set)
        {
            setTerm();
            if (set)
                nc.nl();
            else
                nc.nonl();
            unsetTerm();
        }

        void resetTTY()
        {
            setTerm();
            nc.resetty();
            unsetTerm();
        }

        void saveTTY()
        {
            setTerm();
            nc.savetty();
            unsetTerm();
        }

        void setCursor(int level)
        {
            setTerm();
            nc.curs_set(level);
            unsetTerm();
        }

        void setMode(CursesMode mode, int delayForHD = 1)
        {
            setTerm();
            final switch (mode) {
                case CursesMode.cbreak: nc.cbreak(); break;
                case CursesMode.halfdelay: nc.halfdelay(delayForHD); break;
                case CursesMode.normal: break;
                case CursesMode.raw: nc.raw(); break;
            }
            curMode = mode;
            unsetTerm();
        }

        void ungetch(int ch)
        {
            setTerm();
            nc.ungetch(ch);
            unsetTerm();
        }

        void update()
        {
            setTerm();
            nc.doupdate();
            unsetTerm();
        }

        /* ---------- Constants ---------- */

        int lines()
        {
            setTerm();
            scope(exit) unsetTerm();
            return nc.LINES;
        }

        int cols()
        {
            setTerm();
            scope(exit) unsetTerm();
            return nc.COLS;
        }

        int maxColors()
        {
            setTerm();
            scope(exit) unsetTerm();
            return nc.COLORS;
        }

        int maxColorPairs()
        {
            setTerm();
            scope(exit) unsetTerm();
            return nc.COLOR_PAIRS;
        }

        int tabSize()
        {
            setTerm();
            scope(exit) unsetTerm();
            return nc.TABSIZE;
        }

        int escDelay()
        {
            setTerm();
            scope(exit) unsetTerm();
            return nc.ESCDELAY;
        }

        /* ---------- Other queries ---------- */

        int baudrate()
        {
            setTerm();
            scope(exit) unsetTerm();
            return nc.baudrate();
        }

        bool canChangeColor()
        {
            setTerm();
            scope(exit) unsetTerm();
            return nc.can_change_color();
        }

        RGB colorContent(short color)
        {
            setTerm();
            scope(exit) unsetTerm();

            short r, g, b;
            nc.color_content(color, &r, &g, &b);
            return RGB(r, g, b);
        }

        bool echoMode()
        {
            return echoMode_;
        }

        bool hasColors()
        {
            setTerm();
            scope(exit) unsetTerm();
            return nc.has_colors();
        }

        string keyName(int key)
        {
            import std.string: fromStringz;
            setTerm();
            scope(exit) unsetTerm();
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
            cfg = config;
            stdscr = new Window(this, nc.initscr(), config.initKeypad);

            cfg = config;
            if (config.useColors) {
                import std.exception: enforce;
                enforce(has_colors(), "Terminal does not support colors");
                start_color();
                colors = new ColorTable(this, config.useStdColors);
                stdscr.colors = colors;
            }

            echo(!config.disableEcho);
            setMode(config.mode);
            setCursor(config.cursLevel);
            nl(config.nl);
        }

        /* --- Overrides --- */

    public:
        override void setTerm() { }

    protected:
        override void unsetTerm() { }

        override void finish()
        {
            final switch (curMode) {
                case CursesMode.normal: break;
                case CursesMode.cbreak: nc.nocbreak(); break;
                case CursesMode.halfdelay: nc.nocbreak(); break;
                case CursesMode.raw: nc.noraw(); break;
            }
            if (!echoMode_)
                nc.echo();
            nc.nonl();
            foreach (w; windows)
                w.free();
            stdscr.free();
            nc.endwin();
            nc.doupdate();
        }

}
