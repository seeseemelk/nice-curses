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

        /* Processes a keystroke. */
        void keystroke(int key)
        {
            import std.algorithm;

            if (cfg.nextElemKeys.canFind(key)) {
                changeFocus(+1);
            } else if (cfg.prevElemKeys.canFind(key)) {
                changeFocus(-1);
            } else {
                elements[focus].keystroke(key);
                drawElement(elements[focus], true);
                window.refresh;
                curses.update;
            }
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
            drawElement(elements[focus], false);
            int direction = by > 0 ? +1 : -1;
            /* This will still focus on an unfocusable element if there're 
               only such elements in the UI. */
            while (!elements[focus].focusable && oldFocus != focus) {
                focus += direction;
                /* Casts are safe as long as number of elements is reasonable. */
                int len = cast(int) elements.length;
                if (focus < 0) focus += len;
                if (focus >= elements.length) focus -= len;
            }
            elements[focus].focus();
            drawElement(elements[focus], true);
            window.refresh;
            curses.update;
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
        void keystroke(int key) { /* Ditto. */ }
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
    private:
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

        override void keystroke(int key) 
        {
            import std.algorithm;
            if (cfg.down.canFind(key)) {
                choose(+1);
            } else if (cfg.up.canFind(key)) {
                choose(-1);
            } else if (cfg.enter.canFind(key)) {
                throw new Signal();
            }
        }
}

class Button: UIElement
{
    private:
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
            final switch (cfg.alignment) {
                case Align.left: 
                    window.addAligned(0, 0, text(), Align.left, attr);
                    break;
                case Align.center:
                    window.addAligned(0, window.width / 2, text(), Align.center, attr);
                    break;
                case Align.right:
                    window.addAligned(0, window.maxX, text(), Align.right, attr);
                    break;
            }
        }

        override void keystroke(int key)
        {
            import std.algorithm;
            if (cfg.enter.canFind(key))
                throw new Signal();
        }
}
