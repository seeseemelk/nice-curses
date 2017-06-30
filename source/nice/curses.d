/* Main module.

   Provides Curses, Window and ColorTable classes.

   */

module nice.curses;

import deimos.ncurses;

package alias nc = deimos.ncurses; /* Just for convenience. */

/* ---------- base stuff ---------- */

/* The class representing current library state. */
final class Curses
{
    private:
        Window[] windows;
        Config cfg;
        Mode curMode;

    public:
        Window stdscr;
        ColorTable stdColors;

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
        this(Config config)
        {
            cfg = config;

            stdscr = new Window(initscr());
            if (config.useColors) {
                import std.exception;
                enforce(has_colors());
                start_color();
                if (config.useStdColors)
                    stdColors = new ColorTable();
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

        /* Finalize the library. Consider adding 
           'scope(exit) destroy(cursesState)`
           to the top of yours program to automatically clean-up the library,
           even in case of exceptions.
           */
        ~this()
        {
            destroy(windows);
            if (cfg.initKeypad) stdscr.keypad(false);
            final switch (curMode) {
                case Mode.normal: break;
                case Mode.cbreak: nocbreak(); break;
                case Mode.halfdelay: nocbreak(); break;
                case Mode.raw: noraw(); break;
            }
            curs_set(1);
            if (cfg.disableEcho) echo(true);
            nc.nl();
            endwin();
        }

        /* ---------- window manipulation ---------- */

        Window newWindow(int nlines, int ncols, int begin_y, int begin_x)
        {
            Window res = new Window(nlines, ncols, begin_y, begin_x, cfg.initKeypad);
            windows ~= res;
            return res;
        }

        void deleteWindow(Window which) 
        {
            import std.algorithm;
            import std.array;
            windows = array(windows.remove!(w => w is which));
            destroy(which);
        }

        /* ---------- general commands ---------- */

        void beep()
        {
            nc.beep();
        }

        void delayOutput(int ms)
        {
            nc.delay_output(ms);
        }

        void echo(bool set)
        {
            if (set)
                nc.echo();
            else
                nc.noecho();
        }

        void flash()
        {
            nc.flash();
        }

        void flushInput()
        {
            nc.flushinp();
        }

        void nap(int ms)
        {
            nc.napms(ms);
        }

        void resetTTY()
        {
            nc.resetty();
        }

        void saveTTY()
        {
            nc.savetty();
        }

        void setCursor(int level)
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

        void ungetch(int ch)
        {
            nc.ungetch(ch);
        }

        void update()
        {
            nc.doupdate();
        }

        /* ---------- some constants ---------- */

        int lines() const @property
        {
            return nc.LINES;
        }

        int cols() const @property
        {
            return nc.COLS;
        }

        int colors() const @property
        {
            return nc.COLORS;
        }

        int colorPairs() const @property
        {
            return nc.COLOR_PAIRS;
        }

        int tabSize() const @property
        {
            return nc.TABSIZE;
        }

        int escDelay() const @property
        {
            return nc.ESCDELAY;
        }

        /* ---------- information retrieval ---------- */

        int baudrate() const @property
        {
            return nc.baudrate();
        }

        bool canChangeColor() const @property
        {
            return nc.can_change_color();
        }

        RGB colorContent(short color) const @property
        {
            short r, g, b;
            color_content(color, &r, &g, &b);
            return RGB(r, g, b);
        }

        bool hasColors() const @property
        {
            return nc.has_colors();
        }

        string keyName(int key) const @property
        {
            import std.string;
            return cast(string) nc.keyname(key).fromStringz;
        }
}

/* The class representing a window. */
final class Window
{
    private:
        WINDOW* ptr;
        Window[] children;
        Window parent;
        bool isKeypad = false;

    package:
        this(WINDOW* fromPtr, bool setKeypad = true)
        {
            ptr = fromPtr;
            keypad(setKeypad);
            isKeypad = setKeypad;
        }

        this(int nlines, int ncols, int y, int x, bool setKeypad = true)
        {
            ptr = newwin(nlines, ncols, y, x);
            keypad(setKeypad);
            isKeypad = setKeypad;
        }

        ~this()
        {
            destroy(children);
            keypad(false);
            delwin(ptr);
        }

    public:
        /* ---------- general manipulation ---------- */

        void keypad(bool set)
        {
            if (nc.keypad(ptr, set) != OK) {
                if (set)
                    throw new NCException("Failed to enable keypad mode");
                else
                    throw new NCException("Failed to disable keypad mode");
            }
        }

        void move(int y, int x)
        {
            if (mvwin(ptr, y, x) != OK) 
                throw new NCException("Failed to move a window to position %s:%s", y, x);
        }

        void refresh()
        {
            nc.wrefresh(ptr);
        }

        /* ---------- child windows management ---------- */

        Window subwin(int nlines, int ncols, int y, int x)
        {
            WINDOW* p = nc.subwin(ptr, nlines, ncols, y, x);
            if (p is null) 
                throw new NCException(
                        "Failed to create a subwindow at %s:%s with height %s and width %s",
                        y, x, nlines, ncols);
            Window res = new Window(p, isKeypad);
            res.parent = this;
            children ~= res;
            return res;
        }

        Window derwin(int nlines, int ncols, int y, int x)
        {
            WINDOW* p = nc.derwin(ptr, nlines, ncols, y, x);
            if (p is null) 
                throw new NCException(
                        "Failed to create a subwindow at %s:%s with height %s and width %s",
                        y, x, nlines, ncols);
            Window res = new Window(p, isKeypad);
            res.parent = this;
            children ~= res;
            return res;
        }

        void deleteChild(Window child)
        {
            import std.algorithm;
            import std.array;
            children = array(children.remove!(c => c is child));
            destroy(child);
        }

        /* ---------- drawing ---------- */

        void addch(C: chtype, A: chtype)(int y, int x, C ch, A attr = Attr.normal)
        {
            import std.format;

            setAttr(attr);
            if (nc.mvwaddch(ptr, y, x, ch) != OK)
                throw new NCException("Failed to add character '%s' at %s:%s", ch, y, x);
        }

        void addstr(A: chtype)(int y, int x, string str, A attr = Attr.normal)
        {
            import std.string;

            setAttr(attr);
            if (nc.mvwaddstr(ptr, y, x, str.toStringz) != OK)
                throw new NCException("Failed to write string '%s' at %s:%s", str, y, x);
        }

        void addstr(A: chtype)(int y, int x, int n, string str, A attr = Attr.normal)
        {
            import std.string;

            setAttr(attr);
            if (nc.mvwaddnstr(ptr, y, x, str.toStringz, n) != OK)
                throw new NCException("Failed to write string '%s' at %s:%s", str, y, x);
        }

        private void setAttr(A: chtype)(A attr = Attr.normal)
        {
            if (attrset(attr) != OK)
                throw new NCException("Failed to set attribute '%s'", attr);
        }

        /* ---------- information retrieval ---------- */
}

final class ColorTable
{

}

enum Attr
{
    normal = A_NORMAL,
    charText = A_CHARTEXT,
    color = A_COLOR,
    standout = A_STANDOUT,
    underline = A_UNDERLINE,
    reverse = A_REVERSE,
    blink = A_BLINK,
    dim = A_DIM,
    bold = A_BOLD,
    altCharSet = A_ALTCHARSET,
    invis = A_INVIS,
    protect = A_PROTECT,
    horizontal = A_HORIZONTAL,
    left = A_LEFT,
    low = A_LOW,
    right = A_RIGHT,
    top = A_TOP,
    vertical = A_VERTICAL,
}

struct RGB
{
    short r, g, b;
}

/* ---------- Exceptions ---------- */

/* An exception that is thrown on ncurses errors. */
class NCException: Exception 
{
    import std.format;
    this(Arg...)(string formatString, Arg args)
    {
        super(format(formatString, args));
    }
}
