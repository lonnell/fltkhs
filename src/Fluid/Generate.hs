{-# LANGUAGE ScopedTypeVariables #-}
module Generate
       (collapseString,
        typeToHs,
        typicalConstructorG,
        constructorG,
        attributeG,
        toHs
       )
       where

import           Control.Monad.State
import           Control.Monad.Writer
import           Control.Monad.Identity
import           Data.Char
import           Data.List
import           Foreign.C.Types
import           Graphics.UI.FLTK.LowLevel.Utils
import           Lookup
import           Numeric
import           Types
import           Parser
apply
  :: [Char] -> [Char] -> Maybe [Char] -> [Char]
apply f n args =
  f ++ " " ++ n ++ (maybe "" (\args' -> " " ++ args') args)


collapseParts :: [BracedStringParts] -> String
collapseParts parts = go parts []
  where go ((BareString s):_parts) accum =
          go _parts (accum ++ s)
        go ((QuotedCharCode c):_parts) accum =
          go _parts (accum ++ "\\" ++ [c])
        go ((QuotedHex h):_parts) accum =
          go _parts (accum ++ "0x" ++ (showHex h ""))
        go ((QuotedOctal o):_parts) accum =
          go _parts (accum ++ "0o" ++ (showOct o ""))
        go ((QuotedChar c):_parts) accum =
          go _parts (accum ++ c)
        go ((NestedBrace ps):_parts) accum =
          go _parts ("{" ++ (go ps accum) ++ "}")
        go [] accum = accum

collapseString :: UnbrokenOrBraced -> String
collapseString (UnbrokenString s) = s
collapseString (BracedString []) = ""
collapseString (BracedString parts) = collapseParts parts

typeToHs :: String -> String -> Maybe String
typeToHs flClassName flWidgetType
  | flClassName == "Fl_Box" =
    lookup flWidgetType boxType
  | flClassName == "Fl_Slider" || flClassName == "Fl_Value_Slider" =
    lookup flWidgetType sliderType
  | flClassName == "Fl_Roller" =
    lookup flWidgetType valuatorType
  | flClassName == "Fl_Input" =
    lookup flWidgetType inputType
  | flClassName == "Fl_Output" =
    lookup flWidgetType outputType
  | flClassName == "Fl_Pack" =
    lookup flWidgetType packType
  | flClassName == "Fl_Button" =
    lookup flWidgetType buttonType
  | flClassName == "Fl_Browser" =
    lookup flWidgetType browserType
  | flClassName == "Fl_MenuItem" =
    lookup flWidgetType menuItemType
  | flClassName == "Fl_MenuButton" =
    lookup flWidgetType menuButtonType
  | flClassName == "Fl_Dial" =
    lookup flWidgetType dialType
  | flClassName == "Fl_Valuator" =
    lookup flWidgetType valuatorType
  | flClassName == "Fl_Counter" =
    lookup flWidgetType counterType
  | flClassName == "Fl_Scroll" =
    lookup flWidgetType scrollType
  | flClassName == "Fl_Scrollbar" =
    lookup flWidgetType scrollbarType
  | flClassName == "Fl_Window" =
    lookup flWidgetType windowType
  | flClassName == "Fl_Spinner" =
    lookup flWidgetType spinnerType
  | otherwise = Nothing

typicalConstructorG
  :: Maybe String -> (Int,Int,Int,Int) -> String -> String
typicalConstructorG name posSize constructorF =
  (maybe "_ <- " (\n -> n ++ " <- ") name) ++
  (apply constructorF "" (Just $ "(toRectangle " ++ show posSize ++ ") Nothing"))

constructorG
  :: String -> String -> Maybe String -> (Int,Int,Int,Int) -> [String]
constructorG flClassName hsConstructor name posSize
  | flClassName == "Fl_Table" =
    ["-- Fl_Table " ++ (maybe "" id name) ++ " " ++ (show posSize)]
  | flClassName == "MenuItem" || flClassName == "Submenu" =
    [(maybe "_ <- " (\n -> n ++ " <- ") name) ++ "menuItemNew"]
  | flClassName == "Fl_Window" =
    let (x,y,w,h) = posSize in
    [(maybe "_ <- " (\n -> n ++ " <- ") name) ++
    (apply hsConstructor "" (Just $ "(Size (Width " ++ show w ++ ") (Height " ++ show h ++ ")) (Just (Position (X " ++ show x ++ ") (Y " ++ show y ++ "))) Nothing"))]
  | flClassName == "Fl_Input" || flClassName == "Fl_Output" =
    [typicalConstructorG name posSize hsConstructor ++ " Nothing"]
  | otherwise = [typicalConstructorG name posSize hsConstructor]

attributeG
  :: String -> String -> Attribute -> String
attributeG flClassName name attr =
  case attr of
    Types.Label l ->
      apply "setLabel" name (Just $ show $ collapseString l)
    Types.Value v ->
      apply "setValue" name (Just $ collapseString v)
    Types.WidgetType w ->
      maybe ""
            (\t ->
               (apply "setType" name) (Just t))
            (typeToHs flClassName (collapseString w))
    Types.Color c ->
      apply "setColor" name (Just $ "(Color " ++ (show c) ++ ")")
    Types.Maximum m ->
      apply "setMaximum" name (Just (show m))
    Types.Box b ->
      maybe ""
            (\t -> apply "setBox" name (Just t))
            (lookup b boxType)
    Types.Labelsize s ->
      apply "setLabelsize" name (Just ("(FontSize " ++ (show s) ++ ")"))
    Types.Resizable ->
      apply "setResizable" name (Just ("((Just (safeCast " ++ name  ++ ")) :: Maybe (Ref Widget))"))
    Types.Visible ->
      apply "setVisible" name Nothing
    Types.Align a ->
      apply "setAlign" name (Just $ "(" ++ (show $ intToAlignments a) ++ ")")
    Types.Minimum m ->
      apply "setMinimum" name (Just $ show m)
    Types.Step s ->
      apply "setStep" name (Just $ show s)
    Types.SelectionColor sc ->
      apply "setSelectionColor" name (Just $ "(Color " ++ (show sc) ++ ")")
    Types.Labeltype l ->
      maybe ""
            (\_f ->
               (apply "setLabeltype" name (Just _f)))
            (lookup (show l) labelType)
    Types.Labelcolor c ->
      apply "setLabelcolor" name (Just $ "(Color " ++ (show c) ++ ")")
    Types.Labelfont f ->
      maybe ""
            (\_f ->
               (apply "setLabelfont" name (Just _f)))
            (lookup (show f) fontType)
    Types.Shortcut s ->
      maybe []
            (\ks -> apply "setShortcut" name (Just ("(" ++ (show ks) ++ ")")))
            (cIntToKeySequence ((read s) :: CInt))
    Types.Tooltip t ->
      apply "setTooltip" name (Just $ show $ collapseString t)
    Types.When w ->
      apply "setWhen" name (Just $ "[" ++ (snd (whenType !! w)) ++ "]")
    Types.Hotspot ->
      apply "setHotspot" name Nothing
    Types.Modal ->
      apply "setModal" name Nothing
    Types.TextFont f ->
      maybe ""
            (\_f ->
               (apply "setTextfont" name (Just _f)))
            (lookup (show f) fontType)
    Types.TextSize s ->
      apply "setTextsize" name (Just ("(FontSize " ++ (show s) ++ ")"))
    Types.TextColor c ->
      apply "setTextcolor" name (Just $ "(Color " ++ (show c) ++ ")")
    Types.SliderSize s ->
      apply "setSlizersize" name (Just $ show s)
    Types.Deactivate ->
      apply "deactivate" name Nothing
    Types.DownBox b ->
      maybe ("-- unknown Box type: " ++ b) (\b' -> apply "setDownBox" name (Just b')) (lookup b boxType)
    Types.SizeRange (minw', minh', maxw', maxh') ->
      apply "sizeRangeWithArgs"
            name
            (Just $
             (show minw') ++
             " " ++
             (show minh') ++
             " " ++
             "defaultOptionalSizeRangeArgs {" ++
             "maxw = " ++ (show maxw' ++ "," ++ "maxh =" ++ (show maxh') ++ "}"))
    Types.Callback code ->
      apply "setCallback" name (Just $ collapseString code)
    Types.Code0 code ->
      collapseParts code
    Types.Code1 code ->
      collapseParts code
    Types.Code2 code ->
      collapseParts code
    Types.Code3 code ->
      collapseParts code
    unknown -> " -- unknown attribute: " ++ (show unknown)

haskellIdToName :: TakenNames -> String -> HaskellIdentifier -> String
haskellIdToName _ _ (ValidHaskell hid) = hid
haskellIdToName _ _ (InvalidHaskell hid) = hid
haskellIdToName _ _ UnidentifiedFunction = "main"
haskellIdToName (TakenNames names) hsClassName Unidentified =
  let classNumber = do
        haskellFriendly <- case hsClassName of
          (x:xs) -> return ([(toLower x)] ++ xs)
          []     -> Nothing
        let ofType = filter (\n -> haskellFriendly `isPrefixOf` n) names
        return $ (haskellFriendly, length ofType)
  in maybe "o" (\(tc, n) -> tc ++ (show n)) classNumber

concatTakenNames :: TakenNames -> TakenNames -> TakenNames
concatTakenNames (TakenNames ns) (TakenNames ns') = TakenNames (nub $ ns ++ ns')

findDrop :: [a] -> (a -> Bool) -> (Maybe a, [a])
findDrop as pred' =
  let (found, rest) = partition pred' as
  in
    case found of
      [] -> (Nothing, rest)
      (_ : _ : _) -> (Nothing, rest)
      _ -> (Just (head found), rest)

menuItemCode :: String -> String -> [Attribute] -> ([String], [Attribute])
menuItemCode mn menuItemName restAttrs =
  let callbackCode callback = [
                                "let { callback :: Maybe (Ref MenuItem -> IO ()); callback = " ++ callback ++ "}"
                              ]
      labelCode label = [
                          "let { label = \"" ++ label ++ "\"}"
                        ]
      (((), attrs), haskellCode)= (runIdentity
                                      (runWriterT
                                         (runStateT
                                            (do
                                              let attrCode :: (Attribute -> Bool) ->
                                                              (Attribute -> [String]) ->
                                                              [String] ->
                                                              StateT [Attribute] (WriterT [String] Identity) ()
                                                  attrCode findAttr toCode fallback =
                                                     do
                                                       currentAttrs <- get
                                                       let (attr, restAttrs') = findDrop currentAttrs findAttr
                                                       modify (\_ -> restAttrs')
                                                       tell (maybe fallback toCode attr)
                                              attrCode (\a -> case a of Callback _ -> True; _ -> False)
                                                       (\(Callback c) -> callbackCode (collapseString c))
                                                       (callbackCode "(Nothing :: Maybe (Ref MenuItem -> IO ())) ")
                                              attrCode (\a -> case a of Label _ -> True ; _ -> False)
                                                       (\(Label l) -> labelCode (collapseString l))
                                                       ["let {label = " ++ menuItemName ++ "}"]
                                              tell [
                                                    "(MenuItemIndex idx) <- add " ++
                                                    mn ++ " label " ++
                                                    "(Nothing :: Maybe Shortcut) " ++
                                                    "callback " ++
                                                    "(MenuItemFlags [])",
                                                    mn ++ "_menuItems <- getMenu " ++ mn,
                                                    "let {" ++ menuItemName ++ " = fromJust (" ++ mn ++ "_menuItems !! idx)}"
                                                   ]
                                              attrCode (\a -> case a of Shortcut _ -> True; _ -> False)
                                                       (\(Shortcut s) ->
                                                            maybe
                                                              []
                                                              (\ks -> ["setShortcut " ++ mn ++ " idx (" ++ (show ks) ++ ")"])
                                                              (cIntToKeySequence ((read s) :: CInt)))
                                                       []
                                             ) restAttrs)))
  in (haskellCode, attrs)
determineClassName :: String -> [Attribute] -> (Maybe (String, String, String), [Attribute])
determineClassName flClassName attrs =
  case findDrop attrs
       (\a -> case a of
          DerivedFromClass _ -> True
          _ -> False) of
     (Just (DerivedFromClass derivedClass), restAttrs) ->
       (maybe Nothing (\(c,cons) -> Just (derivedClass, c, cons)) (lookup derivedClass flClasses) , restAttrs)
     _ -> (maybe Nothing (\(c,cons) -> Just (flClassName, c, cons)) (lookup flClassName flClasses), attrs)

widgetTreeG :: Maybe String -> WidgetTree -> State TakenNames [String]
widgetTreeG menuName widgetTree =
  case widgetTree of
    (Group flClassName haskellId attrs trees) ->
      case (determineClassName flClassName attrs) of
        (Just (newFlClassName, hsClassName, hsConstructor), restAttrs) ->
          case findDrop restAttrs
                 (\a -> case a of
                    XYWH _ -> True
                    _      -> False) of
            (Just (XYWH posSize), restAttrs) -> do
              takenNames <- get
              let newName = haskellIdToName takenNames hsClassName haskellId
              modify (\ns -> concatTakenNames ns (TakenNames [newName]))
              (newNames, innerTreeOutput) <-
                get >>= \names ->
                           return
                             (foldl
                                (\(takenNames', outputSoFar) tree ->
                                   let (output, newNames) = runState
                                                              (widgetTreeG
                                                                 Nothing
                                                                 tree)
                                                              takenNames'
                                   in (concatTakenNames takenNames' newNames, outputSoFar ++ output))
                                (names, [])
                                trees)
              modify (\ns -> concatTakenNames ns newNames)
              let code = (constructorG newFlClassName hsConstructor (Just newName) posSize) ++
                         (map (attributeG hsClassName newName) restAttrs) ++
                         ["begin " ++ newName] ++
                         innerTreeOutput ++
                         ["end " ++ newName]
              return code
            _ -> return []
        _ -> return ["-- unknown FLTK class: " ++ flClassName]
    (Menu flClassName haskellId attrs trees) ->
      case (determineClassName flClassName attrs) of
        (Just (newFlClassName, hsClassName, hsConstructor), restAttrs) ->
          case findDrop restAttrs
                 (\a -> case a of
                    XYWH _ -> True
                    _      -> False) of
            (Just (XYWH posSize), restAttrs) -> do
              takenNames <- get
              let newName = haskellIdToName takenNames hsClassName haskellId
              modify (\ns -> concatTakenNames ns (TakenNames [newName]))
              (newNames, innerTreeOutput) <-
                 get >>= \names ->
                   return
                     (foldl
                        (\(takenNames', outputSoFar) tree ->
                           let (output, newNames) = runState (widgetTreeG
                                                               (case hsClassName of {
                                                                  "Submenu" -> menuName;
                                                                  _ -> (Just newName)
                                                                })
                                                               tree)
                                                              takenNames'
                           in (concatTakenNames takenNames' newNames, outputSoFar ++ output))
                        (names, [])
                        trees)
              modify (\ns -> concatTakenNames ns newNames)
              let code = (case hsClassName of
                           "Submenu" ->
                              case menuName of
                                Just mn ->
                                  let (haskellCode, newAttrs) = menuItemCode mn newName restAttrs
                                  in
                                  haskellCode ++
                                  [
                                    "flags " ++ " <- getFlags " ++ newName,
                                    "let {newFlags = maybe (MenuItemFlags [Submenu]) (\\(MenuItemFlags fs)-> (MenuItemFlags (fs ++ [Submenu]))) flags}",
                                    "setMode " ++ mn ++ " idx newFlags"
                                  ] ++
                                  (map (attributeG newFlClassName newName) newAttrs) ++
                                  innerTreeOutput
                                _ ->
                                  (constructorG newFlClassName hsConstructor (Just newName) posSize) ++
                                  (map (attributeG newFlClassName newName) restAttrs) ++
                                  ["setMenu " ++ newName ++ " ([] :: [Ref MenuItem])"] ++
                                  innerTreeOutput
                           _ ->
                             (constructorG newFlClassName hsConstructor (Just newName) posSize) ++
                             (map (attributeG newFlClassName newName) restAttrs) ++
                             ["setMenu " ++ newName ++ " ([] :: [Ref MenuItem])"] ++
                             innerTreeOutput
                          )
              return code
            _ -> return []
        _ -> return ["-- unknown FLTK class: " ++ flClassName]
    (Component flClassName haskellId attrs) -> do
         case (determineClassName flClassName attrs) of
           (Just (newFlClassName, hsClassName, hsConstructor), restAttrs) ->
             case findDrop restAttrs
                    (\a -> case a of
                       XYWH _ -> True
                       _      -> False) of
               (Just (XYWH posSize), restAttrs) -> do
                 takenNames <- get
                 newName <- return (haskellIdToName takenNames hsClassName haskellId)
                 modify (\ns -> concatTakenNames ns (TakenNames [newName]))
                 let code = case hsClassName of
                               "MenuItem" ->
                                  case menuName of
                                     Just mn ->
                                       let (haskellCode, newAttrs) = menuItemCode mn newName restAttrs
                                       in haskellCode ++ (map (attributeG newFlClassName newName) newAttrs)
                                     _ -> []
                               _ -> (constructorG newFlClassName hsConstructor (Just newName) posSize) ++
                                    (case newFlClassName of
                                       "Fl_Output" -> ["setType " ++ newName ++ " FlNormalOutput"]
                                       _           -> []) ++
                                    (map (attributeG newFlClassName newName) restAttrs)
                 return code
               _ -> return []
           _ -> return ["-- unknown FLTK class: " ++ flClassName]
    (Code _ code) -> return [collapseString code]
    (StandAloneComment _ comment) -> return ["{-\n", collapseString comment, "\n-}"]
    _ -> return []

functionG :: Function -> [String]
functionG (Function haskellId args attrs trees) =
  let fArgs =
               case (haskellId, args) of
                 (UnidentifiedFunction, _) -> "IO ()"
                 (_, FunctionArgs Nothing)        -> "()"
                 (_, FunctionArgs (Just args'))   -> args'
      fName = haskellIdToName (TakenNames []) "" haskellId
      fBody = filter (not . null) $ concatMap (\t -> evalState (widgetTreeG Nothing t) (TakenNames [fName]))
                                      trees
      argumentNames = case findDrop attrs
                           (\a -> case a of
                              ReturnType _ -> True
                              _ -> False) of
                      (Just (ReturnType argNames), _) -> collapseString argNames
                      _ -> ""
      indent = "  "
  in
    [fName ++ " :: " ++ fArgs, fName ++ " " ++ argumentNames ++ " = ", indent ++ " do {"] ++
    (map (\line -> indent ++ "  " ++ line ++ ";") fBody) ++
    [indent ++ "}"]

disclaimer :: [String]
disclaimer =
  ["-- GENERATED by fltkhs-fluid, do not edit.",
  "-- Instead edit the original .fl file using the `fluid` tool that ships with FLTK."]

standardImports :: [String]
standardImports =
  [ "import Graphics.UI.FLTK.LowLevel.FLTKHS"
  , "import qualified Graphics.UI.FLTK.LowLevel.FL as FL"
  , "import Graphics.UI.FLTK.LowLevel.Fl_Types"
  , "import Graphics.UI.FLTK.LowLevel.Fl_Enumerations"
  , "import Data.Maybe"
  ]

fluidBlockG :: FluidBlock -> Maybe [String]
fluidBlockG (FluidFunction f) = Just ((filter (not . null) . functionG) f)
fluidBlockG (Decl _ importStatement) = Just [collapseString importStatement]
fluidBlockG _ = Nothing

toHs :: String -> Fluid -> Either GenerationError [String]
toHs moduleName fluid =
  case (toModuleIdentifier moduleName) of
    Nothing -> Left (BadModuleName "")
    Just (InvalidModule m) -> Left (BadModuleName m)
    Just (ValidModule m ) ->
      Right(intersperse "\n" (disclaimer ++ ["module " ++ m ++ " where "] ++ standardImports ++ blocksToHaskell))
  where
    blocksToHaskell :: [String]
    blocksToHaskell = foldl
                        (\accum generatedBlock -> maybe accum (\b -> accum ++ b) generatedBlock)
                        []
                        (map fluidBlockG fluid)