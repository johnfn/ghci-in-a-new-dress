
# Dependencies

* Yesod

* Hoogle (/Users/abi/Library/Haskell/ghc-7.0.3/lib/hoogle-4.2.8/bin) — The Hoogle executable ought to be in the path but not just in .bashrc but also, symlinked in /usr/bin/. Probably because createProcess runs sh, rather than bash? Or createProcess only looks in /usr/bin.

## Running
build with:

    cabal configure
    cabal build

run with:

    ./dist/build/ghci-in-a-new-dress/ghci-in-a-new-dress

or:

    cabal install
    ghci-in-a-new-dress

then open a browser and go to http://127.0.0.1:3000/

## Features

* Types of larger expressions. **DONE**
* Autocomplete - **DONE**
* Calltips - **DONE**
* Syntax highlight - **DONE**
* (Potentially) advanced syntax highlighting (type colors) **DONE**
* Type annotations **DONE**
* Data types via file import **DONE**
* Hlint suggestions **DONE**
* Variable inspector on the side that shows all active bindings **DONE**
* Show all active modules on the side too
* Integrate the debugging information
* Search by result value
* Remove let ... in syntax
* Strictness of functions
* Hoogle integration **DONE**
* Docs
* Red squiggly error lines, and defer all the work to Haskell.
* Call stack lol
* Filter out empty string

## UI

* Select first item of autocomplete
* Autocomplete icons

## BUGZ

* Data doesn't work 100%.
* syntax highlighting does not go all the way back

## TODO

* Multiline inputs
* Error when you hit enter on an empty string.
* Scroll to the bottom automatically.
