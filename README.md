# Introduction
Using D bindings of ncurses library directly is a bit of a pain - error codes
instead of exceptions, pointers instead of strings, multitude of functions to
do essentially the same thing make writing D programs quite awkward. 
'nice-curses' attempts to provide a nicer object-oriented interface to the
library, taking advantage of D's exception mechanism and its ability to
overload functions.

'nice-curses' can also serve as an UI library, providing several basic UI
elements and container for them.

The library consists of three modules: `nice.curses`, which provides wrappers
over ncurses library, `nice.ui.base`, which provides the basis on which UIs are
built, and `nice.ui.elements`, which provides some predefined UI element
classes. `nice.ui.base` publicly imports `nice.curses` and `nice.ui.elements`
publicly imports both `nice.curses` and `nice.ui.base`.

# Initialization
The library needs to be initialized prior to using it. Initialization is quite
simple: you create a Curses.Config struct (see Curses.Config subsection for
details) and feed it to the Curses constructor. In other words

    Curses.Config cfg = { /* Desired configuration. */ };
    auto curses = new Curses(cfg);

That's it. The library is initialized and ready for work. As a side note, 
consider adding `scope(exit) destroy(curses);` somewhere nearby.

## struct Curses.Config
A Curses.Config struct has following fields:
- `bool useColors = true` - set this to request color support from the library.
- `bool useStdColors = true` - set this to fill `colors` ColorTable field of a
  Curses object with color pairs of default colors.
- `bool disableEcho = false` - set this to enter noecho mode;
- `Mode mode = Mode.normal` - choose one of the terminal modes (consult your
  ncurses documentation for difference between them):
	- normal
	- cbreak
	- halfdelay
	- raw
- `int cursLevel = 1` - set cursor visibility. 0 means invisible, 1 means
  normal and 2 means very visible.
- `bool initKeypad = true` - set this to make all spawned windows to enter
  keypad mode (this is most likely what you want, consult `man keypad`).
- `bool nl = false` - when set, the program will enter `nl` mode, otherwise the
  program will enter `nonl` mode (consult ncurses docs for this).
- `bool nodelay = false` - when set, the program will enter nodelay mode.

# Usage as a ncurses wrapper
Once the library is set up, you can either create new windows with `newWindow`
method of a Curses object, or use its field `stdscr`. Perform some drawing on
them, then call `refresh` method of a Window object on each, and then call
`update` method of the Curses object.

## class Curses
Curses objects have following public fields:
- `Window stdscr` - default drawing Window.
- `ColorTable colors` - a container for defined color pairs.
- `static bool echoMode` - indicates whether the program is in echo or noecho
  mode.

Curses object provides following methods:
- `Window newWindow(int nlines, int ncols, int begin_y, int begin_x)` - create
  a new window.
- `Window duplicateWindow(Window which)` - create an exact copy of a window.
- `void deleteWindow(Window which)` - delete a window and all its subwindows.
- `void setMode(Mode mode, int delayForHD = 1)` - enter one of the terminal
  modes (normal, cbreak, halfdelay and raw). Optional argument `delayForHD`
sets the delay for halfdelay mode.

All the other methods are static:
- `static void beep()` - beeps.
- `static void delayOutput(int ms)` - pause the output for a given amount of
  milliseconds.
- `static void echo(bool set)` - enter either echo or noecho mode. 
- `static void flash()` - flashes the screen.
- `static void flushInput()` - discard any unprocessed input from the user.
- `static void nap(int ms)` - pause for a given number of milliseconds.
- `static void resetTTY()` - reset TTY to a previously saved state.
- `static void saveTTY()` - save TTY state.
- `static void setCursor(int level)` - set cursor visibility (0 means
  invisible, 1 - normal, 2 - very visible).
- `static void ungetch(int ch)` - put a character back into input.
- `static void update()` - perform actual drawing from the backbuffer.
- `static RGB colorContent(short color)` - returns the (red, green, blue) color
  content of a given color.
- `static string keyName(int key)` - return the name of a given key.

There are also several static properties:
- `static int lines` - number of lines in the screen.
- `static int cols` - number of columns in the screen.
- `static int maxColors` - maximum number of supported colors.
- `static int maxColorPairs` - maximum number of supported color pairs.
- `static int tabSize` - amount of spaces in a tab character.
- `static int escDelay` - the number of milliseconds to wait after reading an
  escape character.
