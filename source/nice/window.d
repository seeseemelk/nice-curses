module nice.window;

import std.uni;

import nc = deimos.ncurses;

import nice.color_table;
import nice.exception;
import nice.screen: Screen;
import nice.util;

/* Underlying ncurses functions should be marked via explicit nc. prefix, but
   types are fair game.
   */
alias cchar_t = nc.cchar_t;
alias chtype = nc.chtype;
alias wint_t = nc.wint_t;
alias WINDOW = nc.WINDOW;

alias OK = nc.OK;
alias ERR = nc.ERR;

final class Window
{
    private:
        Screen screen;
        Window[] children;
        bool isKeypad;
        bool wasFreed;

    package:
        WINDOW* ptr;

        this(Screen screen, WINDOW* fromPtr, bool setKeypad = true)
        {
            this.screen = screen;
            id = screen.nextWindowId();
            colors = screen.colors;
            ptr = fromPtr;
            keypad(setKeypad);
        }

        void free(bool isStdscr = false)
        {
            if (wasFreed)
                return;
            foreach (child; children)
                child.free();
            if (!isStdscr) 
                nc.delwin(ptr);
            wasFreed = true;
        }

        void throwUnlessValid()
        {
            if (wasFreed) 
                throw new UseAfterFreeException(
                        "Window %s of terminal %s was used after it was freed",
                        id, screen.id);
        }

    public:
        ColorTable colors;
        immutable uint id;

        /* ---------- general manipulation ---------- */

        void keypad(bool set)
        {
            throwUnlessValid();
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
            throwUnlessValid();
            if (nc.wmove(ptr, y, x) != OK) 
                throw new NCException("Failed to move to position %s:%s", y, x);
        }

        /* This one moves the window. */
        void moveWindow(int y, int x)
        {
            throwUnlessValid();
            if (nc.mvwin(ptr, y, x) != OK)
                throw new NCException("Failed to move a window to position %s:%s", y, x);
        }

        void refresh()
        {
            throwUnlessValid();
            nc.wnoutrefresh(ptr);
        }

        /* ---------- child windows management ---------- */

        Window subwin(int nlines, int ncols, int y, int x)
        {
            throwUnlessValid();
            WINDOW* p = nc.subwin(ptr, nlines, ncols, y, x);
            if (p is null) 
                throw new NCException(
                        "Failed to create a subwindow at %s:%s with height %s and width %s",
                        y, x, nlines, ncols);
            Window res = new Window(screen, p, isKeypad);
            children ~= res;
            return res;
        }

        Window derwin(int nlines, int ncols, int y, int x)
        {
            throwUnlessValid();
            WINDOW* p = nc.derwin(ptr, nlines, ncols, y, x);
            if (p is null) 
                throw new NCException(
                        "Failed to create a subwindow at %s:%s with height %s and width %s",
                        y, x, nlines, ncols);
            Window res = new Window(screen, p, isKeypad);
            children ~= res;
            return res;
        }

        void deleteChild(Window child)
        {
            import std.algorithm: canFind, remove;
            throwUnlessValid();
            if (children.canFind(child)) {
                children.remove!(cur => cur is child);
                child.free();
            }
        }

        /* ---------- drawing ---------- */

        import std.range;
        import std.traits;

        enum isString(T) = isInputRange!T && is(Unqual!(ElementType!T): dchar);
        enum isAttrRange(T) = isInputRange!T && is(Unqual!(ElementType!T): chtype);

        void addch(C: cchar_t)(C ch)
        {
            throwUnlessValid();
            bool isLowerRight = (curY == height - 1) && (curX == width - 1);
            cchar_t cchar = ch;
            if (nc.wadd_wch(ptr, &cchar) != OK && !isLowerRight)
                throw new NCException("Failed to add complex character '%s'", ch);

        }

        void addch(C: wint_t, A: chtype)(C ch, A attr = Attr.normal)
        {
            throwUnlessValid();
            bool isLowerRight = (curY == height - 1) && (curX == width - 1);
            auto toDraw = prepChar(ch, attr);
            if (nc.wadd_wch(ptr, &toDraw) != OK && !isLowerRight)
                throw new NCException("Failed to add character '%s'", ch);
        }

