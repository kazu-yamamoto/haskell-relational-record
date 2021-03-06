-- |
-- Module      : Database.Relational.Query.Internal.ShowS
-- Copyright   : 2013 Kei Hibino
-- License     : BSD3
--
-- Maintainer  : ex8k.hibino@gmail.com
-- Stability   : experimental
-- Portability : unknown
--
-- This module provides SQL string concatination functions
-- which result is ShowS differential lists.
module Database.Relational.Query.Internal.ShowS (
  showUnwordsSQL, showWordSQL, showUnwords
  ) where

import Language.SQL.Keyword (unwordsSQL)
import qualified Language.SQL.Keyword as SQL

-- | Unwords 'SQL.Keyword' list and resturns 'ShowS'.
showUnwordsSQL :: [SQL.Keyword] -> ShowS
showUnwordsSQL =  showString . unwordsSQL

-- | From 'SQL.Keyword' into 'ShowS'.
showWordSQL :: SQL.Keyword -> ShowS
showWordSQL =  showString . SQL.wordShow

-- | 'ShowS' version of unwords function.
showUnwords :: [ShowS] -> ShowS
showUnwords =  rec  where
  rec []     = id
  rec [s]    = s
  rec (s:ss@(_:_)) = s . showChar ' ' . rec ss
