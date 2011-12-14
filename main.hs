{-# LANGUAGE TypeFamilies, QuasiQuotes, MultiParamTypeClasses,
              TemplateHaskell, OverloadedStrings #-}


import Yesod
import Yesod.Static

import System.Process
import IO
import Data.List
import Control.Monad
import Data.IORef
import System.IO.Unsafe

data HelloWorld = HelloWorld { helloWorldStatic :: Static }

{- This is Bad, Dirty, Evil, Not Good, etc. Fix if time.  The
 - difficulty is that we need a way to share variables between
 - main and the handlers. I can't figure out a better way to do
 - that. 
 -
 - Reading material: http://www.haskell.org/haskellwiki/Top_level_mutable_state
 -}

-- TODO: This isn't HelloWorld any more, Dorthy

hInGHCI :: IORef Handle
{-# NOINLINE hInGHCI #-}
hInGHCI = unsafePerformIO (newIORef undefined)

hOutGHCI :: IORef Handle
{-# NOINLINE hOutGHCI #-}
hOutGHCI = unsafePerformIO (newIORef undefined)

staticFiles "static"

mkYesod "HelloWorld" [parseRoutes|
/       HomeR   GET
/ghci   GHCIR   GET
/static StaticR Static helloWorldStatic
|]

instance Yesod HelloWorld where
    approot _ = ""

getGHCIR :: Handler RepHtml
getGHCIR = do
  defaultLayout [whamlet|test|]

getHomeR :: Handler RepHtml
getHomeR = do
  result <- liftIO $ queryGHCI ":t 5.0\n"
  liftIO $ print result
  defaultLayout [whamlet|
<html>
  <head>
    <title> ghci in a new dress </title>
    <link rel="stylesheet" type="text/css" href="static/style.css">
    <script src="https://ajax.googleapis.com/ajax/libs/jquery/1.7.1/jquery.min.js"> </script>
    <script src="static/main.js"> </script>
  </head>
  <body>
    <ul id="autocomplete"> 
      <li>something</li>
      <li>other thing</li>
    </ul>

    <div id="console">
      <div id="active">
        <span id="prompt">
          $
        </span>
        <span id="content">
          This is a console.
        </span>
        <span id="cursor">_</span>
      </div>
    </div>
  </body>
</html>|]

readIntro hout = do
  line <- hGetLine hout
  if "Prelude" `isInfixOf` line
    then return ()
    else readIntro hout

-- This only works if the result is one line long, which may not be the case.
queryGHCI input = do
  hin <- readIORef hInGHCI
  hout <- readIORef hOutGHCI

  hPutStr hin input
  output <- hGetLine hout
  return output

main :: IO ()
main = do
  (Just hin, Just hout, _, _) <- createProcess (proc "ghci" []) { std_out = CreatePipe, std_in = CreatePipe }

  hSetBuffering hin NoBuffering
  hSetBuffering hout NoBuffering

  hPutStr hin ":t 1\n"
  readIntro hout

  writeIORef hInGHCI hin
  writeIORef hOutGHCI hout

  s <- static "static"

  warpDebug 3000 $ HelloWorld s
