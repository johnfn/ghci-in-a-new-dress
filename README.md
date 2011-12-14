
# Running

## Features

* Autocomplete - *DONE*
* Calltips - *DONE*
* Syntax highlight - *DONE*
* (Potentially) advanced syntax highlighting (type colors)
* Data types via file import
* Remove let ... in syntax
* Strictness of functions
* Hlint suggestions
* Variable inspection
* Integrate the debugging information
* Search by result value

* Call stack lol

## Components

* UI for the REPL (written in HTML)
* Open websocket to server
* Webserver (Haskell/Yesod)
* GHC API or GHCI (run as a process). Better use the API. http://www.haskell.org/ghc/docs/latest/html/libraries/ghc/index.html https://github.com/ghc/ghc/blob/master/ghc/InteractiveUI.hs

## TODO

* Kind of worried about how it seems like giand is crashing my computer. Should look into this...
* Multiline inputs
