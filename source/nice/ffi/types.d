module nice.ffi.types;

// The kicker is that, at the time of writing, this module is not even
// documented! Heck, you can't even see it at the Phobos' page's sidebar.
import core.stdc.config: c_ulong;
public import core.stdc.stddef: wchar_t;
public import core.stdc.wchar_: wint_t;

/* ---------- ncurses data types ---------- */

const int CCHARW_MAX = 5;

extern (C) @nogc nothrow 
{
    alias chtype = c_ulong;
    alias mmask_t = c_ulong;
    alias attr_t = chtype;

    // I don't really know if these can be anything else, but they are defined
    // as macros in the header, so an alias seems reasonable in case they need
    // to be changed afterwards for some system.
    alias color_t = short;
    alias pairs_t = short;

    // If it can be opaque, it should.
    struct _screen;
    struct _window;
    struct _mevent;

    // This one, unfortunately, cannot be opaque - it's expected to be
    // initialized via a `setcchar` call, and there's no other way to get one
    // but to `malloc` or allocate it on stack. So we do need to know its size.
    struct _cchar_t {
        attr_t attr;
        wchar_t[CCHARW_MAX] chars;
        int ext_color;
    }

    alias _outc = int function(int);
    alias _sp_outc = int function(_screen *, int);
    alias _window_cb = int function(_window *, void *);
    alias _screen_cb = int function(_screen *, void *);
}
