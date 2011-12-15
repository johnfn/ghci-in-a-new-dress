import Debug.Trace (trace)
--import Text.HTML.TagSoup
import Text.XmlHtml
import Data.ByteString.Char8 (pack)
import qualified Data.Text as T
import Data.Maybe

-- module HaddockParser Func (Func) where


data Func = Func {
    name :: String,
    type_ :: String,
    doc  :: String
} deriving (Show)

 

-- type HTML = String

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

main = do
    str <- test
    -- putStrLn str
    return ()