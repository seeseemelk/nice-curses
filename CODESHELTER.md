# Note to Code Shelter maintainers

I don't really have the motivation to continue maintaining this. You can see my
rant in issue #7. Since then I've cooled off enough to see that not all of it
is justified (and part of it is just me being stupid), but not enough to
immediately get back to working on this project.

I'd greatly appreciate if someone would take over the library. Just leaving it
to rot feels wrong, seeing that a number of people for some unfathomable reason
does find it useful. I will try to help with things as well as time allows, and
maybe will send a pull request your way once in a while.

I've added the Code Shelter app to the repo, but haven't yet done anything
about the package ownership on the [registry](http://code.dlang.org/), since
the details of the sheltering process for D packages aren't yet worked out, so
there's no one to transfer the ownership to at the moment.  This does not
prevent releasing a new version of the package, since all that it takes is
pushing a version tag. The rest of package administration _is_ tied to the
ownership, unfortunately. This is discussed
[here](https://gitlab.com/codeshelter/codeshelter-web/issues/30), until that is
done just ping me if you need anything.

Honestly, just keeping the thing maintained would be awesome. I've also
outlined some things _probably_ worth considering, as well as unfinished work,
below.

## Adding tests

The library would benefit from having proper tests. Unfortunately, the
underlying `ncurses` library is not very testing-friendly, since it's highly
stateful, so just making individual tests coexist is sometimes tricky, and
debugging can become a pretty frustrating exercise.

## Deprecating the UI module

It's essentially useless. I'm really not sure if it's worth keeping.

## Unfinished work - multiple terminal support

The version that is currently on `master` (commit
f9c3fe3c3b3437bfc2dc27ff9c6cca8b4de3d30a, closest tag `v0.2.5`) does not have
any support whatsoever for `SCREEN` functions.

`use-screens` branch has some commits to add it, also see #7 for extra notes on
the matter. The whole thing is horrifically thread-unsafe due to a significant
number of `ncurses` functions using a global `SCREEN` variable. Saner versions
of these functions exist (see `man 3 curs_sp_funcs`), at least in newer
versions of `ncurses`. However, a note in the manpage says that the proper way
to refer to them is via a macro which constructs the actual name of the
function in question, and relying on the name staying the same across different
`ncurses` configurations is a bad idea. It's probably fine, but still is a
gamble.

## Unfinished work - resource handling and how it snowballed into more changes

The current resource handling scheme in `master` (and `use-screens`) is not
very good. It is essentially manual (which is alleviated to some extent thanks
to `scope(exit)` guard). Moreover, finalization is baked into the destructors
of relevant classes - which made sense naively, but not really since garbage
collection is not deterministic, so you need to put the guards anyway, and do
the questionable `destroy(library)` in them.

The basic plan was to go RAII with reference-counted structs, preferably
with atomic counters to help with multithreading. There'd still be a problem
with people sticking these into garbage-collected containers, thus making
finalization non-deterministic again, but it looked like an interesting plan.
However, I got waay sidetracked.

`nodepend` branch contains an attempt to drop the dependency on `ncurses`
bindings, and bind to `ncurses` directly from `nice-curses`. Yeah, an obvious
transition from "go RAII". Using structs for everything would allow the code to
be `@nogc`-compatible. However, the upstream package is not itself
`@nogc`-compatible, so I made a pull request to fix that and in parallel tried
to avoid using the upstream package at all. There are a few checklists with the
progress so far (explanation of what `+` and `-` marks mean is in
`checklist/windows`). 
