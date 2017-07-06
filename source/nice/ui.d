/* UI module

   Provides UI class and several UI elements.

   It publicly imports nice.curses, so if you use it there's no need to import
   both.

   */

module nice.ui;

public import nice.curses;

/* ---------- core stuff ---------- */

/* A collection of UI elements. */
class UI
{
    protected:
        Curses curses;
        Window window;
        UIElement[] elements;
        int focus;
        Config cfg;

    public:
        struct Config
        {
            int[] nextElemKeys = ['\t', '+', Key.npage];
            int[] prevElemKeys = ['\b', '-', Key.ppage];
        }

        /* ---------- creation ---------- */

        this(Curses curses, Window window, Config cfg = Config())
        {
            this.curses = curses;
            this.window = window;
            this.cfg = cfg;
        }

        /* Use stdscr. */
        this(Curses curses, Config cfg = Config())
        {
            this.curses = curses;
            this.window = curses.stdscr;
            this.cfg = cfg;
        }

        /* ---------- manipulation ---------- */

        /* Processes a keystroke. Returns true if keystroke was processed by 
           the UI or an element. */
        bool keystroke(int key)
        {
            import std.algorithm;

            bool res = false;
            if (cfg.nextElemKeys.canFind(key)) {
                changeFocus(+1);
                res = true;
            } else if (cfg.prevElemKeys.canFind(key)) {
                changeFocus(-1);
                res = true;
            } else {
                res = elements[focus].keystroke(key);
            }
            draw(true);
            return res;
        }

        /* Draws the UI. */
        void draw(bool erase = true)
        {
            if (erase) window.erase;
            foreach (i, elem; elements)
                if (elem.visible)
                    drawElement(elem, i == focus);
            window.refresh;
            curses.update;
        }

        void drawElement(UIElement elem, bool active)
        {
            elem.draw(active);
            elem.window.overwrite(window);
        }

        /* Moves the whole UI to the different window. */
        void move(Window to)
        {
            window = to;
        }

        void addElement(UIElement e)
        {
            elements ~= e;
        }

        /* Changes currently active element by shifting focus by a given amount. */
        void changeFocus(int by)
        {
            int oldFocus = focus;
            elements[focus].unfocus();
            int direction = by > 0 ? +1 : -1;
            int len = cast(int) elements.length;
            /* This will still focus on an unfocusable element if there're 
               only such elements in the UI. */
            do {
                focus += direction;
                /* Casts are safe as long as number of elements is reasonable. */
                if (focus < 0) focus += len;
                if (focus >= elements.length) focus -= len;
                if (focus == oldFocus) break;
            } while (!elements[focus].focusable || !elements[focus].visible);
            elements[focus].focus();
        }

        /* Change currently active element to a given element. */
        void changeFocus(UIElement newFocused)
        {
            elements[focus].unfocus();
            drawElement(elements[focus], false);
            int i;
            foreach (elem; elements) { /* Can't do 'i, elem' since 'i' would
                                          then be size_t. */
                if (newFocused is elem) {
                    focus = i;
                    break;
                }
                i++;
            }
            newFocused.focus();
            drawElement(newFocused, true);
        }
}

/* Base class for UI elements. */
abstract class UIElement
{
    protected:
        Window window;

        this(UI ui, int nlines, int ncols, int y, int x)
        {
            this.window = ui.curses.newWindow(nlines, ncols, y, x);
            ui.addElement(this);
        }

    public:
        bool visible = true;
        bool focusable = true;

        void draw(bool active);
        void focus() { /* No-op by default. */ }
        void unfocus() { /* Also no-op. */ }
        /* Should return true if a keypress has been processed. */
        bool keystroke(int key) { return false; }
}

/* This is used to communicate UI events from elements to the processing loop. */
abstract class UISignal: Throwable
{
    UIElement sender;

    this(UIElement sender)
    {
        super("Unhandled UI signal");
        this.sender = sender;
    }
}

/* ---------- concrete UI elements ---------- */

class Menu(T): UIElement
{
    protected:
        string delegate() header;
        int choice;
        int curScroll;
        string delegate()[] entries;
        T[] values;
        Config cfg;

    public:
        struct Config
        {
            int[] down = ['j', Key.down];
            int[] up = ['k', Key.up];
            int[] enter = ['\n', '\r', Key.enter];
            Align alignment = Align.center;
        }

        /* Thrown when 'Enter' is pressed while in the menu. */
        class Signal: UISignal
        {
            T value;

            this() 
            { 
                auto m = this.outer;
                super(m); 
                value = m.values[m.choice];
            }
        }

        this(UI ui, int nlines, int ncols, int y, int x,
                string delegate() header, Config cfg = Config())
        {
            super(ui, nlines, ncols, y, x);
            this.header = header;
            this.cfg = cfg;
        }

        this(UI ui, int nlines, int ncols, int y, int x, string header,
                Config cfg = Config())
        {
            string dg() { return header; }
            this(ui, nlines, ncols, y, x, &dg, cfg);
        }

        auto chosenValue() const @property { return values[choice]; }

        void addEntry(T value, string delegate() text)
        {
            values ~= value;
            entries ~= text;
        }

