/* Main module.

   Provides Curses, Window and ColorTable classes.

   */

module nice.curses;

import std.uni;

import deimos.ncurses;
public import deimos.ncurses: chtype, wint_t;

package alias nc = deimos.ncurses; /* Just for convenience. */

public import nice.color_table;
public import nice.util;
public import nice.window;

package abstract class CursesBase
{
    private:
        Window[] windows;
        Config cfg;
        Mode curMode;

    public:
        ColorTable colors;
        static bool echoMode = true;

        /* This struct controls initialization and finalization of the library. */
        static struct Config
        {
            bool useColors = true;
            bool useStdColors = true;
            bool disableEcho = false;
            Mode mode = Mode.normal;
            int cursLevel = 1;
            bool initKeypad = true;
            bool nl = false;
            bool nodelay = false;
        }

        static enum Mode
        {
            normal,
            cbreak,
            halfdelay,
            raw,
        }

        /* Initialize the library. */
        this(Config config = Config()) {

        }

        ~this()
        {
            final switch (curMode) {
                case Mode.normal: break;
                case Mode.cbreak: nocbreak(); break;
                case Mode.halfdelay: nocbreak(); break;
                case Mode.raw: noraw(); break;
            }
            if (cfg.disableEcho) echo(true);
            nc.nl();
            endwin();
        }

        /* ---------- window manipulation ---------- */

        Window newWindow(int nlines, int ncols, int begin_y, int begin_x)
        {
            Window res = new Window(this, nlines, ncols, begin_y, begin_x, cfg.initKeypad);
            windows ~= res;
            return res;
        }

        Window duplicateWindow(Window which)
        {
            auto p = dupwin(which.ptr);
            Window res = new Window(this, p, cfg.initKeypad);
            windows ~= res;
            return res;
        }

        void deleteWindow(Window which) 
        {
            import std.algorithm;
            import std.array;
            windows = array(windows.remove!(w => w is which));
        }

        /* ---------- general commands ---------- */

        static void beep()
        {
            nc.beep();
        }

        static void delayOutput(int ms)
        {
            nc.delay_output(ms);
        }

        static void echo(bool set)
        {
            if (set)
                nc.echo();
            else
                nc.noecho();
            Curses.echoMode = set;
        }

        static void flash()
        {
            nc.flash();
        }

        static void flushInput()
        {
            nc.flushinp();
        }

        static void nap(int ms)
        {
            nc.napms(ms);
        }

        static void resetTTY()
        {
            nc.resetty();
        }

        static void saveTTY()
        {
            nc.savetty();
        }

        static void setCursor(int level)
        {
            nc.curs_set(level);
        }

        void setMode(Mode mode, int delayForHD = 1)
        {
            final switch (mode) {
                case Mode.normal: break;
                case Mode.cbreak: nc.cbreak(); break;
                case Mode.halfdelay: nc.halfdelay(delayForHD); break;
                case Mode.raw: nc.raw(); break;
            }
            curMode = mode;
        }

        static void ungetch(int ch)
        {
            nc.ungetch(ch);
        }

        static void update()
        {
            nc.doupdate();
        }

        /* ---------- some constants ---------- */

        static int lines()
        {
            return nc.LINES;
        }

        static int cols()
        {
            return nc.COLS;
        }

        static int maxColors()
        {
            return nc.COLORS;
        }

        static int maxColorPairs()
        {
            return nc.COLOR_PAIRS;
        }

        static int tabSize()
        {
            return nc.TABSIZE;
        }

        static int escDelay()
        {
            return nc.ESCDELAY;
        }

        /* ---------- information retrieval ---------- */

        static int baudrate()
        {
            return nc.baudrate();
        }

        static bool canChangeColor()
        {
            return nc.can_change_color();
        }

        static RGB colorContent(short color)
        {
            short r, g, b;
            color_content(color, &r, &g, &b);
            return RGB(r, g, b);
        }

        static bool hasColors()
        {
            return nc.has_colors();
        }

        static string keyName(int key)
        {
            import std.string;
            return nc.keyname(key).fromStringz.idup;
        }
}

final class Curses: CursesBase
{
    public:
        Window stdscr;

        this(Config config = Config())
        {
            import core.stdc.locale: LC_ALL, setlocale;
            cfg = config;
            setlocale(LC_ALL, "");

            if (config.useColors) {
                import std.exception: enforce;
                enforce(has_colors(), "Terminal does not support colors");
                start_color();
                colors = new ColorTable(this, config.useStdColors);
                stdscr.colors = colors;
            }

            if (config.disableEcho) echo(false);
            setMode(config.mode);
            curs_set(config.cursLevel);
            if (config.initKeypad) stdscr.keypad(true);
            if (config.nl)
                nc.nl();
            else
                nc.nonl();
        }

}