- `static int baudrate` - the output speed of the terminal.
- `static bool canChangeColor` - indicates whether it's possible to redefine
  colors.
- `static bool hasColors` - indicates whether the terminal supports colors.

## class Window
Objects of Window class have a single public field: `ColorTable colors`, which
they inherit from the Curses object they were created with. There's no publicly
available constructor for Window class. You have to create them either via
`newWindow` method of the Curses class or via `subwin` and `derwin` methods of
the Window class.

These are the methods for general manipulation of windows:
- `void keypad(bool set)` - enter or leave keypad mode.
- `void move(int y, int x)` - move the cursor to the specified position. May
  throw a NCException if the move is impossible.
- `void moveWindow(int y, int x)` - move the window itself. May throw a
  NCException if the move would result in a part of the window being offscreen.
- `void refresh()` - makes next call to `Curses.update` draw the latest changes
  to the window.
- `void bkgd(chtype ch)` - see 'man 3 bkgd'.
- `void bkgdset(chtype ch)` - see 'man 3 bkgdset'.
- `void clear()` - clear the window. For difference with `erase` consult
  'man 3 clear'.
- `void clearToBottom()` - clear the window from the current cursor position to
  the bottom.
- `void clearToEOL()` - clear the window from the cursor position to the end of
  line.
- `void deleteln()` - delete a line under the cursor.
- `void erase()` - clear the screen. For difference with `clear` consult
  'man 3 clear'.
- `void insdel(int n)` - delete and insert `n` lines under the cursor.
- `void insertln()` - insert a line at the top of the current line.
- `void scroll(int n)` - scroll the window by `n` lines.

These are the methods for child windows management:
- `Window subwin(int nlines, int ncols, int y, int x)` - create a subwindow.
- `Window derwin(int nlines, int ncols, int y, int x)` - derive a window.
- `void deleteChild(Window child)` - deletes a child window.
For difference between `subwin` and `derwin` consult your ncurses documentation.

These are the drawing primitives. Those that take coordinates all throw a
NCException if the requested position is outside the window.
- `void addch(C: chtype, A: chtype)(int y, int x, C ch, A attr = Attr.normal)`
  Draws a single character at the given position with given attribute.
- `void addch(C: chtype, A: chtype)(C ch, A attr = Attr.normal)` Draws a single
  character at the current cursor position with given attribute.
- `void addstr(A: chtype)(int y, int x, string str, A attr = Attr.normal)`
  Draws a string at the given position with given attribute.
- `void addstr(A: chtype)(string str, A attr = Attr.normal)` Draws a string at
  the current cursor position with given attribute.
- `void addnstr(A: chtype)(int y, int x, string str, int n, A attr =
  Attr.normal)` Draws at most `n` characters from the string at the given
position with given attribute.
- `void addnstr(A: chtype)(string str, int n, A attr = Attr.normal)` Draws at
  most `n` characters from the string at the current cursor position with given
attribute.
- `void addAligned(A: chtype)(int y, int x, string str, Align alignment, A attr
  = Attr.normal)` The behaviour depends on the `alignment` parameter. If it's
`Align.left` then y and x are the coordinates of the text's upper-left corner,
and the text will be left-justified. If it's `Align.center` then y and x are
the coordinates of the first line's center, and the text will be centered
around this point. If it's `Align.right`, then y and x are the coordinates of
the text's upper-right corner, and the text will be right-justified. The text
that doesn't fit into the window will be silently discarded.
- `void addAligned(A: chtype)(int y, string str, Align alignment, A attr =
  Attr.normal)` Same as the previous, but uses the whole window's width and
figures out x coordinate from the alignment parameter.
- `void border(...)` - see 'man 3 border'.
- `void box(chtype vertical, chtype horizontal)` - see 'man 3 box'.
- `void delch(int y, int x)` - delete a character at the given position.
- `void delch()` - delete a character under the cursor.
- `void insert(int y, int x, chtype ch)` - insert a character at the given
  position.
- `void insert(chtype ch)` - insert a character at the cursor position.
- `void insert(int y, int x, string str)` - insert a string at the given
  position.
- `void insert(string str)` - insert a string at the current cursor position.
- `void hline(int y, int x, chtype ch, int n)` - draw a horizontal line of `n`
  characters at the given position.