        void addch(C: cchar_t)(int y, int x, C ch)
        {
            throwUnlessValid();
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
            throwUnlessValid();
            try {
                move(y, x);
                addch(ch, attr);
            } catch (NCException e) {
                throw new NCException("Failed to add character '%s' at %s:%s", ch, y, x);
            }
        }

        /* Coords, n, multiple attrs */
        void addnstr(String, Range)(int y, int x, String str, int n, Range attrs,
                OOB onOOB = OOB.ignore)
            if (isString!String && isAttrRange!Range)
        {
            throwUnlessValid();
            /* Move first. */
            try {
                move(y, x);
            } catch (NCException e) {
                throw new NCException("Failed to write string '%s' at %s:%s", str, y, x);
            }
            /* Write second. */
            try {
                addnstr(str, n, attrs);
            } catch (NCException e) {
                if (onOOB == OOB.except)
                    throw new NCException("An out-of-bounds condition was " ~
                            "encountered when writing string '%s' at %s:%s",
                            str, y, x);
            }
        }

        /* n, multiple attrs */
        void addnstr(String, Range)(String str, int n, Range attrs, 
                OOB onOOB = OOB.ignore)
            if (isString!String && isAttrRange!Range)
        {
            import std.array;
            import std.conv;
            import std.range;
            import std.uni;
            throwUnlessValid();
            auto grs = str.byGrapheme;
            foreach (gr; str.byGrapheme) {
                if (n <= 0) break;
                if (attrs.empty) break;
                string chr = text(gr[].array);
                auto attr = attrs.front;
                attrs.popFront;
                auto c = CChar(chr, attr);
                try {
                    addch(c);
                } catch (NCException e) {
                    if (onOOB == OOB.ignore)
                        break;
                    else
                        throw new NCException("An out-of-bounds condition was " ~
                                "encountered when writing string '%s'", str);
                }
                n--;
            }
        }

        /* Coords, n, single attr */
        void addnstr(String, A: chtype)
            (int y, int x, String str, int n, A attr = Attr.normal, OOB onOOB = OOB.ignore)
            if (isString!String)
        {
            throwUnlessValid();
            try {
                move(y, x);
            } catch (NCException e) {
                throw new NCException("Failed to write string '%s' at %s:%s", str, y, x);
            }
            try {
                addnstr(str, n, attr);
            } catch (NCException e) {
                if (onOOB == OOB.except)
                    throw new NCException("An out-of-bounds condition was " ~
                            "encountered when writing string '%s' at %s:%s",
                            str, y, x);
            } /* try write */
        } 

        /* n, single attr */
        void addnstr(String, A: chtype)(String str, int n, A attr = Attr.normal, 
                OOB onOOB = OOB.ignore)
            if (isString!String)
        {
            import core.stdc.stddef;
            import std.array;
            import std.conv;
            import std.range;
            import std.uni;
            throwUnlessValid();
            setAttr(attr);
            wchar_t[] chars = [];
            chars.reserve(str.walkLength);
            foreach (gr; str.byGrapheme)
                chars ~= gr[].array.to!(wchar_t[]);
            chars ~= 0;
            if (waddwstr(ptr, chars.ptr) != OK && onOOB == OOB.except)
                throw new NCException("Failed to add string '%s'", str);
        } 

        /* Coords, multiple attrs */
        void addstr(String, Range)(int y, int x, String str, Range attrs, 
                OOB onOOB = OOB.ignore)
            if (isString!String && isAttrRange!Range)
        {
            throwUnlessValid();
            addnstr(y, x, str, width * height, attrs, onOOB);
        }

        /* Multiple attrs */
        void addstr(String, Range)(String str, Range attrs, OOB onOOB = OOB.ignore)
            if (isString!String && isAttrRange!Range)
        {
            throwUnlessValid();
            addnstr(str, width * height, attrs, onOOB);
        }

        /* Coords, single attr */
        void addstr(String, A: chtype)(int y, int x, String str, A attr = Attr.normal,
                OOB onOOB = OOB.ignore)
            if (isString!String)
        {
            throwUnlessValid();
            addnstr(y, x, str, width * height, attr, onOOB);
        }

