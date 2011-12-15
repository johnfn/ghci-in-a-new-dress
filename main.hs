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


import Debug.Trace (trace)
--import Text.HTML.TagSoup
import Text.XmlHtml
import Data.ByteString.Char8 (pack)
import qualified Data.Text as T
import Data.Maybe


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

hErrGHCI :: IORef Handle
{-# NOINLINE hErrGHCI #-}
hErrGHCI = unsafePerformIO (newIORef undefined)

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

tempFileName :: String
tempFileName = "commandsEntered.hs"

tempDataDefs :: String
tempDataDefs = "dataDefs.hs"

isSpace :: Char -> Bool
isSpace c = (c == ' ') || (c == '\n')

trimWhitespace :: String -> String
trimWhitespace = f . f
   where f = reverse . dropWhile isSpace

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

  result <- liftIO $ queryGHCI content

  defaultLayout [whamlet|#{result}|]

getHomeR :: Handler RepHtml
getHomeR = do
  result <- liftIO $ queryGHCI ":t 5.0\n"
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
    <div id="program">
      <div id="console">
        <div class="input" id="active">
          <span id="prompt">
            $
          </span>
          <span id="content">
          </span>
          <span id="cursor">_</span>
        </div>
        <div id="sidebar">
          <h3>
            Inspector
          </h3>
          <ul id="sidelist">
          </ul>
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
    line <- hGetLine hout 
    if sentinel `isInfixOf` line
      then return "\n"
      else go (line ++ "\n")
  where
    go resultSoFar = do
      line <- hGetLine hout

      if sentinel `isInfixOf` line
        then return (resultSoFar)
        else go (resultSoFar ++ line ++ "\n")

lineIsFunctionDefinition :: String -> Bool
lineIsFunctionDefinition line = 
  ("=" `isInfixOf` line) && (not (" " `isPrefixOf` line)) && (not ("data" `isPrefixOf` line))

getFunctionName :: String -> String
getFunctionName line =
  (words line) !! 0

stripLet :: String -> String
stripLet str =
  if "let" `isPrefixOf` str
    then drop 4 str
    else str

-- Strip double definitions out of a Haskell file, retaining
-- only the last one. 
stripDoubleDefs :: String -> IO [String]
stripDoubleDefs file = do
    contents <- liftM lines $ readFile file
    let result = go contents [""] [""]

    return (result)
  where
    go :: [String] -> [String] -> [String] -> [String]
    -- Build valid Haskell program, putting data first, and
    -- all commands inside of a do block.
    go [] result dataLines = dataLines ++ result

    -- Gather all inputted lines.
    go (line:lines) result dataLines =
      if lineIsFunctionDefinition line
        then
          let name = getFunctionName line in
            if (any (==line) (map getFunctionName lines))
              then go lines result dataLines
              else go lines (result ++ [stripLet $ line]) dataLines
        else 
          if "data" `isPrefixOf` line 
            then go lines result (dataLines ++ [line])
            else go lines (result) dataLines
      

-- Handles text typed in the REPL that does data constructor declarations (data Color = Black | White)
handleDataInput input hin hout herr = do
  appendFile tempDataDefs ""
  appendFile tempFileName ""

  oldDataDefs <- readFile tempDataDefs
  oldInput <- readFile tempFileName

  liftIO $ print oldDataDefs
  liftIO $ print oldInput

  liftIO $ print "appending"
  liftIO $ print input

  appendFile tempDataDefs input

  hPutStr hin (":load " ++ tempDataDefs ++ "\n")
  mapM (hPutStr hin) (map (++"\n") (lines oldInput))

  hPutStr hin (":t " ++ sentinel ++ "\n")
  hPutStr hin "oopsthisisnotavariable\n"

  output <- readUntilDone hout
  errLine <- hGetLine herr

  if "oopsthisisnotavariable" `isInfixOf` errLine
    then return ""
    else do
      liftIO $ print errLine
      -- Error with that data definition. Forget about it.
      errors <- getErrors herr
      liftIO $ print "ERrors received:"
      liftIO $ print errors
      if (trimWhitespace errors) == ""
        then return ""
        else do
          writeFile tempDataDefs oldDataDefs
          --load from known good file
          hPutStr hin (":load " ++ tempDataDefs ++ "\n")
          mapM (hPutStr hin) (map (++"\n") (lines oldInput))
          hPutStr hin (":t " ++ sentinel ++ "\n")
          output <- readUntilDone hout
          return errors

getErrors :: Handle -> IO String
getErrors herr = 
    go herr ""
  where
    go herr results = do
      line <- hGetLine herr

      if "oopsthisisnotavariable" `isInfixOf` line
        then return(results)
        else go herr (results ++ "\n" ++ line)


-- Take the interactive output and make it a little more JavaScript friendly.
-- Return a tuple of (position, position, details)
parseErrors :: String -> [String]
parseErrors str =
    go str "" "" 0
  where
    -- <interactive>:1:1:
    go :: String -> String -> String -> Int -> [String]
    go rest first second 3 = [first, second, rest]

    go (s:str) first second seen =
      if s == ':'
        then go str first second (seen + 1)
        else
          case seen of
            1 -> go str (first ++ [s]) second seen
            2 -> go str first (second ++ [s]) seen
            _ -> go str first second seen

queryGHCI :: String -> IO String
queryGHCI input | last input /= '\n' = queryGHCI $ input ++ "\n" -- Append a newline character to the end of input
queryGHCI input = 
  
  -- TODO: Prevent this from running 
  -- Handle Hoogle queries
  if ":doc" `isPrefixOf` input then queryHaddock input else
  if ":hoogle" `isPrefixOf` input then queryHoogle input else do
  
  -- Lock this function. Only 1 person can query
  -- ghci at a time.
  
  -- Get Hlint suggests only if it's Haskell code and not an interpretor command
  hlint <- if ":" `isPrefixOf` input then (return "") else ((hlintCheck input) )
  let hlintSugg = if ":" `isPrefixOf` input then hlint else (hlint ++ "\n")

  -- If "No suggestions", then don't send it in down and if it already ends with '\n', don't do anything
  
  _ <- takeMVar lockGHCI
  hin <- readIORef hInGHCI
  hout <- readIORef hOutGHCI
  herr <- readIORef hErrGHCI

  errors <- if "data " `isPrefixOf` input
              then do
                err <- handleDataInput input hin hout herr
                liftIO $ print "DONE"
                return err
              else do
                hPutStr hin input
                if ":" `isPrefixOf` input
                  then return ""
                  else do
                    hPutStr hin "oopsthisisnotavariable\n"
                    appendFile tempFileName input
                    err <- getErrors herr
                    return err

  
  -- This is a hack that lets us discover where the end of the output is.
  -- We will keep reading until we see the sentinel.
  hPutStr hin (":t " ++ sentinel ++ "\n")

  output <- readUntilDone hout
  putMVar lockGHCI True

  if trimWhitespace(errors) == "" 
    then return (hlintSugg ++ output)
    else return ("ERR: " ++ (show $ parseErrors $ errors))


-- External helpers

hlintCheck :: String -> IO String
hlintCheck code = do
    -- `code` already ends with a newline character
    writeFile "/tmp/temp.hs" ( "main = do" ++ "\n\t" ++ code ++ "\t" ++ "return ()" )
    ( Just hin, Just hout, _ , _ ) <- createProcess (proc "hlint" ["/tmp/temp.hs"]) { std_out = CreatePipe, std_in = CreatePipe }
    output <- hGetContents hout
    return output

queryHoogle :: String -> IO String
queryHoogle keyword = do
    -- TODO: Fix newline issue and handle Hoogle errors
    let keywords = case (stripPrefix ":hoogle" keyword) of
                        (Just x) -> dropWhile (\y -> y == ' ') x
                        Nothing -> "list"
    liftIO $ print "Hoogle"
    liftIO $ print keyword
    (Just hin, Just hout, _, _) <- createProcess (proc "hoogle" ["--count=20", keywords]) { std_out = CreatePipe, std_in = CreatePipe }
    output <- hGetContents hout
    liftIO $ print output
    return output


queryHaddock :: String -> IO String
queryHaddock keyword = do
    -- TODO: Fix newline issue and handle Hoogle errors
  let keywords = case (stripPrefix ":doc" keyword) of
                      (Just x) -> takeWhile (\y -> not (y == '\n')) $ dropWhile (\y -> y == ' ') x
                      Nothing -> "list"
  liftIO $ print "Haddock"
  doc_  <- getDocForFn keywords
  liftIO $ print doc_
  return doc_

main :: IO ()
main = do
  fileExists <- doesFileExist tempFileName
  if fileExists
    then removeFile tempFileName
    else return ()
   
  fileExists <- doesFileExist tempDataDefs
  if fileExists
    then removeFile tempDataDefs
    else return ()

  (Just hin, Just hout, Just herr, _) <- createProcess (proc "ghci" []) { std_out = CreatePipe, std_in = CreatePipe, std_err = CreatePipe }

  hSetBuffering hin NoBuffering
  hSetBuffering hout NoBuffering
  hSetBuffering herr NoBuffering

  hPutStr hin ":t 1\n"
  readIntro hout

  writeIORef hInGHCI hin
  writeIORef hOutGHCI hout
  writeIORef hErrGHCI herr

  s <- staticDevel "static"

  warpDebug 3000 $ HelloWorld s


--- haddockParser
-- module HaddockParser Func (Func) where

data Func = Func {
    name :: String,
    type_ :: String,
    doc  :: String
} deriving (Show)

-- findDefEls =

parseTree n =
    let
        nodeTag = tagName n
        cls = getAttribute (T.pack "class") n
    in
        if not ((isNothing nodeTag) || (isNothing cls) || (not ((fromJust cls) == (T.pack "top"))))
            then ([n] ++ concat (map parseTree $ childNodes n))
            else
                concat (map parseTree $ childNodes n)

convertNodeToMarkup n | isElement n = let tagName_ = T.unpack $ fromJust $ tagName n
                                          -- attrs = map (\x -> ((T.unpack $ fst x) ++ "=" ++ (T.unpack $ snd x))) (elementAttrs n)
                                          -- attrs
                                       in
                                        "<" ++ tagName_ ++ " " ++ ">"  ++ (concat $ map convertNodeToMarkup $ childNodes n) ++ "</" ++ tagName_ ++ ">"
                      | isTextNode n = T.unpack $ nodeText n

parseHaddock :: String -> [Func]
parseHaddock doc =
    let eitherDoc = (parseHTML "html" $ pack doc)
        parseEl e = (Func (extractName e) (extractType e) (extractDoc  e))
        extractName e = T.unpack $ nodeText $ head $ childElements $ head $ childElements e
        extractType e = concat $ map T.unpack $ map nodeText $ init $ drop 1 $ childNodes $ head $ childElements e
        extractDoc  e = convertNodeToMarkup $ (!!) (childElements e) 1
    in
        case eitherDoc of 
            (Right doc_) -> map parseEl $ parseTree (head (docContent doc_))
            (Left err) -> []

test = do
        html <- readFile "test.html"
        return (parseHaddock html)

getDocForFn name_ = do
  html <- readFile "test.html"
  liftIO $ print name_
  let fns = parseHaddock html
      fnDoc = (filter (\x -> ((name x) == name_)) fns)
  return (if (length fnDoc > 0) then "DOC" ++ (doc $ head fnDoc) else "DOC<div class=\"error\">Nothing was found</div>")

--main = do
--    str <- test
--    -- putStrLn str
--    return ()
