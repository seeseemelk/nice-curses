/* UI elements module.

   Provides some UI element classes.

   It publicly imports both nice.curses and nice.ui.base.

   */

module nice.ui.elements;

public import nice.curses;
public import nice.ui.base;

private alias W = WChar; /* There's a lot of default keys below. */

class Menu(T): UIElement
{
    protected:
        string delegate() header;
        int choice;
        int curScroll;
        string delegate()[] entries;
        T[] values;
        Config cfg;
        bool signalChange;

    public:
        struct Config
        {
            WChar[] down = [W('j'), W(Key.down)];
            WChar[] up = [W('k'), W(Key.up)];
            WChar[] enter = [W('\n'), W('\r'), W(Key.enter)];
            Align alignment = Align.center;
            bool signalChange = false;
        }

        /* Thrown when 'Enter' is pressed while in the menu or when the chosen
           element changes (if signalChange is set). */
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
            window.erase;
            auto headerAttr = active ? Attr.reverse : Attr.normal;
            int w = window.width;
            int h = window.height;
            window.addAligned(0, header(), cfg.alignment, headerAttr);
            int offset = 5;
            for (int i = 0; i < h - offset; i++) {
                int entry = i + curScroll;
                if (entry >= entries.length) break;
                auto attr = entry == choice ? Attr.reverse : Attr.normal;
                window.addAligned(offset + i, entries[entry](), cfg.alignment, attr);
            }
        }

        override bool keystroke(WChar key) 
        {
            import std.algorithm;
            if (values == []) return false;
            if (cfg.down.canFind(key)) {
                choose(+1);
                if (cfg.signalChange)
                    throw new Signal();
                return true;
            } else if (cfg.up.canFind(key)) {
                choose(-1);
                if (cfg.signalChange)
                    throw new Signal();
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
            WChar[] enter = [W('\n'), W('\r'), W(Key.enter)];
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
            window.erase;
            auto attr = active ? Attr.reverse : Attr.normal;
            window.addAligned(0, text(), cfg.alignment, attr);
        }

        override bool keystroke(WChar key)
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
            chtype attribute = Attr.normal;
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
            window.erase;
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
            wint_t empty = '-';
            wint_t filled = '#';
            chtype emptyAttr = Attr.normal;
            chtype filledAttr = Attr.normal;
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
            window.erase;
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
        int scroll;
        Config cfg;

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
            WChar[] start = [W('\n'), W('\r'), W('i'), W(Key.enter)];
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

        override bool keystroke(WChar key)
        {
            import std.algorithm;
            if (!cfg.start.canFind(key)) return false;

            window.erase;
            window.move(0, 0);
            text = window.getstr;
            throw new Signal(text);
        } 

        override void draw(bool active)
        {
            window.erase;
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
            wint_t whenChecked = '+';
            wint_t whenUnchecked = '-';
            WChar[] switchKeys = [W('\n'), W('\r'), W(Key.enter)];
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

        override bool keystroke(W key)
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
            window.erase;
            wint_t mark = checked ? cfg.whenChecked : cfg.whenUnchecked;
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

class NumberBox: UIElement
{
    protected:
        int value_;
        Config cfg;

    public:
        int value() const @property { return value_; }
        int value(int k) @property
        {
            int old = value_;
            if (k > cfg.max) k = cfg.max;
            if (k < cfg.min) k = cfg.min;
            value_ = k;
            return old;
        }

        /* Thrown when the user changes value - either through typing or
           pressing an increment/decrement button. */
        class Signal: UISignal
        {
            int value;
            int delta;
            int old;

            this(int old)
            {
                super(this.outer);
                this.old = old;
                this.value = this.outer.value;
                delta = value - old;
            }
        }

        struct Config
        {
            WChar[] start = [W('\n'), W('\r'), W('i'), W(Key.enter)];
            WChar[] smallIncr = [W('k'), W('l'), W(Key.up), W(Key.right)];
            WChar[] bigIncr = [W('K'), W('L'), W(Key.sright)];
            WChar[] smallDecr = [W('j'), W('h'), W(Key.down), W(Key.left)];
            WChar[] bigDecr = [W('J'), W('H'), W(Key.sleft)];
            int min = int.min;
            int max = int.max;
            int smallStep = 1;
            int bigStep = 5;
            Align alignment = Align.center;
        }

        this(UI ui, int nlines, int ncols, int y, int x, int startingValue,
                Config cfg = Config())
        {
            super(ui, nlines, ncols, y, x);
            value = startingValue;
            this.cfg = cfg;
        }

        /* ---------- inherited stuff ---------- */

        override bool keystroke(WChar key)
        {
            import std.algorithm;

            int old = value;
            if (cfg.start.canFind(key)) {
                /* Read a number from the keyboard. */
                import std.conv;
                window.erase;
                window.move(0, 0);
                string str = window.getstr(ch => '0' <= ch && ch <= '9');
                try {
                    value = str.to!int;
                } catch (ConvException e) {
                    /* Can happen on an empty string. */
                    value = cfg.min;
                }
                throw new Signal(old);
            } else if (cfg.smallIncr.canFind(key)) {
                /* Small step increment. */
                throw new Signal(value = value + cfg.smallStep);
            } else if (cfg.bigIncr.canFind(key)) {
                /* Big step increment .*/
                throw new Signal(value = value + cfg.bigStep);
            } else if (cfg.smallDecr.canFind(key)) {
                /* Small step decrement. */
                throw new Signal(value = value - cfg.smallStep);
            } else if (cfg.bigDecr.canFind(key)) {
                /* Big step decrement. */
                throw new Signal(value = value - cfg.bigStep);
            }
            return false;
        } /* keystroke */

        override void draw(bool active)
        {
            import std.conv;
            window.erase;
            auto attr = active ? Attr.reverse : Attr.normal;
            window.addAligned(window.height / 2, value.to!string, cfg.alignment,
                    attr);
        }
}