        /* Single attr */
        void addstr(String, A: chtype)(String str, A attr = Attr.normal, 
                OOB onOOB = OOB.ignore)
            if (isString!String)
        {
            throwUnlessValid();
            addnstr(str, width * height, attr, onOOB);
        }

        /*
           The exact behaviour depends on the 'alignment' parameter.
           If it's Align.left, then y and x are the coordinates of text's
           upper left corner.
           If it's Align.center, then they are the coordinates of text's first
           line's center.
           If it's Align.right, then they are the coordinates of text's upper
           right corner.

           Note that this method uses the entire window.
         */
        void addAligned(String, Range)(int y, int x, String str, 
                Align alignment, Range attrs, OOB onOOB = OOB.ignore)
            if (isString!String && isAttrRange!Range)
        {
            import std.algorithm;
            import std.range;
            import std.string;
            import std.uni;

            throwUnlessValid();

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
            /* The 'take' is here for infinite ranges. Not sure why would
               anyone want to feed an infinite range to this method, but hey.
               It's nice to have the possibility.
               */
            auto arr = str.take(width * height).array;
            foreach (line; arr.splitLines) {
                auto grs = line.byGrapheme;
                nextLine(grs);
                while (!grs.empty && !attrs.empty) {
                    auto gr = grs.front;
                    auto attr = attrs.front;
                    grs.popFront;
                    attrs.popFront;
                    try {
                        addch(fromGrapheme(gr, attr));
                    } catch (NCException e) {
                        if (onOOB == OOB.except)
                            throw new NCException("An out-of-bounds condition " ~
                                    "was encountered when adding aligned string '%s'" ~
                                    "at %s:%s", str, y, x);
                        else
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

        void addAligned(String, A: chtype)(int y, int x, String str, 
                Align alignment, A attr = Attr.normal, OOB onOOB = OOB.ignore)
            if (isString!String)
        {
            import std.range;
            throwUnlessValid();
            addAligned(y, x, str, alignment, cycle([attr]), onOOB);
        }

        /* Use the whole window and figure out exact X coordinate. */
        void addAligned(String, Range) (int y, String str, Align alignment, 
                Range attrs, OOB onOOB = OOB.ignore)
            if (isString!String && isAttrRange!Range)
        {
            throwUnlessValid();
            final switch(alignment) {
                case Align.left:
                    addAligned(y, 0, str, alignment, attrs, onOOB);
                    break;
                case Align.center:
                    addAligned(y, width / 2, str, alignment, attrs, onOOB);
                    break;
                case Align.right:
                    addAligned(y, width - 1, str, alignment, attrs, onOOB);
                    break;
            }
        }

        /* Ditto, but with single attribute. */
        void addAligned(String, A: chtype) (int y, String str, Align alignment, 
                A attr = Attr.normal, OOB onOOB = OOB.ignore)
            if (isString!String)
        {
            import std.range;
            throwUnlessValid();
            addAligned(y, str, alignment, cycle([attr]), onOOB);
        }

        void border(chtype left, chtype right, chtype top, chtype bottom,
                chtype topLeft, chtype topRight, 
                chtype bottomLeft, chtype bottomRight)
        {
            throwUnlessValid();
            nc.wborder(ptr, left, right, top, bottom, topLeft, topRight, bottomLeft, bottomRight);
        }

        void border(cchar_t left, cchar_t right, cchar_t top, cchar_t bottom,
                cchar_t topLeft, cchar_t topRight, 
                cchar_t bottomLeft, cchar_t bottomRight)
        {
            throwUnlessValid();
            nc.wborder_set(ptr, 
                    &left, &right, &top, &bottom, 
                    &topLeft, &topRight, &bottomLeft, &bottomRight);
        }

        void box(cchar_t vertical, cchar_t horizontal)
        {
            throwUnlessValid();
            nc.box_set(ptr, &vertical, &horizontal);
        }

        void box(chtype v, chtype h)
        {
            throwUnlessValid();
            nc.box(ptr, v, h);
        }

        void delch(int y, int x)
        {
            throwUnlessValid();
            if (nc.mvwdelch(ptr, y, x) != OK)
                throw new NCException("Failed to delete character from position %s:%s", y, x);
        }

        void delch()
        {
            throwUnlessValid();
            nc.wdelch(ptr);
        }

        void insert(chtype ch)
        {
            throwUnlessValid();
            nc.winsch(ptr, ch);
        }

        void insert(int y, int x, chtype ch)
        {
            throwUnlessValid();
            if (nc.mvwinsch(ptr, y, x, ch) != OK)
                throw new NCException("Failed to insert a character at position %s:%s", y, x);
        }

        void insert(string s)
        {
            import std.string;
            throwUnlessValid();
            /* This is unfortunate, but none of 'insstr' family functions
               accept immutable strings, the result of toStringz. 
               */
            nc.winsstr(ptr, cast(char*) (s.toStringz));
        }

        void insert(int y, int x, string s)
        {
            import std.string;
            throwUnlessValid();
            if (nc.mvwinsstr(ptr, y, x, cast(char*) (s.toStringz)) != OK)
                throw new NCException("Failed to insert a string at position %s:%s", y, x);
        }

        void insert(string s, int n)
        {
            import std.string;
            throwUnlessValid();
            nc.winsnstr(ptr, cast(char*) (s.toStringz), n);
        }

        void insert(int y, int x, string s, int n)
        {
            import std.string;
            throwUnlessValid();
            /* This fails to compile if template parameters list is omitted.
               Dunno why.
               */
            if (nc.mvwinsnstr!(WINDOW, int, char)(ptr, y, x, cast(char*) (s.toStringz), n) 
                    != OK)
                throw new NCException("Failed to insert a string at position %s:%s", y, x);
        }

        void hline(int y, int x, chtype ch, int n)
        {
            throwUnlessValid();
            if (nc.mvwhline(ptr, y, x, ch, n) != OK)
                throw new NCException("Failed to draw a horizontal line at %s:%s", y, x);
        }

        void hline(int y, int x, cchar_t ch, int n)
        {
            throwUnlessValid();
            try {
                move(y, x);
                hline(ch, n);
            } catch (NCException e) {
                throw new NCException("Failed to draw a horizontal line at %s:%s", y, x);
            }
        }

        void hline(chtype ch, int n)
        {
            throwUnlessValid();
            nc.whline(ptr, ch, n);
        }

        void hline(cchar_t ch, int n)
        {
            throwUnlessValid();
            nc.whline_set(ptr, &ch, n);
        }

        /* Overlays this window on top of another (non-destructively). */
        void overlay(Window target)
        {
            throwUnlessValid();
            if (nc.overlay(ptr, target.ptr) == ERR)
                throw new NCException("Failed to overlay a window");
        }

        /* Overwrites this window on top of another (destructively). */
        void overwrite(Window target)
        {
            throwUnlessValid();
            if (nc.overwrite(ptr, target.ptr) == ERR)
                throw new NCException("Failed to overwrite a window");
        }

        private void setAttr(A: chtype)(A attr = Attr.normal)
        {
            throwUnlessValid();
            if (nc.wattrset(ptr, attr) != OK)
                throw new NCException("Failed to set attribute '%s'", attr);
        }

        void vline(int y, int x, chtype ch, int n)
        {
            throwUnlessValid();
            if (nc.mvwvline(ptr, y, x, ch, n) != OK)
                throw new NCException("Failed to draw a vertical line at %s:%s", y, x);
        }

        void vline(int y, int x, cchar_t ch, int n)
        {
            throwUnlessValid();
            try {
                move(y, x);
                vline(ch, n);
            } catch (NCException e) {
                throw new NCException("Failed to draw a vertical line at %s:%s", y, x);
            }
        }

        void vline(chtype ch, int n)
        {
            throwUnlessValid();
            nc.wvline(ptr, ch, n);
        }

        void vline(cchar_t ch, int n)
        {
            throwUnlessValid();
            nc.wvline_set(ptr, &ch, n);
        }

        /* ---------- various manipulations ---------- */

        void bkgd(chtype ch)
        {
            throwUnlessValid();
            nc.wbkgd(ptr, ch);
        }

        void bkgdset(chtype ch)
        {
            throwUnlessValid();
            nc.wbkgdset(ptr, ch);
        }

        void clear()
        {
            throwUnlessValid();
            nc.wclear(ptr);
        }

        void clearToBottom()
        {
            throwUnlessValid();
            nc.wclrtobot(ptr);
        }

        void clearToEOL()
        {
            throwUnlessValid();
            nc.wclrtoeol(ptr);
        }

        void deleteln()
        {
            throwUnlessValid();
            nc.wdeleteln(ptr);
        }

        void erase()
        {
            throwUnlessValid();
            nc.werase(ptr);
        }

        void insdel(int n)
        {
            throwUnlessValid();
            nc.winsdelln(ptr, n);
        }

        void insertln()
        {
            throwUnlessValid();
            nc.winsertln(ptr);
        }

        void scroll(int n)
        {
            throwUnlessValid();
            if (nc.wscrl(ptr, n) != OK)
                throw new NCException("Failed to scroll a window by %s lines", n);
        }

        void timeout(int ms)
        {
            throwUnlessValid();
            nc.wtimeout(ptr, ms);
        }

        /* ---------- information retrieval ---------- */

        int getch()
        {
            throwUnlessValid();
            int res = nc.wgetch(ptr);
            if (res == ERR)
                throw new NCException("Failed to get a character");
            return res;
        }

        /* This should be preferred over plain 'getch' if you care about your
           program being Unicode-aware. 
           */
        WChar getwch()
        {
            throwUnlessValid();
            wint_t chr;
            int res = nc.wget_wch(ptr, &chr);
            if (res == nc.KEY_CODE_YES)
                return WChar(chr, true);
            else if (res == OK)
                return WChar(chr, false);
            else
                throw new NCException("Failed to get a wide character");
        }

        int curX() @property
        {
            throwUnlessValid();
            return nc.getcurx(ptr);
        }

        int curY() @property
        {
            throwUnlessValid();
            return nc.getcury(ptr);
        }

        int width() @property
        {
            throwUnlessValid();
            return nc.getmaxx(ptr) + 1;
        }

        int height() @property
        {
            throwUnlessValid();
            return nc.getmaxy(ptr) + 1;
        }

        string getstr(int maxLength, bool echoChars = true)
        {
            import std.conv;
            throwUnlessValid();
            const bool isEcho = screen.echoMode;
            screen.echo(echoChars);
            scope(exit) screen.echo(isEcho);

            wint_t[] buffer = new wint_t[maxLength + 1];
            buffer[$ - 1] = 0;
            if (nc.wgetn_wstr(ptr, buffer.ptr, maxLength) != OK)
                throw new NCException("Failed to get a string");
            string res;
            res.reserve(buffer.length);
            foreach (ch; buffer)
                res ~= text(ch);
            return res;
        }

        string getstr(bool echoChars = true)
        {
            throwUnlessValid();
            return getstr(ch => true, echoChars);
        }

        string getstr(bool delegate(wint_t) predicate, bool echoChars = true)
        {
            import std.conv;
            throwUnlessValid();

            bool isEcho = screen.echoMode;
            screen.echo(false);
            scope(exit) screen.echo(isEcho);

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
                        x = screen.cols - 1;
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
            throwUnlessValid();

            auto buffer = new chtype[screen.lines * screen.cols + 1];
            buffer[$ - 1] = 0;
            nc.winchstr(ptr, buffer.ptr);
            return buffer.until(0).array.dup;
        }

        chtype[] inchstr(int n)
        {
            import std.algorithm;
            import std.array;
            throwUnlessValid();
            
            auto buffer = new chtype[n + 1];
            buffer[$ - 1] = 0;
            nc.winchnstr(ptr, buffer.ptr, n);
            return buffer.until(0).array.dup;
        }

        chtype[] inchstr(int y, int x)
        {
            throwUnlessValid();
            move(y, x);
            return inchstr;
        }

        chtype[] inchstr(int y, int x, int n)
        {
            throwUnlessValid();
            move(y, x);
            return inchstr(n);
        }
}