- `void hline(chtype ch, int n)` - draw a horizontal line of `n` characters at
  the current cursor position.
- `void vline(int y, int x, chtype ch, int n)` - draw a vertical line of `n`
  characters at the given position.
- `void vline(chtype ch, int n)` - draw a vertical line of `n` characters at
  the current cursor position.
- `void overlay(Window target)` - overlay this window on top of another. Blanks
  are not copied.
- `void overwrite(Window target)` - overlay this window on top of another.
  Blanks are copied.

These are for retrieving information from the window.
- `int getch()` - get a single keystroke.
- `int curX()` - get the X coordinate of the cursor.
- `int curY()` - get the Y coordinate of the cursor.
- `int width()` - get the width of the window.
- `int height()` - get the height of the window.
- `string getstr(int maxLength, bool echoChars = true)` - get a string of 
  characters at most `maxLength` long. May or may not echo the characters
  being typed.
- `string getstr(bool echoChars = true)` - get a string of characters. May or
  may not echo the characters being typed. 
- `string getstr(bool delegate(int) predicate, bool echoChars = true)` - get a
  string of characters, blocking all keys such that the given predicate returns
  false on them. May or may not echo the characters being typed. 
- `chtype[] inchstr()` - get an array of characters and attributes from the 
  cursor to the right margin of the window.
- `chtype[] inchstr(int n)` - same, but limit the maximum amount of the 
  characters read.
- `chtype[] inchstr(int y, int x)` - same, but move the cursor to the given
  position first.
- `chtype[] inchstr(int y, int x, int n)` - same, but with limit on the length
  of the resulting array and with moving the cursor.

## class ColorTable
A ColorTable object stores information about defined colors and color pairs.
It can be indexed in two ways: 
- By a pair of `short`s: the first is foreground color index, the second is
  background.
- By a single `short`: it is a color pair index.
Indexing yields an attribute that can be used as a parameter to `addch`,
`addstr` and the like. It may throw an exception if a requested pair is not in
the table.

Apart of this, a ColorTable object has following methods:
- `short addPair(short fg, short bg)` - define a new color pair and return its
  index. Throws an exception if a new pair cannot be added.
- `void redefineColor(short color, short r, short g, short b)` - redefine a 
  color with given index. Throws an exception if the color cannot be redefined.
- `short addColor(short r, short g, short b)` - add a new color with given RGB
  content. Return the index of the new color. Throws an exception if a new
  color cannot be added.
- `short addColor(RGB color)` - same.
- `void removePair(short pairIndex)` - mark a pair for overwriting.
- `void removeColor(short colorIndex)` - mark a color for overwriting.
- `void initDefaultColors()` - initialize color pairs from StdColor enum. This
  is called if you request standard colors in Curses configuration.

## Helper things

### struct RGB
Used to represent colors. Has three fields:
- `short r` - the red component.
- `short g` - the green component.
- `short b` - the blue component.

### enum Attr
A set of possible (and binary OR-able) attributes for drawing characters. 
Following attributes are available:
- `normal`
- `charText`
- `color`
- `standout`
- `underline`
- `reverse`
- `blink`
- `dim`
- `bold`
- `altCharSet`
- `invis`
- `protect   `
- `horizontal`
- `left`
- `low`
- `right`
- `top`
- `vertical`

### enum StdColor
A set of default colors:
- `black`
- `red`
- `green`
- `yellow`
- `blue`
- `magenta`
- `cyan`
- `white`

### enum Key
A set of constants that `getch` may return. For the full set, see the table in
`man 3 getch`. As a general rule, you can get a Key.something from
corresponding KEY\_SOMETHING by dropping KEY\_ part and changing the rest to
lower case. The only exception is KEY\_BREAK, with corresponding Key.codeBreak,
to avoid using a keyword as an identifier.

### enum Align
- `left`
- `center`
- `right`

# Usage as a UI library
When using 'nice-curses' as a UI library, you still need to initialize it as
was shown before. In addition, you need to create an UI object. The constructor
takes a Curses object, a Window object, and an optional UI.Config struct:
    UI.Config cfg = { /* Some configuration. */ };
    auto ui = new UI(curses, curses.stdscr, cfg);
After that, you can construct some UI elements. All of the currently available
UI element classes take UI object as the first argument in their constructors
and there's no need to explicitly add them to the UI object via `addElement`
method.

