module nice.ffi.misc;

import nice.ffi.types;

/* ---------- various routines that don't fit anywhere else ---------- */

extern (C) @nogc nothrow
{
    const(char) *curses_version();
    int setcchar(_cchar_t *, const wchar_t *, const attr_t, pairs_t, const void *);

}
