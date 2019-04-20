module nice.ffi.core;

import std.stdio: FILE;

import nice.ffi.types;

/* ---------- core ncurses routines ---------- */

extern (C) @nogc nothrow
{
    _window *initscr();
    _screen *newterm(char *type, FILE *outfd, FILE *infd);

    bool isendwin();
    int endwin();
    void delscreen(_screen *);
    int delwin(_window *);

    _screen *set_term(_screen *);
    int doupdate();

}

/* ---------- library-wide operations ---------- */

extern (C) @nogc nothrow
{
    void filter();
    void nofilter();
    int ripoffline(int, int function(_window *, int) nothrow);
    void use_env(bool);
    void use_tioctl(bool);

    /* ---------- extensions ---------- */
    int use_extended_names(bool);

}
