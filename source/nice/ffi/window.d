module nice.ffi.window;

import nice.ffi.types;

/* ---------- construction ---------- */

extern (C) @nogc nothrow
{
    /* ---------- normal windows ---------- */
    _window *derwin(_window *, int, int, int, int);
    _window *dupwin(_window *);
    _window *newwin(int, int, int, int);
    _window *subwin(_window *, int, int, int, int);

    /* ---------- pads ---------- */
    _window *newpad(int, int);
    _window *subpad(_window *, int, int, int, int);

}

/* ---------- pure movement ---------- */

extern (C) @nogc nothrow
{
    int mvderwin(_window *, int, int);
    int mvwin(_window *, int, int);
}

/* ---------- high-level manipulations ---------- */

extern (C) @nogc nothrow
{
    int clearok(_window *, bool);
    int redrawwin(_window *);
    int wclear(_window *);
    int wclrtobot(_window *);
    int wclrtoeol(_window *);
    int werase(_window *);
    int wredrawln(_window *, int, int);
    int wrefresh(_window *);
    int wscrl(_window *, int);
}

/* ---------- drawing ---------- */

extern (C) @nogc nothrow
{
    /* ---------- highest-level interactions ---------- */
    int copywin(const _window *, _window *, int, int, int, int, int, int, int, int);
    int overlay(const _window *, _window *);
    int overwrite(const _window *, _window *);

    /* ---------- boxes, lines and similar ---------- */
    int box(_window *, chtype, chtype);
    int box_set(_window *, const _cchar_t *, const _cchar_t *);
    int mvwhline(_window *, int, int, chtype, int);
    int mvwhline_set(_window *, int, int, const _cchar_t *, int);
    int mvwvline(_window *, int, int, chtype, int);
    int mvwvline_set(_window *, int, int, const _cchar_t *, int);
    int wborder(_window *, chtype, chtype, chtype, chtype, chtype, chtype, chtype, chtype);
    int wborder_set(_window *, 
            const _cchar_t *, const _cchar_t *,
            const _cchar_t *, const _cchar_t *,
            const _cchar_t *, const _cchar_t *,
            const _cchar_t *, const _cchar_t *);
    int whline(_window *, chtype, int);
    int whline_set(_window *, const _cchar_t *, int);
    int wvline(_window *, chtype, int);
    int wvline_set(_window *, const _cchar_t *, int);

    /* ---------- string drawing - with movement ---------- */
    int mvwaddchnstr(_window *, int, int, const chtype *, int);
    int mvwaddnstr(_window *, int, int, const char *, int);
    int mvwadd_wchnstr(_window *, int, int, const _cchar_t *, int);
    int mvwaddnwstr(_window *, int, int, const wchar_t *, int);
    int mvwinsnstr(_window *, int, int, const char *, int);
    int mvwins_nwstr(_window *, int, int, const wchar_t *, int);

    /* ---------- string drawing - without movement ---------- */
    int waddch(_window *, const chtype);
    int waddchnstr(_window *, const chtype *, int);
    int waddnstr(_window *, const char *, int);
    int winsnstr(_window *, const char *, int);
    int wins_nwstr(_window *, const wchar_t *, int);

    /* ---------- single-character drawing - with movement ---------- */
    int mvwaddch(_window *, int, int, const chtype);
    int mvwadd_wch(_window *, int, int, const _cchar_t *);
    int mvwinsch(_window *, int, int, chtype);
    int mvwins_wch(_window *, int, int, const _cchar_t *);

    /* ---------- single-character drawing - without movement ---------- */
    int wadd_wch(_window *, const _cchar_t *);
    int wechochar(_window *, const chtype);
    int wecho_wchar(_window *, const _cchar_t *);
    int winsch(_window *, chtype);
    int wins_wch(_window *, const _cchar_t *);

    /* ---------- attribute manipulation ---------- */
    int mvwchgat(_window *, int, int, int, attr_t, short, const void *);
    int wchgat(_window *, int, attr_t, short, const void *);

    /* ---------- line manipulation ---------- */
    int wdeleteln(_window *);
    int winsdelln(_window *, int);
    int winsertln(_window *);

    /* ---------- miscellaneous ---------- */
    int mvwdelch(_window *, int, int);
    int wdelch(_window *);

    /* ---------- functions for pads ---------- */
    int pechochar(_window *, const chtype);
    int pecho_wchar(_window *, const _cchar_t *);
    int pnoutrefresh(_window *, int, int, int, int, int, int);
    int prefresh(_window *, int, int, int, int, int, int);

}

/* ---------- queries ---------- */

extern (C) @nogc nothrow
{
    /* ---------- global properties ---------- */
    chtype getbkgd(_window *);
    int getattrs(const _window *);
    int getcurx(const _window *);
    int getcury(const _window *);
    int getbegx(const _window *);
    int getbegy(const _window *);
    int getmaxx(const _window *);
    int getmaxy(const _window *);
    int getparx(const _window *);
    int getpary(const _window *);
    _window *wgetparent(const _window *);
    int wgetdelay(const _window *);
    int wgetscrreg(const _window *, int *, int *);
    int wget_wch(_window *, wint_t *);
    int wgetbkgrnd(_window *, _cchar_t *);
    int wgetn_wstr(_window *, wint_t *, int);

    /* ---------- chars and strings - with movement ---------- */
    int mvwgetch(_window *, int, int);
    int mvwgetnstr(_window *, int, int, char *, int);
    int mvwgetn_wstr(_window *, int, int, wint_t *, int);
    int mvwget_wch(_window *, int, int, wint_t *);
    chtype mvwinch(_window *, int, int);
    int mvwinchnstr(_window *, int, int, chtype *, int);
    int mvwinnstr(_window *, int, int, char *, int);
    int mvwinnwstr(_window *, int, int, wchar_t *, int);
    int mvwin_wch(_window *, int, int, _cchar_t *);
    int mvwin_wchnstr(_window *, int, int, _cchar_t *, int);

    /* ---------- chars and strings - without movement ---------- */
    int wattr_get(_window *, attr_t *, short *, void *);
    int wgetch(_window *);
    int wgetnstr(_window *, char *, int);
    chtype winch(_window *);
    int winchnstr(_window *, chtype *, int);
    int winnstr(_window *, char *, int);
    int win_wch(_window *, _cchar_t *);
    int win_wchnstr(_window *, _cchar_t *, int);
    int winnwstr(_window *, wchar_t *, int);

    /* ---------- miscellaneous ---------- */
    bool is_cleared(const _window *);
    bool is_idcok(const _window *);
    bool is_idlok(const _window *);
    bool is_immedok(const _window *);
    bool is_keypad(const _window *);
    bool is_leaveok(const _window *);
    bool is_linetouched(_window *, int);
    bool is_nodelay(const _window *);
    bool is_notimeout(const _window *);
    bool is_pad(const _window *);
    bool is_scrollok(const _window *);
    bool is_subwin(const _window *);
    bool is_syncok(const _window *);
    bool is_wintouched(_window *);

}
