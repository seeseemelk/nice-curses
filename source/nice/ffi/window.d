module nice.ffi.window;

import nice.ffi.types;

/* ---------- construction ---------- */

extern (C) @nogc nothrow
{
    _window *derwin(_window *, int, int, int, int);
    _window *dupwin(_window *);
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
}

/* ---------- drawing ---------- */

extern (C) @nogc nothrow
{
    /* ---------- highest-level interactions ---------- */
    int copywin(const _window *, _window *, int, int, int, int, int, int, int, int);

    /* ---------- boxes, lines and similar ---------- */
    int box(_window *, chtype, chtype);
    int mvwhline(_window *, int, int, chtype, int);
    int mvwhline_set(_window *, int, int, const _cchar_t *, int);
    int mvwvline(_window *, int, int, chtype, int);
    int mvwvline_set(_window *, int, int, const _cchar_t *, int);

    /* ---------- string drawing ---------- */
    int mvwaddchnstr(_window *, int, int, const chtype *, int);
    int mvwaddnstr(_window *, int, int, const char *, int);
    int mvwadd_wchnstr(_window *, int, int, const _cchar_t *, int);
    int mvwaddnwstr(_window *, int, int, const wchar_t *, int);
    int mvwinsnstr(_window *, int, int, const char *, int);
    int mvwins_nwstr(_window *, int, int, const wchar_t *, int);

    /* ---------- single-character drawing ---------- */
    int mvwaddch(_window *, int, int, const chtype);
    int mvwadd_wch(_window *, int, int, const _cchar_t *);
    int mvwinsch(_window *, int, int, chtype);
    int mvwins_wch(_window *, int, int, const _cchar_t *);

    /* ---------- attribute manipulation ---------- */
    int mvwchgat(_window *, int, int, int, attr_t, short, const void *);

    /* ---------- miscellaneous ---------- */
    int mvwdelch(_window *, int, int);
}

/* ---------- queries ---------- */

extern (C) @nogc nothrow
{
    chtype getbkgd(_window *);
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
}
