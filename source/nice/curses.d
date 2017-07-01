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

        /* This one moves the cursor. */
        void move(int y, int x)
        {
            if (wmove(ptr, y, x) != OK) 
                throw new NCException("Failed to move to position %s:%s", y, x);
        }

        /* This one moves the window. */
        void moveWindow(int y, int x)
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

        void addch(C: chtype, A: chtype)(C ch, A attr = Attr.normal)
        {
            import std.format;
            setAttr(attr);
            if (nc.waddch(ptr, ch) != OK)
                throw new NCException("Failed to add character '%s'", ch);
        }

        void addstr(A: chtype)(int y, int x, string str, A attr = Attr.normal)
        {
            import std.string;

            setAttr(attr);
            if (nc.mvwaddstr(ptr, y, x, str.toStringz) != OK)
                throw new NCException("Failed to write string '%s' at %s:%s", str, y, x);
        }

        void addstr(A: chtype)(string str, A attr = Attr.normal)
        {
            import std.string;

            setAttr(attr);
            if (nc.waddstr(ptr, str.toStringz) != OK)
                throw new NCException("Failed to write string '%s'", str);
        }

        void addnstr(A: chtype)(int y, int x, string str, int n, A attr = Attr.normal)
        {
            import std.string;

            setAttr(attr);
            if (nc.mvwaddnstr(ptr, y, x, str.toStringz, n) != OK)
                throw new NCException("Failed to write string '%s' at %s:%s", str, y, x);
        }

        void addnstr(A: chtype)(int n, string str, int n, A attr = Attr.normal)
        {
            import std.string;

            setAttr(attr);
            if (nc.waddnstr(ptr, str.toStringz, n) != OK)
                throw new NCException("Failed to write string '%s' at %s:%s", str, y, x);
        }

        private void setAttr(A: chtype)(A attr = Attr.normal)
        {
            if (attrset(attr) != OK)
                throw new NCException("Failed to set attribute '%s'", attr);
        }

        /* ---------- information retrieval ---------- */

        int getch()
        {
            int res = wgetch(ptr);
            if (res == ERR)
                throw new Exception("Failed to get a character");
            return res;
        }

        string getstr(int maxLength)
        {
            import std.string;

            char[] buffer = new char[maxLength + 1];
            char* p = &buffer[0];
            if (wgetstr(ptr, p) != OK)
                throw new Exception("Failed to get a string");
            /* The cast is safe, it's the only reference to the string. */
            return cast(string) fromStringz(p);
        }
}

final class ColorTable
{

}

/* An exception that is thrown on ncurses errors. */
class NCException: Exception 
{
    import std.format;
    this(Arg...)(string formatString, Arg args)
    {
        super(format(formatString, args));
    }
}

struct RGB
{
    short r, g, b;
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

enum Key
{
    codeYes   = KEY_CODE_YES,
    min       = KEY_MIN,
    codeBreak = KEY_BREAK, /* This should've been break, but that's a keyword. */

