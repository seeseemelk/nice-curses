module nice.color_table;

import std.uni;

import nc = deimos.ncurses;

import nice.screen: Screen;
import nice.util;

alias chtype = nc.chtype;

final class ColorTable
{
    private:
        struct Pair { short fg; short bg; }

        Pair[short] pairs; /* A mapping from pair indices to pairs. */
        short[] reusablePairs;
        short latestPair = 1;

        short latestColor;
        short[] reusableColors;

        Screen screen;

    package:

        this(Screen scr, bool useStdColors)
        {
            screen = scr;
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
            screen.setTerm();
            scope(exit) screen.unsetTermPkg();

            const auto pair = Pair(fg, bg);
            foreach (index, p; pairs)
                if (p == pair) return nc.COLOR_PAIR(index);
            throw new NCException("Combination of colors %s:%s is not in the color table");
        }

        /* Alternatively, you can use a pair index to get an attribute. */
        chtype opIndex(short pairIndex)
        {
            screen.setTerm();
            scope(exit) screen.unsetTermPkg();

            if (pairIndex in pairs)
                return nc.COLOR_PAIR(pairIndex);
            else
                throw new NCException("Color pair #%s is not in the color table", pairIndex);
        }

        /* Return the index of a newly created pair. */
        short addPair(short fg, short bg)
        {
            screen.setTerm();
            scope(exit) screen.unsetTermPkg();

            const bool addNew = reusablePairs == [];
            short pair;
            if (addNew) 
                pair = latestPair;
            else
                pair = reusablePairs[0];
            if (nc.init_pair(pair, fg, bg) != nc.OK)
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
            screen.setTerm();
            scope(exit) screen.unsetTermPkg();

            if (color >= screen.maxColors)
                throw new NCException("A color with index %s requested, but the " ~
                        "terminal supports only %s colors", color, screen.maxColors);
            if (nc.init_color(color, r, g, b) != nc.OK)
                throw new NCException("Failed to initialize a color #%s with RGB content " ~
                        "%s:%s:%s", color, r, g, b);
        }

        /* Return the index of a newly defined color. */
        short addColor(short r, short g, short b)
        {
            screen.setTerm();
            scope(exit) screen.unsetTermPkg();

            if (!screen.canChangeColor)
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
