{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}

module DataCreation where

import Language.Haskell.TH
import Data.Aeson
import Data.Maybe
import Data.HashMap.Strict as StrHash
import Data.Text
import Data.Char
import Data.Generics
import Language.Haskell.TH.Syntax
import Data.Vector
import Control.Monad.State

personJSON =  fromJust $ decode $ "{\"name\":\"Joe\",\"age\":25,\"avg\":4,\"arr\" : [1,2,3]}" :: Value

personJSON2 =  fromJust $ decode $ "{\"name\":\"Joe\",\"age\":25,\"avg\":4,\"arra\" : {\"fg\" : \"qwerty\"}}" :: Maybe Value

arrJs = fromJust $ decode $ "{\"fg\" : \"qwerty\"}" :: Maybe Value

compJSON = fromJust $ decode $ "{\"name\":\"Joe\",\"age\":{\"foo\": {\"r\" : 12}}}" :: Maybe Value

createData name' json' =
           DataD
                []
                (mkName name')
                []
                [ RecC (mkName name') (mka $ json') ]
                [mkName "Show", mkName "Eq"]

--toHashMap :: Value -> Object
toHashMap (Object obj) = obj

--проверка на то, что Value является Object
isObject :: Value -> Bool
isObject (Object obj) = True;
isObject _ = False;

--проверка на сложность JSON
isComp:: Value -> Bool
isComp (Object obj) = StrHash.foldl' (\pred elem -> if (isObject elem) then True
                                                  || pred else pred) False (obj)

getMapKeys :: Maybe Value -> [Text]
getMapKeys map' = foldlWithKey' (\list' key' val' -> if (isObject val')
                          then key' : list'
                          else key' : list') [] (toHashMap $ fromJust $ map')

firstLetterToUpper :: String -> String
firstLetterToUpper fieldName = (Data.Char.toUpper $ Prelude.head fieldName)
                                                     : (Prelude.tail fieldName)

--makeListVarStrictType :: [Text] -> [VarStrictType]
--makeListVarStrictType fNames = foldl (\list' val' -> (mkName) : list') [] fNames

getContentFromType (ConT val') = val'

--mkValType :: Value -> Type
mkValType (Number val') name'= ConT (mkName "Float")
mkValType (String val') name' = ConT (mkName "String")
mkValType (Bool val') name' = ConT (mkName "Bool")
mkValType (Array val') name' = AppT (ListT)
                                    (mkValType (Data.Vector.head val') name')
mkValType (Object val') name' = ConT (mkName $ firstLetterToUpper name')

numOfInsertedObjects:: Value -> Int
numOfInsertedObjects (Object obj) = foldlWithKey' (\acc' key' val' ->
         if isComp (Object obj)
           then acc' + 1 + numOfInsertedObjects val'
           else acc' + numOfInsertedObjects val') 0 obj

numOfInsertedObjects _ = 0

mapKeys' =  (foldlWithKey'
    (\map' key' value' -> StrHash.insert (Data.Text.unpack key') value' map')
    StrHash.empty)

--mka :: Maybe Value -> ([Language.Haskell.TH.Syntax.VarStrictType],)
mka map' =
                         foldlWithKey'
                         (\list' key' val' ->
    if (isObject val')
      then
            (Control.Monad.State.modify $ (Prelude.++) [(createData key' val')]) >>
            ((   (mkName $  key'),
                NotStrict,
                (   mkValType val' key'    )
            )
            : list')
      else
            (Control.Monad.State.modify $ (Prelude.++) []) >>
            ((  (mkName $ key'),
               NotStrict,
               (   mkValType val'  key'    )
            )
            : list')
                         )
                         []
                         (mapKeys' $ toHashMap map')

--mainConverter::DecsQ
mainConverter:: State [Dec] [Dec]
mainConverter = do
  acc <- Control.Monad.State.get
  Control.Monad.State.put []
  Control.Monad.State.modify $ (Prelude.++) [createData "JSONData" $ personJSON]
  return acc

getDataFromJSON::DecsQ
getDataFromJSON = do
  return $
          snd (runState mainConverter $ [])