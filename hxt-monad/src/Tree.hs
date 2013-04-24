{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeSynonymInstances  #-}

module Tree
{- just for testing
    ( Tree
    , isNull
    , isFail
    , fromList
    , toList
    )
-- -}
where

import           Control.Applicative
import           Control.Monad
import           Control.Monad.Arrow
import           Control.Monad.ArrowExc
import           Control.Monad.ArrowIf
import           Control.Monad.ArrowIO
import           Control.Monad.ArrowList
import           Control.Monad.ArrowState
import           Control.Monad.Error
import           Control.Monad.MonadList
import           Control.Monad.State.Strict
import           Data.List                  (partition)
import           Data.List.IOList
import           Data.List.IOTree
import           Data.List.Tree
import           Data.Monoid

-- ----------------------------------------

mk2 :: a -> a -> Tree a
mk2 x y = Bin (Tip x) (Tip y)

tt1,tt7,tt8 :: Tree Integer
tt1 = fromList [1]
tt7 = fromList [1..7]
tt8 = fromList [1..8]