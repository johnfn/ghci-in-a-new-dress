
# Dependencies

* Yesod

* Hoogle (/Users/abi/Library/Haskell/ghc-7.0.3/lib/hoogle-4.2.8/bin) — The Hoogle executable ought to be in the path but not just in .bashrc but also, symlinked in /usr/bin/. Probably because createProcess runs sh, rather than bash? Or createProcess only looks in /usr/bin.

This should be a .cabal file.

# Running

## Features

* Autocomplete - **DONE**
* Calltips - **DONE**
* Syntax highlight - **DONE**
* (Potentially) advanced syntax highlighting (type colors) **DONE**
* Type annotations **DONE**
* Data types via file import **DONE**
* Remove let ... in syntax
* Strictness of functions
* Hlint suggestions
* Variable inspection **DONE**
* Integrate the debugging information
* Search by result value
* Hoogle integration

* Call stack lol

## TODO

* Multiline inputs
* Error when you hit enter on an empty string.
* Sometimes Prelude> appears, sometimes it doesn't.