Assuming you use the usual processing loop approach, you need then to read 
keyboard input with `getch` and feed it to the UI via its 
`void keystroke(int key)` method. Note that this method may raise an exception
to deliver UI elements' reaction to the key to the main loop. Those exceptions
all inhering from UISignal class, and have `sender` field which contains the
element that reacted to the keypress.

Below will be given the list of currently available pre-made UIElement classes.

## class UI
An UI object has following publicly available methods:
- `void keystroke(int key)` - process a keystroke from the user. This can
  change currently focused element and raise an exception inheriting from
UISignal class.
- `void draw(bool erase = true)` - draw the UI, optionally erasing the window
  first.
- `void drawElement(UIElement elem, bool active)` - draw a single element,
  which may or may not be focused.
- `void move(Window to)` - move the entire UI to the different window.
- `void addElement(UIElement e)` - add an element to the UI. Note that it's
  unnecessary to call this for standard UI elements as they do that already in
their constructors.
- `void changeFocus(int by)` - change currently focused element.
- `void changeFocus(UIElement newFocused)` - ditto.

### struct UI.Config
This struct controls how the UI reacts to certain keys. It has two fields,
`int[] nextElemKeys` and `int[] prevElemKeys`. When a key that is in
`nextElemKeys` is sent to the UI via `keystroke`, the focus will change to the
next focusable visible element. Likewise, if a key that is in `prevElemKeys` is
sent, previous focusable visible element will be selected.

## class Menu(T)
A class for scrollable menu with multiple entries. The class is parametric on
the values that can serve as its entries. When a menu is active, its header is
drawn in reverse mode.

Two constructors are available:
    this(UI ui, int nlines, int ncols, int y, int x, 
        string delegate() header, Config cfg = Config());
    this(UI ui, int nlines, int ncols, int y, int x, string header, 
        Config cfg = Config());
The first one creates a menu with a dynamic header, the second one - with a 
static one.

Menus throw a Menu!T.Signal when a key that is in `enter` field of menu's
configuration is pressed.

Available methods:
- `T chosenValue()` - return currenly chosen value. 
- `void addEntry(T value, string delegate() text)` - add an entry with dynamic
  text to the menu.
- `void addEntry(T value, string text)` - add an entry with static text to the
  menu.

### struct Menu!T.Config
Has following fields:
- `int[] down = ['j', Key.down]` - when a key from these is pressed, next entry
  in the menu is chosen.
- `int[] up = ['k', Key.up]` - likewise, but the previous entry is chosen.
- `int[] enter = ['\n', '\r', Key.enter]` - when a key from these is pressed,
  signal the chosen value to the processing loop.
- `Align alignment = Align.center` - controls whether the menu is
  left-justified, centered or right-justified.

### class Menu!T.Signal
Has `sender` field inherited from UISignal and `T value` field which contains
the chosen value from the menu.

## class Button
A class for pressable buttons. When a button is active, it's drawn in reverse
mode.

Two constructors are available:
    this(UI ui, int nlines, int ncols, int y, int x, 
        string delegate() text, Config cfg = Config());
    this(UI ui, int nlines, int ncols, int y, int x,
        string text, Config cfg = Config());
The first one creates a button with dynamic text, the second one - with static.

Buttons thrown a Button.Signal when a key that is in `enter` field of button's
configuration is pressed.

### struct Button.Config
Has following fields:
- `int[] enter = ['\n', '\r', Key.enter]` - when a key from these is pressed,
  signal it to the processing loop.
- `Align alignment = Align.left` - controls the way button's text is aligned.

### class Button.Signal
Has a single field `sender` inherited from UISignal.
        
## class Label
A class for text containers. Labels are not selectable and can't signal
anything to the processing loop.

Two constructors are available:
    this(UI ui, int nlines, int ncols, int y, int x,
        string delegate() text, Config cfg = Config());
    this(UI ui, int nlines, int ncols, int y, int x,
        string text, Config cfg = Config());
The first one creates a label with dynamic text, the second one - with static.

### struct Label.Config
Has following fields:
- `int attribute = Attr.normal` - attribute to use when drawing the text.
- `Align alignment = Align.left` - controls how the text is aligned.

## class ProgressBar
A class for progress bars. They are not selectable and can't signal anything to
the processing loop.

