module nice.ffi.types;

// The kicker is that, at the time of writing, this module is not even
// documented! Heck, you can't even see it at the Phobos' page's sidebar.
import core.stdc.config: c_ulong;
public import core.stdc.wchar_: wint_t;

/* ---------- ncurses data types ---------- */

extern (C) @nogc nothrow 
{
    alias chtype = c_ulong;
    alias mmask_t = c_ulong;
    alias attr_t = chtype;

    package:

    // All structs should be opaque, and be only produced by calling C functions.
    struct _screen;
    struct _window;
    struct _cchar_t;
    struct _mevent;

    alias _outc = int function(int);
    alias _sp_outc = int function(_screen *, int);
    alias _window_cb = int function(_window *, void *);
    alias _screen_cb = int function(_screen *, void *);
}
