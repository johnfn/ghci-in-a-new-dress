{-# LANGUAGE TypeFamilies, QuasiQuotes, MultiParamTypeClasses,
              TemplateHaskell, OverloadedStrings #-}


import Yesod
import Yesod.Static
import Yesod.Request

import Text.Blaze
import System.Directory
import qualified Data.Text as T
import Data.Maybe
import Control.Concurrent
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

lockGHCI :: MVar Bool
{-# NOINLINE lockGHCI #-}
lockGHCI = unsafePerformIO (newMVar True)

staticFiles "static"

mkYesod "HelloWorld" [parseRoutes|
/       HomeR   GET
/ghci   GHCIR   POST
/static StaticR Static helloWorldStatic
|]

instance Yesod HelloWorld where
    approot _ = ""

unescape :: String -> String
unescape string = go string ""
  where
    go :: String -> String -> String
    go "" result = result
    go string result | "\\\\" `isPrefixOf` string = go (drop 2 string) (result ++ "\\")
    go string result | "&lt;" `isPrefixOf` string = go (drop 4 string) (result ++ "<")
    go string result | "&gt;" `isPrefixOf` string = go (drop 4 string) (result ++ ">")

    go string result | otherwise = go (drop 1 string) (result ++ [head string])

postGHCIR :: Handler RepHtml
postGHCIR = do
  -- This is how you get post data. 
  -- type of postTuples is [(Data.Text, Data.Text)] - key value pairs

  (postTuples, _) <- runRequestBody
  let content = unescape $ T.unpack (snd $ postTuples !! 0)
  
  liftIO $ print content

  result <- liftIO $ queryGHCI content
  defaultLayout [whamlet|#{result}|]

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
    </ul>
    <div id="typeannotations">
    </div>
    <div id="calltips">
    </div>
    <div id="console">
      <div id="active">
        <span id="prompt">
          $
        </span>
        <span id="content">
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

sentinel :: String
sentinel = "1234567890"

readUntilDone hout = do
    line <- hGetLine hout --remove "Prelude>" from first line.
    if sentinel `isInfixOf` line
      then return "\n"
      else go (line ++ "\n")
  where
    go resultSoFar = do
      line <- hGetLine hout

      if sentinel `isInfixOf` line
        then return (resultSoFar)
        else go (resultSoFar ++ line ++ "\n")

handleDataInput input hin hout = do
  writeFile "temp.hs" input
  hPutStr hin ":load temp.hs\n"
  hPutStr hin (":t " ++ sentinel ++ "\n")
  output <- readUntilDone hout

  removeFile "temp.hs"

queryGHCI :: String -> IO String
queryGHCI input | last input /= '\n' = queryGHCI $ input ++ "\n"
queryGHCI input = do
  -- Lock this function. Only 1 person can query
  -- ghci at a time.
  _ <- takeMVar lockGHCI

  hin <- readIORef hInGHCI
  hout <- readIORef hOutGHCI

  if "data " `isPrefixOf` input
    then handleDataInput input hin hout
    else hPutStr hin input
  
  -- This is a hack that lets us discover where the end of the output is.
  -- We will keep reading until we see the sentinel.
  hPutStr hin (":t " ++ sentinel ++ "\n")

  output <- readUntilDone hout

  putMVar lockGHCI True
  return output

main :: IO ()
main = do
  {- TODO: I think that ghci sometimes uses stderr, so I guess we should go
   - ahead and read from that one too. -}
  (Just hin, Just hout, _, _) <- createProcess (proc "ghci" []) { std_out = CreatePipe, std_in = CreatePipe }

  hSetBuffering hin NoBuffering
  hSetBuffering hout NoBuffering

  hPutStr hin ":t 1\n"
  readIntro hout

  writeIORef hInGHCI hin
  writeIORef hOutGHCI hout

  s <- staticDevel "static"

  warpDebug 3000 $ HelloWorld s
