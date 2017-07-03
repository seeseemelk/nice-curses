/* Main module.

   Provides Curses, Window and ColorTable classes.

   */

module nice.curses;

import deimos.ncurses;

package alias nc = deimos.ncurses; /* Just for convenience. */

/* ---------- base stuff ---------- */

/* The class representing current library state. Make sure you only have a 
   single instance of this around. */
final class Curses
{
    private:
        Window[] windows;
        Config cfg;
        Mode curMode;

    public:
        Window stdscr;
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
        this(Config config)
        {
            cfg = config;

            stdscr = new Window(null, initscr());
            if (config.useColors) {
                import std.exception;
                enforce(has_colors());
                start_color();
                colors = new ColorTable;
                if (config.useStdColors)
                    colors.initDefaultColors();
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

        /* Use default configuration. */
        this()
        {
            this(Config());
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
            Window res = new Window(colors, nlines, ncols, begin_y, begin_x, cfg.initKeypad);
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
            Curses.echoMode = set;
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
            return nc.keyname(key).fromStringz.idup;
        }
}

/* The class representing a window. */
final class Window
{
    private:
        WINDOW* ptr;
        Window[] children;
        Window parent;
        bool isKeypad;

    package:
        this(ColorTable colors, WINDOW* fromPtr, bool setKeypad = true)
        {
            ptr = fromPtr;
            this.colors = colors;
            keypad(setKeypad);
            isKeypad = setKeypad;
        }

        this(ColorTable colors, int nlines, int ncols, int y, int x, bool setKeypad = true)
        {
            ptr = newwin(nlines, ncols, y, x);
            this.colors = colors;
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
        ColorTable colors;

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
            nc.wnoutrefresh(ptr);
        }

        /* ---------- child windows management ---------- */

        Window subwin(int nlines, int ncols, int y, int x)
        {
            WINDOW* p = nc.subwin(ptr, nlines, ncols, y, x);
            if (p is null) 
                throw new NCException(
                        "Failed to create a subwindow at %s:%s with height %s and width %s",
                        y, x, nlines, ncols);
            Window res = new Window(colors, p, isKeypad);
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
            Window res = new Window(colors, p, isKeypad);
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

        /* This will silently drop any characters that don't fit into the 
           window. 

           The exact behavious depends on the 'alignment' parameter.
           If it's Align.left, then y and x are the coordinates of text's
           upper left corner.
           If it's Align.center, then they are the coordinates of text's first
           line's center.
           If it's Align.right, then they are the coordinates of text's upper
           right corner.

           Note that this method uses the entire window.
         */
        void addAligned(A: chtype)(int y, int x, string str, 
                Align alignment, A attr = Attr.normal)
        {
            import std.algorithm;

            final switch (alignment) {
                case Align.left: {
                    while (y < height && str != "") {
                        int w = min(width - x, cast(int) str.length);
                        addnstr(y, x, str, w, attr);
                        y++;
                        str = str[w .. $];
                    }
                    break;
                }
                case Align.center: {
                    while (y < height && str != "") {
                        int w = min(x, width - x, cast(int) str.length);
                        addnstr(y, x - w / 2, str, w, attr);
                        y++;
                        str = str[w .. $];
                    }
                    break;
                }
                case Align.right: {
                    while (y < height && str != "") {
                        int w = min(x, cast(int) str.length);
                        addnstr(y, x - w, str, w, attr);
                        y++;
                        str = str[w .. $];
                    }
                }
            } /* switch alignment */
        } /* addAligned */

        void border(chtype left, chtype right, chtype top, chtype bottom,
                chtype topLeft, chtype topRight, 
                chtype bottomLeft, chtype bottomRight)
        {
            nc.wborder(ptr, left, right, top, bottom, topLeft, topRight, bottomLeft, bottomRight);
        }

        void box(chtype vertical, chtype horizontal)
        {
            nc.box(ptr, vertical, horizontal);
        }

        void delch(int y, int x)
        {
            if (nc.mvwdelch(ptr, y, x) != OK)
                throw new NCException("Failed to delete character from position %s:%s", y, x);
        }

        void delch()
        {
            nc.wdelch(ptr);
        }

        void insert(chtype ch)
        {
            nc.winsch(ptr, ch);
        }

        void insert(int y, int x, chtype ch)
        {
            if (nc.mvwinsch(ptr, y, x, ch) != OK)
                throw new NCException("Failed to insert a character at position %s:%s", y, x);
        }

        /* This is unfortunate, but none of 'insstr' family functions accept
           immutable strings, the result of toStringz. 
           */
        void insert(string s)
        {
            import std.string;
            nc.winsstr(ptr, cast(char*) s.toStringz);
        }

        void insert(int y, int x, string s)
        {
            import std.string;
            if (nc.mvwinsstr(ptr, y, x, cast(char*) s.toStringz) != OK)
                throw new NCException("Failed to insert a string at position %s:%s", y, x);
        }

        void insert(string s, int n)
        {
            import std.string;
            nc.winsnstr(ptr, cast(char*) s.toStringz, n);
        }

        void insert(int y, int x, string s, int n)
        {
            import std.string;
            /* This fails to compile if template parameters list is omitted.
               Dunno why.
               */
            if (nc.mvwinsnstr!(WINDOW, int, char)(ptr, y, x, cast(char*) s.toStringz, n) 
                    != OK)
                throw new NCException("Failed to insert a string at position %s:%s", y, x);
        }

        void hline(int y, int x, chtype ch, int n)
        {
            if (nc.mvwhline(ptr, y, x, ch, n) != OK)
                throw new NCException("Failed to draw a horizontal line at %s:%s", y, x);
        }

        void hline(chtype ch, int n)
        {
            nc.whline(ptr, ch, n);
        }

        /* Overlays this window on top of another (non-destructively). */
        void overlay(Window target)
        {
            if (nc.overlay(ptr, target.ptr) == ERR)
                throw new NCException("Failed to overlay a window");
        }

        /* Overwrites this window on top of another (destructively). */
        void overwrite(Window target)
        {
            if (nc.overwrite(ptr, target.ptr) == ERR)
                throw new NCException("Failed to overwrite a window");
        }

        private void setAttr(A: chtype)(A attr = Attr.normal)
        {
            if (wattrset(ptr, attr) != OK)
                throw new NCException("Failed to set attribute '%s'", attr);
        }

        void vline(int y, int x, chtype ch, int n)
        {
            if (nc.mvwvline(ptr, y, x, ch, n) != OK)
                throw new NCException("Failed to draw a vertical line at %s:%s", y, x);
        }

        void vline(chtype ch, int n)
        {
            nc.wvline(ptr, ch, n);
        }

        /* ---------- various manipulations ---------- */

        void bkgd(chtype ch)
        {
            nc.wbkgd(ptr, ch);
        }

        void bkgdset(chtype ch)
        {
            nc.wbkgdset(ptr, ch);
        }

        void clear()
        {
            nc.wclear(ptr);
        }

        void clearToBottom()
        {
            nc.wclrtobot(ptr);
        }

        void clearToEOL()
        {
            nc.wclrtoeol(ptr);
        }

        void deleteln()
        {
            nc.wdeleteln(ptr);
        }

        void erase()
        {
            nc.werase(ptr);
        }

        void insdel(int n)
        {
            nc.winsdelln(ptr, n);
        }

        void insertln()
        {
            nc.winsertln(ptr);
        }

        void scroll(int n)
        {
            if (nc.wscrl(ptr, n) != OK)
                throw new NCException("Failed to scroll a window by %s lines", n);
        }
       

        /* ---------- information retrieval ---------- */

        int getch()
        {
            int res = wgetch(ptr);
            if (res == ERR)
                throw new Exception("Failed to get a character");
            return res;
        }

        int curX()
        {
            return nc.getcurx(ptr);
        }

        int curY()
        {
            return nc.getcury(ptr);
        }

        int maxX()
        {
            return nc.getmaxx(ptr);
        }

        int maxY()
        {
            return nc.getmaxy(ptr);
        }

        int width()
        {
            return maxX + 1;
        }

        int height()
        {
            return maxY + 1;
        }

        string getstr(int maxLength)
        {
            import std.string;

            char[] buffer = new char[maxLength + 1];
            char* p = &buffer[0];
            if (wgetstr(ptr, p) != OK)
                throw new Exception("Failed to get a string");
            return fromStringz(p).idup;
        }

        string getstr()
        {
            import std.string;

            bool isEcho = Curses.echoMode;
            noecho();
            scope(exit) if (isEcho) echo();

            string res;
            int x = curX;
            int y = curY;
            while(true) {
                int ch = wgetch(ptr);
                if (ch == ERR) return res;
                if (ch == '\n' || ch == '\r' || ch == Key.enter) return res;
                if (ch == '\b' || ch == Key.left || ch == Key.backspace
                        || ch == killchar || ch == erasechar) {
                    if (res.length == 0) continue;
                    res = res[0 .. $ - 1];
                    /* Delete the character under the cursor and then move it. */
                    if (!isEcho) continue;
                    x--;
                    if (x < 0) {
                        x = Curses.cols - 1;
                        y--;
                    }
                    if (y < 0) y = 0; 
                    move(y, x);
                    delch();
                    continue;
                }
                if (ch > 0xff) {
                    nc.beep();
                    continue;
                }
                if (ch == '\t') ch = ' '; /* This greatly simplifies deleting
                                             characters. */
                addch(ch);
                x = curX;
                y = curY;
                res ~= cast(char) ch;
            } /* while true */
        } /* getstr */

        chtype[] inchstr()
        {
            import std.algorithm;
            import std.array;

            auto buffer = new chtype[Curses.lines * Curses.cols + 1];
            auto p = &buffer[0];
            winchstr(ptr, p);
            return buffer.until(0).array.dup;
        }

        chtype[] inchstr(int n)
        {
            import std.algorithm;
            import std.array;
            
            auto buffer = new chtype[Curses.lines * Curses.cols + 1];
            auto p = &buffer[0];
            winchnstr(ptr, p, n);
            return buffer.until(0).array.dup;
        }

        chtype[] inchstr(int y, int x)
        {
            move(y, x);
            return inchstr;
        }

        chtype[] inchstr(int y, int x, int n)
        {
            move(y, x);
            return inchstr(n);
        }
}

final class ColorTable
{
    private:
        struct Pair { short fg; short bg; }
        int[Pair] pairs;

    public:

        int opIndex(short fg, short bg)
        {
            auto pair = Pair(fg, bg);
            if (pair in pairs) 
                return pairs[pair];
            else 
                throw new NCException("Combination of colors %s:%s is not in the color table",
                        fg, bg);
        }

        void addPair(short fg, short bg)
        {
            /* The cast can lead to nasty bugs, but if you need 65k color
               pairs, you're better off with using SDL or OpenGL or something. */
            int newPair = init_pair(cast(short) (pairs.length + 1), fg, bg);
            if (newPair == ERR)
                throw new NCException("Failed to initialize color pair %s:%s", fg, bg);
            pairs[Pair(fg, bg)] = newPair;
        }

        void removePair(short fg, short bg)
        {
            auto pair = Pair(fg, bg);
            if (pair in pairs)
                pairs.remove(pair);
        }

        void initDefaultColors()
        {
            import std.traits;
            foreach (colorA; EnumMembers!StdColor) 
                foreach (colorB; EnumMembers!StdColor) 
                    addPair(colorA, colorB);
        }
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
    normal     = A_NORMAL,
    charText   = A_CHARTEXT,
    color      = A_COLOR,
    standout   = A_STANDOUT,
    underline  = A_UNDERLINE,
    reverse    = A_REVERSE,
    blink      = A_BLINK,
    dim        = A_DIM,
    bold       = A_BOLD,
    altCharSet = A_ALTCHARSET,
    invis      = A_INVIS,
    protect    = A_PROTECT,
    horizontal = A_HORIZONTAL,
    left       = A_LEFT,
    low        = A_LOW,
    right      = A_RIGHT,
    top        = A_TOP,
    vertical   = A_VERTICAL,
}

enum StdColor: chtype
{
    black   = COLOR_BLACK,
    red     = COLOR_RED,
    green   = COLOR_GREEN,
    yellow  = COLOR_YELLOW,
    blue    = COLOR_BLUE,
    magenta = COLOR_MAGENTA,
    cyan    = COLOR_CYAN,
    white   = COLOR_WHITE,
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

enum Align
{
    left,
    center,
    right
}
