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

    int ripoffline(int, int function(_window *, int) nothrow);

}
