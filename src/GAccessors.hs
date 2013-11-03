{-# OPTIONS_GHC -Wall #-}
{-# LANGUAGE DefaultSignatures #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
--{-# LANGUAGE DeriveGeneric #-}

module GAccessors ( AccessorTree(..), accessors ) where

import GHC.Generics

showAccTree :: String -> AccessorTree a -> [String]
showAccTree spaces (Getter _) = [spaces ++ "Getter {}"]
showAccTree spaces (Data name trees) =
  [spaces ++ "Data " ++ show name] ++
  concatMap (showChild (spaces ++ "    ")) trees

showChild :: String -> (String, AccessorTree a) -> [String]
showChild spaces (name, tree) =
  [spaces ++ name] ++ (showAccTree (spaces ++ "    ") tree)

instance Show (AccessorTree a) where
  show = unlines . showAccTree ""

data AccessorTree a = Data (String,String) [(String, AccessorTree a)]
                    | Getter (a -> Double)

accessors :: Lookup a => a -> AccessorTree a
accessors = flip toAccessorTree id

class Lookup a where
  toAccessorTree :: a -> (b -> a) -> AccessorTree b

  default toAccessorTree :: (Generic a, GLookup (Rep a)) => a -> (b -> a) -> AccessorTree b
  toAccessorTree x f = gtoAccessorTree (from x) (from . f)

class GLookup f where
  gtoAccessorTree :: f a -> (b -> f a) -> AccessorTree b

class GLookupS f where
  gtoAccessorTreeS :: f a -> (b -> f a) -> [(String, AccessorTree b)]

instance Lookup Float where
  toAccessorTree _ f = Getter $ realToFrac . f
instance Lookup Double where
  toAccessorTree _ f = Getter $ realToFrac . f
instance Lookup Int where
  toAccessorTree _ f = Getter $ fromIntegral . f

instance (Lookup f, Generic f) => GLookup (Rec0 f) where
  gtoAccessorTree x f = toAccessorTree (unK1 x) (unK1 . f)

instance (Selector s, GLookup a) => GLookupS (S1 s a) where
  gtoAccessorTreeS x f = [(selName x, gtoAccessorTree (unM1 x) (unM1 . f))]

instance (GLookupS f, GLookupS g) => GLookupS (f :*: g) where
  gtoAccessorTreeS (x :*: y) f = tf ++ tg
    where
      tf = gtoAccessorTreeS x $ left . f
      tg = gtoAccessorTreeS y $ right . f

      left  ( x' :*: _  ) = x'
      right ( _  :*: y' ) = y'

instance (Datatype d, Constructor c, GLookupS a) => GLookup (D1 d (C1 c a)) where
  gtoAccessorTree d@(M1 c) f = Data (datatypeName d, conName c) con
    where
      con = gtoAccessorTreeS (unM1 c) (unM1 . unM1 . f)

--data Xyz = Xyz { xx :: Int
--               , yy :: Double
--               , zz :: Float
--               , ww :: Int
--               } deriving (Generic)
--data One = MkOne { one :: Double } deriving (Generic)
--data Foo = Foo { aaa :: Int
--               , bbb :: Xyz
--               , ccc :: One
--               } deriving (Generic)
--instance Lookup One
--instance Lookup Xyz
--instance Lookup Foo
--foo :: Foo
--foo = Foo 2 (Xyz 6 7 8 9) (MkOne 17)