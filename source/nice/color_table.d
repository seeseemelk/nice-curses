module nice.color_table;

import std.uni;

import deimos.ncurses;

import nice.curses: CursesBase;
import nice.util;

package alias nc = deimos.ncurses;

final class ColorTable
{
    private:
        struct Pair { short fg; short bg; }

        Pair[short] pairs; /* A mapping from pair indices to pairs. */
        short[] reusablePairs;
        short latestPair = 1;

        short latestColor;
        short[] reusableColors;

        CursesBase library;

    package:

        this(CursesBase lib, bool useStdColors)
        {
            library = lib;
            if (useStdColors) {
                latestColor = StdColor.max + 1;
                initDefaultColors;
            } else {
                latestColor = 1;
            }
        }

    public:

        /* Indexing a color table returns an attribute which a color pair 
           represents. */
        chtype opIndex(short fg, short bg)
        {
            const auto pair = Pair(fg, bg);
            foreach (index, p; pairs)
                if (p == pair) return COLOR_PAIR(index);
            throw new NCException("Combination of colors %s:%s is not in the color table");
        }

        /* Alternatively, you can use a pair index to get an attribute. */
        chtype opIndex(short pairIndex)
        {
            if (pairIndex in pairs)
                return COLOR_PAIR(pairIndex);
            else
                throw new NCException("Color pair #%s is not in the color table", pairIndex);
        }

        /* Return the index of a newly created pair. */
        short addPair(short fg, short bg)
        {
            const bool addNew = reusablePairs == [];
            short pair;
            if (addNew) 
                pair = latestPair;
            else
                pair = reusablePairs[0];
            if (init_pair(pair, fg, bg) != OK)
                throw new NCException("Failed to initialize color pair %s:%s", fg, bg);

            const auto p = Pair(fg, bg);
            pairs[pair] = p;
            if (addNew)
                latestPair++;
            else
                reusablePairs = reusablePairs[1 .. $];
            return pair;
        }

        /* Redefine a color. */
        void redefineColor(short color, short r, short g, short b)
        {
            if (color >= library.maxColors)
                throw new NCException("A color with index %s requested, but the " ~
                        "terminal supports only %s colors", color, library.maxColors);
            if (init_color(color, r, g, b) != OK)
                throw new NCException("Failed to initialize a color #%s with RGB content " ~
                        "%s:%s:%s", color, r, g, b);
        }

        /* Return the index of a newly defined color. */
        short addColor(short r, short g, short b)
        {
            if (!library.canChangeColor)
                throw new NCException("The terminal doesn't support changing colors");

            const bool addNew = reusableColors == [];
            short color;
            if (addNew)
                color = latestColor;
            else
                color = reusableColors[0];
            redefineColor(color, r, g, b);
            if (addNew)
                latestColor++;
            else
                reusableColors = reusableColors[1 .. $];
            return color;
        }

        /* Ditto. */
        short addColor(RGB color)
        {
            return addColor(color.r, color.g, color.b);
        }

        /* Mark a pair as available for overwriting. It doesn't actually
           undefine it or anything, there's no way to do that. */
        void removePair(short pairIndex)
        {
            if (pairIndex !in pairs)
                throw new NCException("Attempted to remove color pair #%s, which is " ~
                        "not in the color table to begin with", pairIndex);
            reusablePairs ~= pairIndex;
            pairs.remove(pairIndex);
        }

        /* Mark a color as available for overwriting. */
        void removeColor(short color)
        {
            reusableColors ~= color;
        }

        void initDefaultColors()
        {
            import std.traits: EnumMembers;
            foreach (colorA; EnumMembers!StdColor) 
                foreach (colorB; EnumMembers!StdColor) 
                    addPair(colorA, colorB);
        }
}