Single constructor is available:
    this(UI ui, int nlines, int ncols, int y, int x, Config cfg = Config());

The percentage of filledness of a progress bar can be queried and set via
`percentage` property (a double from [0, 1] range).

### struct ProgressBar.Config
Has following fields:
- `char empty = '-'` - a character to use for drawing empty areas of the
  progress bar.
- `char filled = '#'` - a character to use for drawing filled areas of the
  progress bar.
- `int emptyAttr = Attr.normal` - attribute to use for drawing empty areas.
- `int filledAttr = Attr.normal` -  attribute to use for drawing filled areas.
- `bool vertical = false` - when set, the bar will be filled in vertical
  direction, rather than in horizontal.
- `bool reverse = false` - when set, the bar will be filled from the right to
  the left for horizontal bars, and from the top to bottom for vertical ones.

## class TextInput
A class for text inputs. To start typing, a key in `start` field of input's
configuration has to be pressed. When the user is done typing, the input will
signal received text to the processing loop.

A single constructor is available:
    this(UI ui, int nlines, int ncols, int y, int x, string initialText,
        Config cfg = Config());

### struct TextInput.Config
Has following fields:
- `int[] start = ['\n', '\r', 'i', Key.enter]` - when a key from these is
  pressed, start receiving text from the user.
- `string emptyText = "<empty>"` - text to display when the user typed in
  nothing.

### class TextInput.Signal
Has `sender` field inherited from UISignal and `string text` field which 
contains received from the user text.

## class CheckBox
A class for checkboxes. To change its status, press any key listed in
`switchKeys` field of checkbox's configuration. When its status changes,
signals new status to the processing loop. Current status is also available via
`checked` field.

Two constructors are available:
    this(Ui ui, int nlines, int ncols, int y, int x,
        string delegate() text, Config cfg = Config());
    this(UI ui, int nlines, int ncols, int y, int x, string text,
        Config cfg = Config());
The first one creates a checkbox with dynamic text, the second one with static.

### struct CheckBox.Config
Has following fields:
- `char whenChecked = '+'` - this will appear near text if the checkbox is
  checked.
- `char whenUnchecked = '-'` - this will appear near text if the checkbox is 
  unchecked.
- `int switchKeys = ['\n', '\r', Key.enter]` - keys that, when pressed, will
  cause the checkbox to change its status.
- `Align alignment = Align.left` - alignment of the text on the checkbox.

### class CheckBox.Signal
Has `sender` field inherited from UISignal and `bool checked` field which 
indicates whether the checkbox is checked.
    
## class NumberBox
A class for numerical input. You can change current value in two ways: press a
key in any of `smallIncr`, `bigIncr`, `smallDecr` and `bigDecr` fields of 
number box's configuration to (respectively) increase it by `smallStep`, 
increase it by `bigStep`, decrease it by `smallStep`, decrease it by `bigStep`;
or press any key in `start` field of number box's configuration to begin typing
the number directly. In both cases, old value, new value and delta are signaled
to the processing loop.

A single constructor is available:
    this(UI ui, int nlines, int ncols, int y, int x, int startingValue,
        Config cfg = Config());

### struct NumberBox.Config
Has following fields:
- `int[] start = ['\n', '\r', 'i', Key.enter]` - when any of these keys is 
  pressed, text input mode is activated.
- `int[] smallIncr = ['k', 'l', Key.up, Key.right]` - when any of these keys is
  pressed, value increases by `smallStep`.
- `int[] bigIncr = ['K', 'L", Key.sright]` - likewise, but increase the value
  by `bigStep`.
- `int[] smallDecr = ['j', 'h', Key.down, Key.left]` - likewise, but decrease
  the value by `smallStep`.
- `int[] bigDecr = ['J', 'H', Key.sleft]` - likewise, but decrease it by 
  `bigStep`.
- `int min = int.min` - the lower bound on the number box's value.
- `int max = int.max` - the upper bound on the number box's value.
- `int smallStep = 1`
- `int bigStep = 5`
- `Align alignment = Align.center` - alignment of the text on the number box.

### class NumberBox.Signal
Has `sender` field inherited from UISignal and also following fields:
- `int value` - contains current value of the number box.
- `int delta` - contains the change in the value.
- `int old` - contains previous value of the number box.
