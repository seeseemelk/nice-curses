void main()
{
    import nice.ui.elements;

    auto curses = new Curses();
    scope(exit) destroy(curses);
    auto scr = curses.stdscr;
    auto ui = new UI(curses, scr);

    /* Several checkboxes. */
    CheckBox.Config cb1cfg = { alignment: Align.left, };
    auto cb1 = new CheckBox(ui, 2, 14, 0, 0, "box #1", cb1cfg);
    CheckBox.Config cb2cfg = { alignment: Align.center, };
    auto cb2 = new CheckBox(ui, 2, 14, 0, 20, "box #2", cb2cfg);
    CheckBox.Config cb3cfg = { alignment: Align.right, };
    auto cb3 = new CheckBox(ui, 2, 14, 0, 40, "box #3", cb3cfg);

    /* A number box. */
    auto nb = new NumberBox(ui, 1, 20, 4, 0, 0);

    while (true) {
        ui.draw(true);
        WChar key = scr.getwch();
        try {
            ui.keystroke(key);
        } catch (CheckBox.Signal s) {
            {}
        } catch (NumberBox.Signal s) {
            {}
        }
    }
}
