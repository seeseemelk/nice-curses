/* Main module.

   Provides Curses, Window and ColorTable classes.

   */

module nice.curses;

import std.uni;

import deimos.ncurses;
public import deimos.ncurses: chtype, wint_t;

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
        this(Config config = Config())
        {
            import core.stdc.locale;
            cfg = config;
            setlocale(LC_ALL, "");

            stdscr = new Window(null, initscr());
            if (config.useColors) {
                import std.exception;
                enforce(has_colors());
                start_color();
                colors = new ColorTable(config.useStdColors);
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

        Window duplicateWindow(Window which)
        {
            auto p = dupwin(which.ptr);
            Window res = new Window(colors, p, cfg.initKeypad);
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

        void addch(C: cchar_t)(C ch)
        {
            bool isLowerRight = (curY == height - 1) && (curX == width - 1);
            cchar_t cchar = ch;
            if (nc.wadd_wch(ptr, &cchar) != OK && !isLowerRight)
                throw new NCException("Failed to add complex character '%s'", ch);

        }

        void addch(C: wint_t, A: chtype)(C ch, A attr = Attr.normal)
        {
            bool isLowerRight = (curY == height - 1) && (curX == width - 1);
            auto toDraw = prepChar(ch, attr);
            if (nc.wadd_wch(ptr, &toDraw) != OK && !isLowerRight)
                throw new NCException("Failed to add character '%s'", ch);
        }

        void addch(C: cchar_t)(int y, int x, C ch)
        {
            try {
                move(y, x);
                addch(ch);
            } catch (NCException e) {
                throw new NCException("Failed to add complex character '%s' at %s%s", 
                        ch, y, x);
            }
        }

        void addch(C: wint_t, A: chtype)(int y, int x, C ch, A attr = Attr.normal)
        {
            try {
                move(y, x);
                addch(ch, attr);
            } catch (NCException e) {
                throw new NCException("Failed to add character '%s' at %s:%s", ch, y, x);
            }
        }

        void addnstr(A: chtype)(int y, int x, string str, int n, A attr = Attr.normal)
        {
            try {
                move(y, x);
                addnstr(str, n, attr);
            } catch (NCException e) {
                throw new NCException("Failed to write string '%s' at %s:%s", str, y, x);
            }
        } 

        void addnstr(A: chtype)(string str, int n, A attr = Attr.normal)
        {
            import core.stdc.stddef;
            import std.array;
            import std.conv;
            import std.uni;

            setAttr(attr);
            wchar_t[] chars = [];
            chars.reserve(str.length);
            foreach (gr; str.byGrapheme)
                chars ~= gr[].array.to!(wchar_t[]);
            chars ~= 0;
            if (waddwstr(ptr, &chars[0]) != OK)
                throw new NCException("Failed to add string '%s'", str);
        } 

        void addstr(A: chtype)(int y, int x, string str, A attr = Attr.normal)
        {
            addnstr(y, x, str, width * height, attr);
        }

        void addstr(A: chtype)(string str, A attr = Attr.normal)
        {
            addnstr(str, width * height, attr);
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
            import std.range;
            import std.string;
            import std.uni;

            /* Advance to the next line. */
            void nextLine(Range)(Range grs)
            {
                final switch (alignment) {
                    case Align.left: 
                        move(y, x);
                        break;
                    case Align.center:
                        int offset = min(grs.walkLength / 2 - 1, x);
                        move(y, x - offset);
                        break;
                    case Align.right:
                        int offset = min(x, grs.walkLength - 1);
                        move(y, x - offset);
                        break;
                }
            }
            foreach (line; str.splitLines) {
                auto grs = line.byGrapheme;
                nextLine(grs);
                while (!grs.empty) {
                    auto gr = grs.front;
                    grs.popFront;
                    try {
                        addch(fromGrapheme(gr, attr));
                    } catch (NCException e) {
                        return;
                    }
                    if (curY >= height) return;
                    if (curY > y) {
                        y = curY;
                        nextLine(grs);
                    } /* if next line */
                } /* while !grs.empty */
                y++;
            } /* foreach line */
        } /* addAligned */

        /* Use the whole window and figure out exact X coordinate. */
        void addAligned(A: chtype)(int y, string str, Align alignment, A attr = Attr.normal)
        {
            final switch(alignment) {
                case Align.left:
                    addAligned(y, 0, str, alignment, attr);
                    break;
                case Align.center:
                    addAligned(y, width / 2, str, alignment, attr);
                    break;
                case Align.right:
                    addAligned(y, width - 1, str, alignment, attr);
                    break;
            }
        }

        void border(chtype left, chtype right, chtype top, chtype bottom,
                chtype topLeft, chtype topRight, 
                chtype bottomLeft, chtype bottomRight)
        {
            nc.wborder(ptr, left, right, top, bottom, topLeft, topRight, bottomLeft, bottomRight);
        }

        void border(cchar_t left, cchar_t right, cchar_t top, cchar_t bottom,
                cchar_t topLeft, cchar_t topRight, 
                cchar_t bottomLeft, cchar_t bottomRight)
        {
            nc.wborder_set(ptr, 
                    &left, &right, &top, &bottom, 
                    &topLeft, &topRight, &bottomLeft, &bottomRight);
        }

        void box(cchar_t vertical, cchar_t horizontal)
        {
            nc.box_set(ptr, &vertical, &horizontal);
        }

        void box(chtype v, chtype h)
        {
            nc.box(ptr, v, h);
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

        void insert(string s)
        {
            import std.string;
            /* This is unfortunate, but none of 'insstr' family functions
               accept immutable strings, the result of toStringz. 
               */
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

        void hline(int y, int x, cchar_t ch, int n)
        {
            try {
                move(y, x);
                hline(ch, n);
            } catch (NCException e) {
                throw new NCException("Failed to draw a horizontal line at %s:%s", y, x);
            }
        }

        void hline(chtype ch, int n)
        {
            nc.whline(ptr, ch, n);
        }

        void hline(cchar_t ch, int n)
        {
            nc.whline_set(ptr, &ch, n);
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

        void vline(int y, int x, cchar_t ch, int n)
        {
            try {
                move(y, x);
                vline(ch, n);
            } catch (NCException e) {
                throw new NCException("Failed to draw a vertical line at %s:%s", y, x);
            }
        }

        void vline(chtype ch, int n)
        {
            nc.wvline(ptr, ch, n);
        }

        void vline(cchar_t ch, int n)
        {
            nc.wvline_set(ptr, &ch, n);
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
                throw new NCException("Failed to get a character");
            return res;
        }

        /* This should be preferred over plain 'getch' if you care about your
           program being Unicode-aware. 
           */
        WChar getwch()
        {
            wint_t chr;
            int res = wget_wch(ptr, &chr);
            if (res == KEY_CODE_YES)
                return WChar(chr, true);
            else if (res == OK)
                return WChar(chr, false);
            else
                throw new NCException("Failed to get a wide character");
        }

        int curX() @property
        {
            return nc.getcurx(ptr);
        }

        int curY() @property
        {
            return nc.getcury(ptr);
        }

        int width() @property
        {
            return nc.getmaxx(ptr) + 1;
        }

        int height() @property
        {
            return nc.getmaxy(ptr) + 1;
        }

        string getstr(int maxLength, bool echoChars = true)
        {
            import std.conv;

            bool isEcho = Curses.echoMode;
            Curses.echo(echoChars);
            scope(exit) Curses.echo(isEcho);

            wint_t[] buffer = new wint_t[maxLength + 1];
            buffer[$ - 1] = 0;
            if (wgetn_wstr(ptr, &buffer[0], maxLength) != OK)
                throw new NCException("Failed to get a string");
            string res;
            res.reserve(buffer.length);
            foreach (ch; buffer)
                res ~= text(ch);
            return res;
        }

        string getstr(bool echoChars = true)
        {
            return getstr(ch => true, echoChars);
        }

        string getstr(bool delegate(wint_t) predicate, bool echoChars = true)
        {
            import std.conv;

            bool isEcho = Curses.echoMode;
            Curses.echo(false);
            scope(exit) Curses.echo(isEcho);

            string res;
            int x = curX;
            int y = curY;
            while(true) {
                WChar key;
                try {
                    key = getwch;
                } catch (NCException e) {
                    return res;
                }
                bool special = key.isSpecialKey;
                wint_t ch = key.chr;
                /* Check for end-of-input keys. */
                if ((special && key.key == Key.enter) 
                        || ch == '\n' || ch == '\r') {
                    return res;
                }
                /* Check for erase-some-characters keys. */
                wint_t kill, erase;
                nc.killwchar(&kill);
                nc.erasewchar(&erase);
                if (special && (key.key == Key.left || key.key == Key.backspace)
                        || ch == '\b' || ch == kill || ch == erase) {
                    if (res.length == 0) continue;
                    import std.array;
                    import std.range;
                    import std.uni;
                    res = res
                        .byGrapheme
                        .array
                        .dropBackOne
                        .byCodePoint
                        .text;
                    /* Delete the character under the cursor and then move it. */
                    if (!echoChars) continue;
                    x--;
                    if (x < 0) {
                        x = Curses.cols - 1;
                        y--;
                    }
                    if (y < 0) y = 0; 
                    delch(y, x);
                    continue;
                }
                if (special) continue;
                /* When at the end of the window, allow only deleting and
                   finishing the input. 
                   */
                if (x == width - 1 && y == height - 1) continue;
                if (!predicate(ch)) {
                    nc.beep();
                    continue;
                }
                if (ch == '\t') ch = ' '; /* This greatly simplifies deleting
                                             characters. */
                if (echoChars) addch(ch);
                x = curX;
                y = curY;
                res ~= text(ch);
            } /* while true */
        } /* getstr */

        chtype[] inchstr()
        {
            import std.algorithm;
            import std.array;

            auto buffer = new chtype[Curses.lines * Curses.cols + 1];
            buffer[$ - 1] = 0;
            auto p = &buffer[0];
            winchstr(ptr, p);
            return buffer.until(0).array.dup;
        }

        chtype[] inchstr(int n)
        {
            import std.algorithm;
            import std.array;
            
            auto buffer = new chtype[n + 1];
            buffer[$ - 1] = 0;
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

        Pair[short] pairs; /* A mapping from pair indices to pairs. */
        chtype[Pair] attrs; /* A mapping from pairs to attributes. */
        short[] reusablePairs;
        short latestPair = 1;

        short latestColor;
        short[] reusableColors;

    public:

        this(bool useStdColors)
        {
            if (useStdColors) {
                latestColor = StdColor.max + 1;
                initDefaultColors;
            } else {
                latestColor = 1;
            }
        }

        /* Indexing a color table returns an attribute which a color pair 
           represents. */
        chtype opIndex(short fg, short bg)
        {
            auto pair = Pair(fg, bg);
            if (pair in attrs) 
                return attrs[pair];
            else 
                throw new NCException("Combination of colors %s:%s is not in the color table",
                        fg, bg);
        }

        /* Alternatively, you can use a pair index to get an attribute. */
        chtype opIndex(short pairIndex)
        {
            if (pairIndex in pairs)
                return attrs[pairs[pairIndex]];
            else
                throw new NCException("Color pair #%s is not in the color table", pairIndex);
        }

        /* Return the index of a newly created pair. */
        short addPair(short fg, short bg)
        {
            bool addNew = reusablePairs == [];
            short pair;
            if (addNew) 
                pair = latestPair;
            else
                pair = reusablePairs[0];
            if (init_pair(pair, fg, bg) != OK)
                throw new NCException("Failed to initialize color pair %s:%s", fg, bg);

            auto p = Pair(fg, bg);
            pairs[pair] = p;
            attrs[p] = COLOR_PAIR(pair);
            if (addNew)
                latestPair++;
            else
                reusablePairs = reusablePairs[1 .. $];
            return pair;
        }

        /* Redefine a color. */
        void redefineColor(short color, short r, short g, short b)
        {
            if (color >= Curses.maxColors)
                throw new NCException("A color with index %s requested, but the " ~
                        "terminal supports only %s colors", color, Curses.maxColors);
            if (init_color(color, r, g, b) != OK)
                throw new NCException("Failed to initialize a color #%s with RGB content " ~
                        "%s:%s:%s", color, r, g, b);
        }

        /* Return the index of a newly defined color. */
        short addColor(short r, short g, short b)
        {
            if (!Curses.canChangeColor)
                throw new NCException("The terminal doesn't support changing colors");

            bool addNew = reusableColors == [];
            short color;
            if (addNew)
                color = latestColor;
            else
                color = reusableColors[0];
            redefineColor(color, r, g, b);
            if (addNew)
                latestColor++;
            else
                reusableColors = reusableColors[1 .. $];
            return color;
        }

        /* Ditto. */
        short addColor(RGB color)
        {
            return addColor(color.r, color.g, color.b);
        }

        /* Mark a pair as available for overwriting. It doesn't actually
           undefine it or anything, there's no way to do that. */
        void removePair(short pairIndex)
        {
            if (pairIndex !in pairs)
                throw new NCException("Attempted to remove color pair #%s, which is " ~
                        "not in the color table to begin with", pairIndex);
            reusablePairs ~= pairIndex;
            attrs.remove(pairs[pairIndex]);
            pairs.remove(pairIndex);
        }

        /* Mark a color as available for overwriting. */
        void removeColor(short color)
        {
            reusableColors ~= color;
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
    this(Arg...)(string formatString, Arg args)
    {
        import std.format;
        super(format(formatString, args));
    }
}

/* ---------- helpers and enums ---------- */

/* Wide character - the return type of getwch function. */
struct WChar
{
    private:
        bool isSpecialKey_;
        int key_;
        wint_t chr_;

    public:
        bool isSpecialKey() const @property { return isSpecialKey_; }
        int key() const @property { return key_; }
        wint_t chr() const @property { return chr_; }

        bool opBinary(op)(WChar other)
            if (op == "==")
        {
            if (isSpecialKey_ != other.isSpecialKey_) return false;
            if (isSpecialKey_)
                return key_ == other.key_;
            else
                return chr_ == other.chr_;
        }

        this(wint_t key, bool isSpecial = false)
        {
            isSpecialKey_ = isSpecial;
            if (isSpecial) 
                key_ = key;
            else
                chr_ = key;
        }

        this(Key key)
        {
            this(key, true);
        }
}

/* Complex character (that is, with attribute bundled) - used as input by some
   functions.
   */
struct CChar
{
    wint_t[] chars;
    chtype attr;

    this(wint_t chr, chtype attr = Attr.normal)
    {
        chars = [chr];
        this.attr = attr;
    }

    this(const wint_t[] chars, chtype attr = Attr.normal)
    {
        this.chars = chars.dup;
        this.attr = attr;
    }

    this(const string chars, chtype attr = Attr.normal)
    {
        import std.conv;

        this.chars = chars.to!(wint_t[]);
        this.attr = attr;
    }

    bool opBinary(op)(wint_t chr)
        if (op == "==")
    {
        return chars[0] == chr;
    }

    alias cchar this;

    cchar_t cchar() const @property
    {
        return prepChar(chars, attr);
    }
}

struct RGB
{
    short r, g, b;
}

enum Attr: chtype
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

enum StdColor: short
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
    codeBreak = KEY_BREAK, /* This should've been just 'break', but that's a
                              keyword. */

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

/* ---------- private helpers ---------- */

private:

/* Prepare a wide character for drawing. */
cchar_t
prepChar(C: wint_t, A: chtype)(C ch, A attr)
{
    import core.stdc.stddef: wchar_t;

    cchar_t res;
    wchar_t[] str = [ch, 0];
    setcchar(&res, &str[0], attr, 0, null);
    return res;
}

cchar_t
prepChar(C: wint_t, A: chtype)(const C[] chars, A attr)
{
    import core.stdc.stddef: wchar_t;
    import std.exception;
    enforce(chars.length < CCHARW_MAX, "The array of characters must be shorter " ~
          "than CCHARW_MAX");

    cchar_t res;
    const wchar_t[] str = chars ~ 0;
    /* Hmm, 'const' modifiers apparently were lost during porting the library
       from C to D.
       */
    setcchar(&res, cast(wchar_t*) &str[0], attr, 0, null);
    return res;
}

/* Advance the cursor by a given amount of spaces. */
void 
advance(ref int y, ref int x, int w, int h, int by)
{
    x += by;
    while(x >= w) {
        x -= w;
        y++;
    }
}

CChar
fromGrapheme(Grapheme g, chtype attr = Attr.normal)
{
    import std.array;

    return CChar(g[].array, attr);
}

/* Returns visual lenght of a string. */
int 
lineLength(string str)
{
    import std.array;
    import std.uni;

    int res = 0;
    foreach (gr; str.byGrapheme) {
        if (gr[0] == '\t') 
            res += 8;
        else 
            res++;
    }
    return res;
}
