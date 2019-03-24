module nice.util;

import std.uni;

import deimos.ncurses;

package alias nc = deimos.ncurses;

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
            this(cast(wint_t)key, true);
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

/* Out-of-bounds condition handling. */
enum OOB
{
    ignore,
    except
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

enum Key: int
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

package:

/* Prepare a wide character for drawing. */
cchar_t
prepChar(C: wint_t, A: chtype)(C ch, A attr)
{
    import core.stdc.stddef: wchar_t;

    cchar_t res;
    wchar_t[] str = [ch, 0];
    setcchar(&res, str.ptr, attr, PAIR_NUMBER(attr), null);
    return res;
}

cchar_t
prepChar(C: wint_t, A: chtype)(const C[] chars, A attr)
{
    import core.stdc.stddef: wchar_t;
    import std.array;
    import std.range;

    cchar_t res;
    version(Win32) {
        import std.conv: wtext;
        const wchar_t[] str = (chars.take(CCHARW_MAX).wtext) ~ 0;
    } else {
        const wchar_t[] str = (chars.take(CCHARW_MAX).array) ~ 0;
    }
    /* Hmm, 'const' modifiers apparently were lost during porting the library
       from C to D.
       */
    setcchar(&res, cast(wchar_t*) str.ptr, attr, PAIR_NUMBER(attr), null);
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

    version(Win32) {
        import std.conv: wtext;
        return CChar(g[].wtext, attr);
    } else {
        return CChar(g[].array, attr);
    }
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
