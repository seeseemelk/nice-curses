module nice.ffi.color;

import nice.ffi.types;

/* ---------- color manipulation ---------- */

extern (C) @nogc nothrow
{
    /* ---------- initialization ---------- */
    int init_color(color_t, color_t, color_t, color_t);
    int init_pair(pairs_t, color_t, color_t);
    int start_color();

    /* ---------- queries for capabilities ---------- */
    bool can_change_color();
    bool has_colors();

    /* ---------- queries for colors and pairs ---------- */
    int color_content(color_t, color_t *, color_t *, color_t *);
    int color_pair(int);
    int pair_content(pairs_t, color_t *, color_t *);
    int pair_number(int);

    /* ---------- color-pair extensions ---------- */
    // TODO: compile the code using these conditionally, probably based on the
    // package configuration or some flag.
    int alloc_pair(int, int);
    int extended_color_content(int, int *, int *, int *);
    int extended_pair_content(int, int *, int *);
    int find_pair(int, int);
    int free_pair(int);
    int init_extended_color(int, int, int, int);
    int init_extended_pair(int, int, int);
    void reset_color_pairs();

    /* ---------- default color extensions ---------- */
    // TODO: ditto
    int assume_default_colors(int, int);
    int use_default_colors();

}
