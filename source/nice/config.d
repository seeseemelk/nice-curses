module nice.config;

public struct CursesConfig
{
    bool useColors = true;
    bool useStdColors = true;
    bool disableEcho = false;
    CursesMode mode = CursesMode.normal;
    int cursLevel = 1;
    bool initKeypad = true;
    bool nl = false;
    bool nodelay = false;
}

public enum CursesMode
{
    normal,
    cbreak,
    halfdelay,
    raw,
}