    down      = KEY_DOWN,
    up        = KEY_UP,
    left      = KEY_LEFT,
    right     = KEY_RIGHT,
    home      = KEY_HOME,
    backspace = KEY_BACKSPACE,
    f0        = KEY_F0,
    f1        = KEY_F(1),
    f2        = KEY_F(2),
    f3        = KEY_F(3),
    f4        = KEY_F(4),
    f5        = KEY_F(5),
    f6        = KEY_F(6),
    f7        = KEY_F(7),
    f8        = KEY_F(8),
    f9        = KEY_F(9),
    f10       = KEY_F(10),
    f11       = KEY_F(11),
    f12       = KEY_F(12),
    f13       = KEY_F(13),
    f14       = KEY_F(14),
    f15       = KEY_F(15),
    f16       = KEY_F(16),
    f17       = KEY_F(17),
    f18       = KEY_F(18),
    f19       = KEY_F(19),
    f20       = KEY_F(20),
    f21       = KEY_F(21),
    f22       = KEY_F(22),
    f23       = KEY_F(23),
    f24       = KEY_F(24),
    f25       = KEY_F(25),
    f26       = KEY_F(26),
    f27       = KEY_F(27),
    f28       = KEY_F(28),
    f29       = KEY_F(29),
    f30       = KEY_F(30),
    f31       = KEY_F(31),
    f32       = KEY_F(32),
    f33       = KEY_F(33),
    f34       = KEY_F(34),
    f35       = KEY_F(35),
    f36       = KEY_F(36),
    f37       = KEY_F(37),
    f38       = KEY_F(38),
    f39       = KEY_F(39),
    f40       = KEY_F(40),
    f41       = KEY_F(41),
    f42       = KEY_F(42),
    f43       = KEY_F(43),
    f44       = KEY_F(44),
    f45       = KEY_F(45),
    f46       = KEY_F(46),
    f47       = KEY_F(47),
    f48       = KEY_F(48),
    f49       = KEY_F(49),
    f50       = KEY_F(50),
    f51       = KEY_F(51),
    f52       = KEY_F(52),
    f53       = KEY_F(53),
    f54       = KEY_F(54),
    f55       = KEY_F(55),
    f56       = KEY_F(56),
    f57       = KEY_F(57),
    f58       = KEY_F(58),
    f59       = KEY_F(59),
    f60       = KEY_F(60),
    f61       = KEY_F(61),
    f62       = KEY_F(62),
    f63       = KEY_F(63),
    dl        = KEY_DL,
    il        = KEY_IL,
    dc        = KEY_DC,
    ic        = KEY_IC,
    eic       = KEY_EIC,
    clear     = KEY_CLEAR,
    eos       = KEY_EOS,
    eol       = KEY_EOL,
    sf        = KEY_SF,
    sr        = KEY_SR,
    npage     = KEY_NPAGE,
    ppage     = KEY_PPAGE,
    stab      = KEY_STAB,
    ctab      = KEY_CTAB,
    catab     = KEY_CATAB,
    enter     = KEY_ENTER,
    sreset    = KEY_SRESET,
    reset     = KEY_RESET,
    print     = KEY_PRINT,
    ll        = KEY_LL,
    a1        = KEY_A1,
    a3        = KEY_A3,
    b2        = KEY_B2,
    c1        = KEY_C1,
    c3        = KEY_C3,
    btab      = KEY_BTAB,
    beg       = KEY_BEG,
    cancel    = KEY_CANCEL,
    close     = KEY_CLOSE,
    command   = KEY_COMMAND,
    copy      = KEY_COPY,
    create    = KEY_CREATE,
    end       = KEY_END,
    exit      = KEY_EXIT,
    find      = KEY_FIND,
    help      = KEY_HELP,
    mark      = KEY_MARK,
    message   = KEY_MESSAGE,
    move      = KEY_MOVE,
    next      = KEY_NEXT,
    open      = KEY_OPEN,
    options   = KEY_OPTIONS,
    previous  = KEY_PREVIOUS,
    redo      = KEY_REDO,
    reference = KEY_REFERENCE,
    refresh   = KEY_REFRESH,
    replace   = KEY_REPLACE,
    restart   = KEY_RESTART,
    resume    = KEY_RESUME,
    save      = KEY_SAVE,
    sbeg      = KEY_SBEG,
    scancel   = KEY_SCANCEL,
    scommand  = KEY_SCOMMAND,
    scopy     = KEY_SCOPY,
    screate   = KEY_SCREATE,
    sdc       = KEY_SDC,
    sdl       = KEY_SDL,
    select    = KEY_SELECT,
    send      = KEY_SEND,
    seol      = KEY_SEOL,
    sexit     = KEY_SEXIT,
    sfind     = KEY_SFIND,
    shelp     = KEY_SHELP,
    shome     = KEY_SHOME,
    sic       = KEY_SIC,
    sleft     = KEY_SLEFT,
    smessage  = KEY_SMESSAGE,
    smove     = KEY_SMOVE,
    snext     = KEY_SNEXT,
    soptions  = KEY_SOPTIONS,
    sprevious = KEY_SPREVIOUS,
    sprint    = KEY_SPRINT,
    sredo     = KEY_SREDO,
    sreplace  = KEY_SREPLACE,
    sright    = KEY_SRIGHT,
    srsume    = KEY_SRSUME,
    ssave     = KEY_SSAVE,
    ssuspend  = KEY_SSUSPEND,
    sundo     = KEY_SUNDO,
    suspend   = KEY_SUSPEND,
    undo      = KEY_UNDO,
    mouse     = KEY_MOUSE,
    resize    = KEY_RESIZE,
    event     = KEY_EVENT,
    max       = KEY_MAX,
}
