{-# LANGUAGE MultiParamTypeClasses, FlexibleInstances #-}

-- |
-- Module      : Data.Vector.Mutable
-- Copyright   : (c) Roman Leshchinskiy 2008-2010
-- License     : BSD-style
--
-- Maintainer  : Roman Leshchinskiy <rl@cse.unsw.edu.au>
-- Stability   : experimental
-- Portability : non-portable
-- 
-- Mutable boxed vectors.
--

module Data.Vector.Mutable (
  -- * Mutable boxed vectors
  MVector(..), IOVector, STVector,

  -- * Accessors

  -- ** Length information
  length, null,

  -- ** Extracting subvectors
  slice, init, tail, take, drop,
  unsafeSlice, unsafeInit, unsafeTail, unsafeTake, unsafeDrop,

  -- ** Overlapping
  overlaps,

  -- * Construction

  -- ** Initialisation
  new, unsafeNew, replicate, clone,

  -- ** Growing
  grow, unsafeGrow,

  -- ** Restricting memory usage
  clear,

  -- * Accessing individual elements
  read, write, swap,
  unsafeRead, unsafeWrite, unsafeSwap,

  -- * Modifying vectors

  -- ** Filling and copying
  set, copy, unsafeCopy,

  -- * Deprecated operations
  newWith, unsafeNewWith
) where

import qualified Data.Vector.Generic.Mutable as G
import           Data.Primitive.Array
import           Control.Monad.Primitive

import Prelude hiding ( length, null, replicate, reverse, map, read,
                        take, drop, init, tail )

import Data.Typeable ( Typeable )

#include "vector.h"

-- | Mutable boxed vectors keyed on the monad they live in ('IO' or @'ST' s@).
data MVector s a = MVector {-# UNPACK #-} !Int
                           {-# UNPACK #-} !Int
                           {-# UNPACK #-} !(MutableArray s a)
        deriving ( Typeable )

type IOVector = MVector RealWorld
type STVector s = MVector s

instance G.MVector MVector a where
  {-# INLINE basicLength #-}
  basicLength (MVector _ n _) = n

  {-# INLINE basicUnsafeSlice #-}
  basicUnsafeSlice j m (MVector i n arr) = MVector (i+j) m arr

  {-# INLINE basicOverlaps #-}
  basicOverlaps (MVector i m arr1) (MVector j n arr2)
    = sameMutableArray arr1 arr2
      && (between i j (j+n) || between j i (i+m))
    where
      between x y z = x >= y && x < z

  {-# INLINE basicUnsafeNew #-}
  basicUnsafeNew n
    = do
        arr <- newArray n uninitialised
        return (MVector 0 n arr)

  {-# INLINE basicUnsafeReplicate #-}
  basicUnsafeReplicate n x
    = do
        arr <- newArray n x
        return (MVector 0 n arr)

  {-# INLINE basicUnsafeRead #-}
  basicUnsafeRead (MVector i n arr) j = readArray arr (i+j)

  {-# INLINE basicUnsafeWrite #-}
  basicUnsafeWrite (MVector i n arr) j x = writeArray arr (i+j) x

  {-# INLINE basicClear #-}
  basicClear v = G.set v uninitialised

uninitialised :: a
uninitialised = error "Data.Vector.Mutable: uninitialised element"

-- Length information
-- ------------------

-- | Length of the mutable vector.
length :: MVector s a -> Int
{-# INLINE length #-}
length = G.length

-- | Check whether the vector is empty
null :: MVector s a -> Bool
{-# INLINE null #-}
null = G.null

-- Extracting subvectors
-- ---------------------

-- | Yield a part of the mutable vector without copying it.
slice :: Int -> Int -> MVector s a -> MVector s a
{-# INLINE slice #-}
slice = G.slice

take :: Int -> MVector s a -> MVector s a
{-# INLINE take #-}
take = G.take

drop :: Int -> MVector s a -> MVector s a
{-# INLINE drop #-}
drop = G.drop

init :: MVector s a -> MVector s a
{-# INLINE init #-}
init = G.init

tail :: MVector s a -> MVector s a
{-# INLINE tail #-}
tail = G.tail

-- | Yield a part of the mutable vector without copying it. No bounds checks
-- are performed.
unsafeSlice :: Int  -- ^ starting index
            -> Int  -- ^ length of the slice
            -> MVector s a
            -> MVector s a
{-# INLINE unsafeSlice #-}
unsafeSlice = G.unsafeSlice

unsafeTake :: Int -> MVector s a -> MVector s a
{-# INLINE unsafeTake #-}
unsafeTake = G.unsafeTake

unsafeDrop :: Int -> MVector s a -> MVector s a
{-# INLINE unsafeDrop #-}
unsafeDrop = G.unsafeDrop

unsafeInit :: MVector s a -> MVector s a
{-# INLINE unsafeInit #-}
unsafeInit = G.unsafeInit

unsafeTail :: MVector s a -> MVector s a
{-# INLINE unsafeTail #-}
unsafeTail = G.unsafeTail

-- Overlapping
-- -----------

-- Check whether two vectors overlap.
overlaps :: MVector s a -> MVector s a -> Bool
{-# INLINE overlaps #-}
overlaps = G.overlaps

-- Initialisation
-- --------------

-- | Create a mutable vector of the given length.
new :: PrimMonad m => Int -> m (MVector (PrimState m) a)
{-# INLINE new #-}
new = G.new

-- | Create a mutable vector of the given length. The length is not checked.
unsafeNew :: PrimMonad m => Int -> m (MVector (PrimState m) a)
{-# INLINE unsafeNew #-}
unsafeNew = G.unsafeNew

-- | Create a mutable vector of the given length (0 if the length is negative)
-- and fill it with an initial value.
replicate :: PrimMonad m => Int -> a -> m (MVector (PrimState m) a)
{-# INLINE replicate #-}
replicate = G.replicate

-- | Create a copy of a mutable vector.
clone :: PrimMonad m => MVector (PrimState m) a -> m (MVector (PrimState m) a)
{-# INLINE clone #-}
clone = G.clone

-- Growing
-- -------

-- | Grow a vector by the given number of elements. The number must be
-- positive.
grow :: PrimMonad m
              => MVector (PrimState m) a -> Int -> m (MVector (PrimState m) a)
{-# INLINE grow #-}
grow = G.grow

-- | Grow a vector by the given number of elements. The number must be
-- positive but this is not checked.
unsafeGrow :: PrimMonad m
               => MVector (PrimState m) a -> Int -> m (MVector (PrimState m) a)
{-# INLINE unsafeGrow #-}
unsafeGrow = G.unsafeGrow

-- Restricting memory usage
-- ------------------------

-- | Reset all elements of the vector to some undefined value, clearing all
-- references to external objects. This is usually a noop for unboxed vectors. 
clear :: PrimMonad m => MVector (PrimState m) a -> m ()
{-# INLINE clear #-}
clear = G.clear

-- Accessing individual elements
-- -----------------------------

-- | Yield the element at the given position.
read :: PrimMonad m => MVector (PrimState m) a -> Int -> m a
{-# INLINE read #-}
read = G.read

-- | Replace the element at the given position.
write :: PrimMonad m => MVector (PrimState m) a -> Int -> a -> m ()
{-# INLINE write #-}
write = G.write

-- | Swap the elements at the given positions.
swap :: PrimMonad m => MVector (PrimState m) a -> Int -> Int -> m ()
{-# INLINE swap #-}
swap = G.swap


-- | Yield the element at the given position. No bounds checks are performed.
unsafeRead :: PrimMonad m => MVector (PrimState m) a -> Int -> m a
{-# INLINE unsafeRead #-}
unsafeRead = G.unsafeRead

-- | Replace the element at the given position. No bounds checks are performed.
unsafeWrite :: PrimMonad m => MVector (PrimState m) a -> Int -> a -> m ()
{-# INLINE unsafeWrite #-}
unsafeWrite = G.unsafeWrite

-- | Swap the elements at the given positions. No bounds checks are performed.
unsafeSwap :: PrimMonad m => MVector (PrimState m) a -> Int -> Int -> m ()
{-# INLINE unsafeSwap #-}
unsafeSwap = G.unsafeSwap

-- Filling and copying
-- -------------------

-- | Set all elements of the vector to the given value.
set :: PrimMonad m => MVector (PrimState m) a -> a -> m ()
{-# INLINE set #-}
set = G.set

-- | Copy a vector. The two vectors must have the same length and may not
-- overlap.
copy :: PrimMonad m
                 => MVector (PrimState m) a -> MVector (PrimState m) a -> m ()
{-# INLINE copy #-}
copy = G.copy

-- | Copy a vector. The two vectors must have the same length and may not
-- overlap. This is not checked.
unsafeCopy :: PrimMonad m => MVector (PrimState m) a   -- ^ target
                          -> MVector (PrimState m) a   -- ^ source
                          -> m ()
{-# INLINE unsafeCopy #-}
unsafeCopy = G.unsafeCopy

-- Deprecated functions
-- --------------------

-- | /DEPRECATED/ Use 'replicate' instead
newWith :: PrimMonad m => Int -> a -> m (MVector (PrimState m) a)
{-# INLINE newWith #-}
newWith = G.replicate

-- | /DEPRECATED/ Use 'replicate' instead
unsafeNewWith :: PrimMonad m => Int -> a -> m (MVector (PrimState m) a)
{-# INLINE unsafeNewWith #-}
unsafeNewWith = G.replicate

{-# DEPRECATED newWith, unsafeNewWith "Use replicate instead" #-}

