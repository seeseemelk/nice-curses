void main()
{
    import std.format;

    import nice.ui.elements;

    Curses.Config cfg = {
        disableEcho: true,
        cursLevel: 0
    };
    auto curses = new Curses(cfg);
    scope(exit) destroy(curses);
    auto scr = curses.stdscr;

    /* We're using default configuration for the UI. In default config next
       element is selected by pressing tab, page down or down arrow button,
       and the previous - by pressing backspace, page up or up arrow button.
       */
    auto ui = new UI(curses, scr); 

    auto menu = new Menu!Fruit(ui, 20, 20, 10, scr.width / 2 - 10,
            "Pick a fruit" /* We're using static text */
            ); /* and default config. With it arrows and Vim keys are accepted
                  for movement. */
    /* We're using static text for these three. Could use an arbitrary 
       delegate if we wanted to. */
    menu.addEntry(Fruit.apple, "Apple");
    menu.addEntry(Fruit.orange, "Orange");
    menu.addEntry(Fruit.pear, "Pear");
    
    /* A button. */
    Button.Config buttonCfg = {
        alignment: Align.left,
    };
    auto borderButton = new Button(ui, 1, 20, 1, 1, "Draw a border", buttonCfg);

    /* A text input. */
    auto textInput = new TextInput(ui, 1, 30, 2, 1, "Press Enter or 'i' to input text");

    /* Main processing loop. */
    while (true) {
        ui.draw();
        int k = scr.getch();

        try {
            ui.keystroke(k);
        } catch (Menu!Fruit.Signal s) {
            auto fruit = s.value; /* Chosen value is stored in '.value' */
            string msg = format!"Your fruit is %s. Press any key to continue."(fruit);
            scr.addAligned(scr.height / 2, scr.width / 2, msg, Align.center);
            scr.refresh;
            curses.update;
            scr.getch;
        } catch (Button.Signal s) {
            /* The element that sent a signal is available via '.sender' field. */
            if (s.sender == borderButton) {
                scr.box('|', '-');
                scr.refresh;
                curses.update;
                scr.getch;
            }
        } catch (TextInput.Signal s) {
            /* The typed text is available via '.text' field. */
            scr.addAligned(scr.height / 2, scr.width / 2, s.text, Align.center);
            scr.refresh;
            curses.update;
            scr.getch;
        }
    }
}

enum Fruit
{
    apple,
    orange,
    pear
}