        void addEntry(T value, string text)
        {
            values ~= value;
            string dg() { return text; }
            entries ~= &dg;
        }

        /* ---------- internal things ---------- */

    private:

        void scroll(int by)
        {
            curScroll += by;
            if (curScroll < 0) curScroll = 0;
            /* The cast is most likely safe. I can't imagine a menu where difference
               between size_t and int is significant. */
            if (curScroll >= entries.length) curScroll = cast(int) entries.length - 1;
        }

        void choose(int shift)
        {
            choice += shift;
            /* The cast is safe since menus are generally short. */
            if (choice < 0) choice = 0;
            if (choice >= entries.length) choice = cast(int) entries.length - 1;
            if (choice >= curScroll + window.height || choice < curScroll) scroll(shift);
        }

    public:

        /* ---------- inherited stuff ---------- */

        override void draw(bool active)
        {
            auto headerAttr = active ? Attr.reverse : Attr.normal;
            int w = window.width;
            int h = window.height;
            window.addAligned(0, header(), cfg.alignment, headerAttr);
            int offset = 3;
            for (int i = 0; i < h - offset; i++) {
                int entry = i + curScroll;
                if (entry >= entries.length) break;
                auto attr = entry == choice ? Attr.reverse : Attr.normal;
                window.addAligned(offset + i, entries[entry](), cfg.alignment, attr);
            }
        }

        override bool keystroke(int key) 
        {
            import std.algorithm;
            if (cfg.down.canFind(key)) {
                choose(+1);
                return true;
            } else if (cfg.up.canFind(key)) {
                choose(-1);
                return true;
            } else if (cfg.enter.canFind(key)) {
                throw new Signal();
            }
            return false;
        }
}

class Button: UIElement
{
    protected:
        string delegate() text;
        Config cfg;

    public:
        /* Thrown when the button is pressed. */
        class Signal: UISignal
        {
            this() { super(this.outer); }
        }

        struct Config
        {
            Align alignment = Align.left;
            int[] enter = ['\n', '\r', Key.enter];
        }

        this(UI ui, int nlines, int ncols, int y, int x, 
                string delegate() text,
                Config cfg = Config())
        {
            super(ui, nlines, ncols, y, x);
            this.text = text;
            this.cfg = cfg;
        }

        this(UI ui, int nlines, int ncols, int y, int x, string text,
                Config cfg = Config())
        {
            string dg() { return text; }
            this(ui, nlines, ncols, y, x, &dg, cfg);
        }

        /* ---------- inherited stuff ---------- */

        override void draw(bool active)
        {
            auto attr = active ? Attr.reverse : Attr.normal;
            window.addAligned(0, text(), cfg.alignment, attr);
        }

        override bool keystroke(int key)
        {
            import std.algorithm;
            if (cfg.enter.canFind(key))
                throw new Signal();
            return false;
        }
}

class Label: UIElement
{
    protected:
        string delegate() text;
        Config cfg;

    public:
        struct Config
        {
            Align alignment = Align.left;
            int attribute = Attr.normal;
        }

        this(UI ui, int nlines, int ncols, int y, int x,
                string delegate() text,
                Config cfg = Config())
        {
            super(ui, nlines, ncols, y, x);
            this.text = text;
            this.cfg = cfg;
            focusable = false;
        }

        this(UI ui, int nlines, int ncols, int y, int x, string text,
                Config cfg = Config())
        {
            string dg() { return text; }
            this(ui, nlines, ncols, y, x, &dg, cfg);
        }

        /* ---------- inherited stuff ---------- */

        override void draw(bool active)
        {
            window.addAligned(0, text(), cfg.alignment, cfg.attribute);
        }
}

class ProgressBar: UIElement
{
    protected:
        Config cfg;
        double percentage_ = 0;

    public:
        struct Config
        {
            char empty = '-';
            char filled = '#';
            int emptyAttr = Attr.normal;
            int filledAttr = Attr.normal;
            bool vertical = false;
            bool reverse = false;
        }

        this(UI ui, int nlines, int ncols, int y, int x, Config cfg = Config())
        {
            super(ui, nlines, ncols, y, x);
            this.cfg = cfg;
            focusable = false;
        }

        double percentage() const @property { return percentage_; }
        void percentage(double p) @property 
        { 
            if (p < 0) p = 0;
            if (p > 1) p = 1;
            percentage_ = p; 
        }

        /* ---------- inherited stuff ---------- */

