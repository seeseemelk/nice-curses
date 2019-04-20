module nice.ffi.term;

import nice.ffi.types;

/* ---------- queries ---------- */

extern (C) @nogc nothrow
{
    int baudrate();
    char erasechar();
    int erasewchar(wchar_t *);
    bool has_ic();
    bool has_il();
    bool is_term_resized(int, int);
    const(char) *keyname(int);
    const(char) *key_name(wchar_t);
    char killchar();
    int killwchar(wchar_t *);
    char *longname();
    chtype termattrs();
    attr_t term_attrs();
    char *termname();
    // I'm intensely curious why this doesn't return a const pointer in the
    // original header. Being able to change this seems odd.
    wchar_t *wunctrl(_cchar_t *);

    /* ---------- kinda limited portability ---------- */
    bool has_mouse();

    /* ---------- extensions ---------- */
    int get_escdelay();
    int has_key(int);
    char *keybound(int, int);
    int key_defined(const char *);

}

/* ---------- configuration ---------- */

extern (C) @nogc nothrow
{
    int cbreak();
    int curs_set(int);
    int echo();
    int halfdelay(int);
    int nl();
    int nocbreak();
    int noecho();
    int nonl();
    void noqiflush();
    int noraw();
    void qiflush();
    int raw();
    int typeahead(int);

    /* ---------- extensions ---------- */
    int define_key(const char *, int);
    int keyok(int, bool);
    int set_escdelay(int);
    int set_tabsize(int);
    int use_legacy_coding(int);

}

/* ---------- non-configuration manipulation ---------- */

extern (C) @nogc nothrow
{
    int beep();
    int def_prog_mode();
    int def_shell_mode();
    int delay_output(int);
    int flash();
    int flushinp();
    int mvcur(int, int, int, int);
    int napms(int);
    int resetty();
    int reset_prog_mode();
    int reset_shell_mode();
    int savetty();
    int ungetch(int);
    int unget_wch(const wchar_t);
    int use_screen(_screen *, _screen_cb, void *);

    /* ---------- limited portability ---------- */
    int resizeterm(int, int);
    int resize_term(int, int);

}
