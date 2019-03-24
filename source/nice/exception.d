module nice.exception;

import std.format;

/* An exception that is thrown on ncurses errors. */
class NCException: Exception 
{
    this(Arg...)(string formatString, Arg args)
    {
        super(format(formatString, args));
    }
}

class UseAfterFreeException: Exception
{
    this(Arg...)(string formatString, Arg args)
    {
        super(format(formatString, args));
    }
}