        override void draw(bool active)
        {
            if (cfg.vertical) {
                int n = cast(int) (window.height * percentage);
                if (cfg.reverse) {
                    /* Fill from the top downwards. */
                    foreach (y; 0 .. n) 
                        foreach (x; 0 .. window.width)
                            window.addch(y, x, cfg.filled, cfg.filledAttr);
                    foreach (y; n .. window.height)
                        foreach (x; 0 .. window.width)
                            window.addch(y, x, cfg.empty, cfg.emptyAttr);
                } else {
                    /* Fill from the bottom up. */
                    foreach (k; 1 .. n + 1)
                        foreach (x; 0 .. window.width)
                            window.addch(window.height - k, x, cfg.filled, cfg.filledAttr);
                    foreach (k; n + 1 .. window.height + 1)
                        foreach (x; 0 .. window.width)
                            window.addch(window.height - k, x, cfg.empty, cfg.emptyAttr);
                }
            } else {
                int n = cast(int) (window.width * percentage);
                if (cfg.reverse) {
                    /* Fill from the right to the left. */
                    foreach (k; 1 .. n)
                        foreach (y; 0 .. window.height)
                            window.addch(y, window.width - k, cfg.filled, cfg.filledAttr);
                    foreach (k; n + 1 .. window.width + 1)
                        foreach (y; 0 .. window.height)
                            window.addch(y, window.width - k, cfg.empty, cfg.emptyAttr);
                } else {
                    /* Fill from the left to the right. */
                    foreach (x; 0 .. n)
                        foreach (y; 0 .. window.height)
                            window.addch(y, x, cfg.filled, cfg.filledAttr);
                    foreach (x; n .. window.width)
                        foreach (y; 0 .. window.height)
                            window.addch(y, x, cfg.empty, cfg.emptyAttr);
                }
            } /* if vertical */
        } /* draw */
}

class TextInput: UIElement
{
    protected:
        string text;
        Config cfg;
        int scroll;

    public:
        /* Thrown when the user finishes typing. */
        class Signal: UISignal
        {
            string text;

            this(string text)
            { 
                super(this.outer);
                this.text = text;
            }
        }

        struct Config
        {
            int[] start = ['\n', '\r', 'i', Key.enter];
            string emptyText = "<empty>";
        }

        this(UI ui, int nlines, int ncols, int y, int x, string initialText,
                Config cfg = Config())
        {
            super(ui, nlines, ncols, y, x);
            text = initialText;
            this.cfg = cfg;
        }

        /* ---------- inherited stuff ---------- */

        override bool keystroke(int key)
        {
            import std.algorithm;
            if (!cfg.start.canFind(key)) return false;

            window.erase;
            window.move(0, 0);
            string str = window.getstr;
            text = str;
            throw new Signal(str);
        } 

        override void draw(bool active)
        {
            auto attr = active ? Attr.reverse : Attr.normal;
            if (text != "")
                window.addstr(0, 0, text, attr);
            else
                window.addstr(0, 0, cfg.emptyText, attr);
        }
}

class CheckBox: UIElement
{
    protected:
        string delegate() text;
        Config cfg;
        Window textWindow;
        Window markWindow;

    public:
        bool checked;

        /* Thrown when the user checks/unchecks the box. */
        class Signal: UISignal
        {
            bool checked;
            this()
            {
                super(this.outer);
                checked = this.outer.checked;
            }
        }

        struct Config
        {
            char whenChecked = '+';
            char whenUnchecked = '-';
            int[] switchKeys = ['\n', '\r', Key.enter];
            /* Denotes the position of checked/unchecked mark. Note that the
               element should be at least 4 cells wide for left and right
               alignments and at least 2 cells high for central alignment. */
            Align alignment = Align.left; 
        }

        this(UI ui, int nlines, int ncols, int y, int x, 
                string delegate() text, Config cfg = Config())
        {
            super(ui, nlines, ncols, y, x);
            this.text = text;
            this.cfg = cfg;
            enum width = 3;
            final switch (cfg.alignment) {
                case Align.left:
                    markWindow = window.derwin(nlines, width, 0, 0);
                    textWindow = window.derwin(nlines, ncols - width, 0, width);
                    break;
                case Align.center:
                    markWindow = window.derwin(1, ncols, nlines - 1, 0);
                    textWindow = window.derwin(nlines - 1, ncols, 0, 0);
                    break;
                case Align.right:
                    markWindow = window.derwin(nlines, width, 0, ncols - width);
                    textWindow = window.derwin(nlines, ncols - width, 0, 0);
                    break;
            }
        }

        this(UI ui, int nlines, int ncols, int y, int x,
                string text, Config cfg = Config())
        {
            string dg() { return text; }
            this(ui, nlines, ncols, y, x, &dg, cfg);
        }

        /* ---------- inherited stuff ---------- */

        override bool keystroke(int key)
        {
            import std.algorithm;
            if (cfg.switchKeys.canFind(key)) {
                checked = !checked;
                throw new Signal();
            }
            return false;
        }

        override void draw(bool active)
        {
            auto attr = active ? Attr.reverse : Attr.normal;
            char mark = checked ? cfg.whenChecked : cfg.whenUnchecked;
            final switch (cfg.alignment) {
                case Align.left:
                    markWindow.addch(markWindow.height / 2, 1, mark);
                    textWindow.addAligned(textWindow.height / 2, text(), Align.left, attr);
                    break;
                case Align.center:
                    markWindow.addch(0, markWindow.width / 2, mark);
                    textWindow.addAligned(0, text(), Align.center, attr);
                    break;
                case Align.right:
                    markWindow.addch(markWindow.height / 2, 1, mark);
                    textWindow.addAligned(textWindow.height / 2, text(), Align.right, attr);
                    break;
            }
        }
}
