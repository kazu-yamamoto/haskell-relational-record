{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}

-- |
-- Module      : Database.Relational.Query.Monad.Trans.Ordering
-- Copyright   : 2013 Kei Hibino
-- License     : BSD3
--
-- Maintainer  : ex8k.hibino@gmail.com
-- Stability   : experimental
-- Portability : unknown
--
-- This module defines monad transformer which lift
-- from 'MonadQuery' into query with ordering.
module Database.Relational.Query.Monad.Trans.Ordering (
  -- * Transformer into query with ordering
  Orderings, orderings, OrderedQuery, OrderingTerms,

  -- * API of query with ordering
  asc, desc,

  -- * Result order by SQLs
  appendOrderBys
  ) where

import Control.Monad.Trans.Class (MonadTrans (lift))
import Control.Monad.Trans.State (StateT, runStateT, modify)
import Control.Applicative (Applicative, (<$>))
import Control.Arrow (second)

import Database.Relational.Query.Internal.OrderingContext
  (Order(Asc, Desc), OrderingContext, primeOrderingContext)
import qualified Database.Relational.Query.Internal.OrderingContext as Context

import Database.Relational.Query.Projection (Projection)
import qualified Database.Relational.Query.Projection as Projection
import Database.Relational.Query.Aggregation (Aggregation)
import qualified Database.Relational.Query.Aggregation as Aggregation

import Database.Relational.Query.Monad.Class
  (MonadQuery(on, wheres, unsafeSubQuery), MonadAggregate(groupBy, having))


-- | 'StateT' type to accumulate ordering context.
--   Type 'p' is ordering term projection type.
newtype Orderings (p :: * -> *) m a =
  Orderings { orderingState :: StateT OrderingContext m a }
  deriving (MonadTrans, Monad, Functor, Applicative)

-- | Run 'Orderings' to expand context state
runOrderings :: Orderings p m a        -- ^ Context to expand
             -> OrderingContext        -- ^ Initial context
             -> m (a, OrderingContext) -- ^ Expanded result
runOrderings =  runStateT . orderingState

-- | Run 'Orderings' with primary empty context to expand context state.
runOrderingsPrime :: Orderings p m a        -- ^ Context to expand
                  -> m (a, OrderingContext) -- ^ Expanded result
runOrderingsPrime q = runOrderings q $ primeOrderingContext

-- | Lift to 'Orderings'.
orderings :: Monad m => m a -> Orderings p m a
orderings =  lift

-- | 'MonadQuery' with ordering.
instance MonadQuery m => MonadQuery (Orderings p m) where
  on     =  orderings . on
  wheres =  orderings . wheres
  unsafeSubQuery na       = orderings . unsafeSubQuery na
  -- unsafeMergeAnotherQuery = unsafeMergeAnotherOrderBys

-- | 'MonadAggregate' with ordering.
instance MonadAggregate m => MonadAggregate (Orderings p m) where
  groupBy = orderings . groupBy
  having  = orderings . having

-- | OrderedQuery type synonym. Projection must be the same as 'Orderings' type parameter 'p'
type OrderedQuery p m r = Orderings p m (p r)

-- | Ordering term projection type interface.
class OrderingTerms p where
  orderTerms :: p t -> [String]

-- | 'Projection' is ordering term.
instance OrderingTerms Projection where
  orderTerms = Projection.columns

-- | 'Aggregation' is ordering term.
instance OrderingTerms Aggregation where
  orderTerms = Projection.columns . Aggregation.projection

-- | Unsafely update ordering context.
updateOrderingContext :: Monad m => (OrderingContext -> OrderingContext) -> Orderings p m ()
updateOrderingContext =  Orderings . modify

-- | Add ordering terms.
updateOrderBys :: (Monad m, OrderingTerms p)
               => Order            -- ^ Order direction
               -> p t              -- ^ Ordering terms to add
               -> Orderings p m () -- ^ Result context with ordering
updateOrderBys order p = updateOrderingContext (\c -> foldl update c (orderTerms p))  where
  update = flip (Context.updateOrderBy order)

{-
takeOrderBys :: Monad m => Orderings p m OrderBys
takeOrderBys =  Orderings $ state Context.takeOrderBys

restoreLowOrderBys :: Monad m => Context.OrderBys -> Orderings p m ()
restoreLowOrderBys ros = updateOrderingContext $ Context.restoreLowOrderBys ros
unsafeMergeAnotherOrderBys :: UnsafeMonadQuery m
                           => NodeAttr
                           -> Orderings p m (Projection r)
                           -> Orderings p m (Projection r)

unsafeMergeAnotherOrderBys naR qR = do
  ros   <- takeOrderBys
  let qR' = fst <$> runOrderingsPrime qR
  v     <- lift $ unsafeMergeAnotherQuery naR qR'
  restoreLowOrderBys ros
  return v
-}


-- | Add ascendant ordering term.
asc  :: (Monad m, OrderingTerms p)
     => p t              -- ^ Ordering terms to add
     -> Orderings p m () -- ^ Result context with ordering
asc  =  updateOrderBys Asc

-- | Add descendant ordering term.
desc :: (Monad m, OrderingTerms p)
     => p t              -- ^ Ordering terms to add
     -> Orderings p m () -- ^ Result context with ordering
desc =  updateOrderBys Desc


-- | Get order-by appending function from 'OrderingContext'.
appendOrderBys' :: OrderingContext -> String -> String
appendOrderBys' c = (++ d (Context.composeOrderBys c))  where
  d "" = ""
  d s  = ' ' : s

-- | Run 'Orderings' to get query result and order-by appending function.
appendOrderBys :: MonadQuery m
               => Orderings p m a         -- ^ 'Orderings' to run
               -> m (a, String -> String) -- ^ Query result and order-by appending function.
appendOrderBys q = second appendOrderBys' <$> runOrderingsPrime q
