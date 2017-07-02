/* UI module.

   Provides UI class and some UI elements classes.

   Publicly imports 'nice.curses', so there's no need to import both.

   */

module nice.ui;

public import nice.curses;

/* ---------- Core stuff ---------- */

class UI
{
    protected:
        Curses curses;
        Window window;
        UIElement[] elements;
        int focus;
        Config cfg;

    public:
        /* ---------- creation ---------- */
        struct Config 
        {
            int[] nextElemKeys = ['\t', '+', Key.npage];
            int[] prevElemKeys = ['\b', '-', Key.ppage];
        }

        this(Curses curses, Window window, Config cfg)
        {
            this.cfg = cfg;
            this.curses = curses;
            this.window = window;
        }

        /* Use default config. */
        this(Curses curses, Window window)
        {
            this(curses, window, Config());
        }

        /* ---------- manipulation ---------- */

        /* Processes a keystroke. */
        void keystroke(Curses c, int key)
        {
            import std.algorithm;

            if (cfg.nextElemKeys.canFind(key))
                changeFocus(+1);
            else if (cfg.prevElemKeys.canFind(key))
                changeFocus(-1);
            else
                elements[focus].keystroke(c, window, key);
        }

        /* Draws the UI and associated elements. */
        void draw()
        {
            window.erase;
            foreach (i, elem; elements)
                if (elem.visible) 
                    elem.draw(window, focus == i);
        }

        /* Moves whole UI to a different window. */
        void move(Window to)
        {
            window = to;
        }

        /* Adds and element to the UI and returns it. */
        UIElement addElement(UIElement e)
        {
            elements ~= e;
            return e;
        }

        /* Changes currently active element. */
        void changeFocus(int by)
        {
            int oldFocus = focus;
            elements[focus].unfocus(curses, window);
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
            elements[focus].focus(curses, window);
        }

        /* Ditto. */
        void changeFocus(UIElement newFocused)
        {
            elements[focus].unfocus(curses, window);
            int i;
            foreach (elem; elements) { /* Can't do 'i, elem' since i would then
                                          be size_t. */
                if (newFocused is elem) {
                    focus = i;
                    break;
                }
                i++;
            }
            newFocused.focus(curses, window);
        }
}

abstract class UIElement
{
    protected:
        /* The coordinates for every element indicate its upper-left corner. */
        int x, y, w, h;

        this(int x, int y, int w, int h)
        {
            this.x = x;
            this.y = y;
            this.w = w;
            this.h = h;
        }

    public:
        bool visible = true;
        bool focusable = true;

        void draw(Window window, bool active);
        void focus(Curses curses, Window window) { /* No-op by default. */ }
        void unfocus(Curses curses, Window window) { /* Also no-op. */ }
        void keystroke(Curses curses, Window window, int key) { /* Ditto. */ }
}

/* This is used to communicate UI events from elements to the processing loop. */
abstract class UISignal: Throwable
{
    public UIElement sender;

    this(UIElement sender)
    {
        super("Unhandled UI signal");
        this.sender = sender;
    }
}

/* ---------- Concrete UI elements ---------- */

class Menu(T): UIElement
{
    private:
        string header;
        int choice;
        int curScroll;
        string[] entries;
        T[] values;
        KeyConfig keyCfg;

    public:
        struct KeyConfig
        {
            int[] down = ['j', Key.down];
            int[] up = ['k', Key.up];
            int[] enter = ['\n', '\r', Key.enter];
        }

        auto chosenValue() const @property { return values[choice]; }

        this(int x, int y, int w, int h, string header, KeyConfig cfg = KeyConfig())
        {
            super(x, y, w, h);
            this.header = header;
            keyCfg = cfg;
        }

        void addEntry(T value, string text)
        {
            entries ~= text;
            values ~= value;
        }

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
            if (choice >= curScroll + h || choice < curScroll) scroll(shift);
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

        /* ---------- inherited stuff ---------- */

        override void draw(Window onWindow, ColorTable colors, bool active)
        {
            auto headerAttr = active ? Attr.normal : Attr.reverse;
            onWindow.addstrc(y, x + w / 2, header, headerAttr);
            int offset = 3;
            for (int i = 0; i < h - offset; i++) {
                int entry = i + curScroll;
                if (entry >= entries.length) break;
                auto attr = entry == choice ? Attribute.reverse : Attribute.normal;
                onWindow.addstrc(offset + i, x + w / 2, entries[entry], attr);
            }
        }

        override void keystroke(Curses c, int key) 
        {
            import std.algorithm;
            if (cfg.keyCfg.down.canFind(key)) {
                choose(+1);
            } else if (cfg.keyCfg.up.canFind(key)) {
                choose(-1);
            } else if (cfg.keyCfg.enter.canFind(key)) {
                throw new Signal();
            }
        }
}

class StaticButton: UIElement
{
    private: 
        string text;
        int alignment; /* Negative means shift to the left, 0 - centered,
                         positive - shift to the right. */

    public:
        this(int x, int y, int w, string text, int alignment)
        {
            super(x, y, w, 1);
            this.text = text;
            this.alignment = alignment;
        }

        override void draw(Window window, bool active)
        {
            auto attr = active ? Attr.reverse : Attr.normal;
            int len = cast(int) text.length; /* If a button has more text than
                                                fits into an int, it's gonna
                                                fail anyway. */
            if (alignment < 0) {
                window.addnstr(y, x, text, w, attr);
            } else if (alignment == 0) {
                int start = x - len / 2;
                int left = w - start;
                window.addnstr(y, start, text, left, attr);
            } else {
                if (len > w) {
                    /* There's no space for some leading characters. */
                    window.addnstr(y, x, text[$ - w .. $], w, attr);
                } else {
                    /* Everything fits. */
                    window.addnstr(y, x + w - len, text, len, attr);
                }
            }
        } /* draw */

        class Signal: UISignal
        {
            this()
            {
                super(this.outer);
            }
        }

        override void keystroke(Curses curses, Window window, int key)
        {
            throw new Signal();
        }
} /* StaticButton */

class TextLabel: UIElement
{
    private:
        string delegate() text;
        Window window;

    public:
        override void draw(Window otherWindow, bool active)
        {
            window.addstr(0, 0, text());
            window.overlay(otherWindow);
        }

        this(Curses c, string delegate() text, int x, int y, int w, int h)
        {
            super(x, y, w, h);
            window = c.newWindow(h, w, y, x);
            this.text = text;
            focusable = false;
        }
}

/* TextInputs are always two spaces high. */
class TextInput: UIElement
{
    private:
        Config cfg;
        string caption;
        string text;

    public:
        struct Config
        {
            int[] enter = ['\n', '\r', Key.enter];
        }

        this(string caption, Config cfg, int x, int y, int w)
        {
            super(x, y, w, 2);
            this.caption = caption;
            this.cfg = cfg;
        }

        override void keystroke(Curses curses, Window window, int key)
        {
            import std.algorithm;
            if (cfg.enter.canFind(key)) {
                /* Start text editing. */
                window.move(y, x);
                text = window.getstr(w);
            } 
        }

        override void draw(Window window, bool active)
        {
            auto attr = active ? Attr.reverse : Attr.normal;
            window.addstr(y, x, caption);
            window.addstr(y + 1, x, text);
        }
}
