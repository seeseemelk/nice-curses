/* Base UI module

   Provides base classes used in UI making. 

   It publicly imports nice.curses, so if you use it there's no need to import
   both.

   */

module nice.ui.base;

public import nice.curses;

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
            WChar[] nextElemKeys = [WChar('\t'), WChar('+'), WChar(Key.npage)];
            WChar[] prevElemKeys = [WChar('\b'), WChar('-'), WChar(Key.ppage)];
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
        bool keystroke(WChar key)
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
                if (elements != [])
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
                if (elem.visible) drawElement(elem, i == focus);
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
        bool keystroke(WChar key) { return false; }
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
