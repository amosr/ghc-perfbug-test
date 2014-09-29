{-# LANGUAGE CPP, MagicHash, ForeignFunctionInterface, NoImplicitPrelude,
             BangPatterns, UnboxedTuples, UnliftedFFITypes #-}


#include "MachDeps.h"

module New1.GHC.Integer.Type
{-
    ( Integer (..)
    , mkInteger, smallInteger, wordToInteger, integerToWord, integerToInt
#if WORD_SIZE_IN_BITS < 64
    , integerToWord64, word64ToInteger
    , integerToInt64, int64ToInteger
#endif
    , plusInteger, minusInteger, timesInteger, negateInteger
    , eqInteger, neqInteger, absInteger, signumInteger
    , leInteger, gtInteger, ltInteger, geInteger, compareInteger
    , divModInteger, quotRemInteger, quotInteger, remInteger
    , encodeFloatInteger, decodeFloatInteger, floatFromInteger
    , encodeDoubleInteger, decodeDoubleInteger, doubleFromInteger
    -- , gcdInteger, lcmInteger -- XXX
    , andInteger, orInteger, xorInteger, complementInteger
    , shiftLInteger, shiftRInteger
    , hashInteger


    , toList, mkLarge

    ) where
-}
    where

import Prelude hiding (Integer, abs, pi, succ) -- (all, error, otherwise, return, show, (++))

import Data.Bits
import Data.Primitive.ByteArray

import GHC.Prim
import GHC.Types
import GHC.Tuple ()
#if WORD_SIZE_IN_BITS < 64
import GHC.IntWord64
#endif

import Common.GHC.Integer.Debug
import Common.GHC.Integer.Loop
import Common.GHC.Integer.Prim
import Common.GHC.Integer.StrictPrim
import New1.GHC.Integer.Array
import New1.GHC.Integer.Sign

#if !defined(__HADDOCK__)

data Integer
    = Small !Sign
        {-# UNPACK #-} !Word
    | Large !Sign
        {-# UNPACK #-} !Int
        {-# UNPACK #-} !ByteArray

--------------------------------------------------------------------------------

mkInteger :: Bool   -- non-negative?
          -> [Int]  -- absolute value in 31 bit chunks, least significant first
                    -- ideally these would be Words rather than Ints, but
                    -- we don't have Word available at the moment.
          -> Integer
mkInteger _ [] = smallInteger 0#
mkInteger True [I# i] = smallInteger i
mkInteger False [I# i] = smallInteger (negateInt# i)
mkInteger nonNegative is =
    let abs = f is
    in if nonNegative
        then abs
        else negateInteger abs
  where
    f [] = smallInteger 0#
    f [I# x] = smallInteger x
    f (I# x : xs) = smallInteger x `orInteger` shiftLInteger (f xs) 31#

{-# NOINLINE smallInteger #-}
smallInteger :: Int# -> Integer
smallInteger i
    | isTrue# (i ==# 0#) = Small Pos 0
    | isTrue# (i <# 0#) = Small Neg (W# (int2Word# (negateInt# i)))
    | otherwise = Small Pos (W# (int2Word# i))

{-# NOINLINE wordToInteger #-}
wordToInteger :: Word# -> Integer
wordToInteger w = Small Pos (W# w)

{-# NOINLINE integerToWord #-}
integerToWord :: Integer -> Word#
integerToWord (Small _ (W# w)) = w
integerToWord (Large _ _ arr) = unboxWord (indexWordArray arr 0)

{-# NOINLINE integerToInt #-}
integerToInt :: Integer -> Int#
integerToInt (Small Pos (W# w)) = word2Int# w
integerToInt (Small Neg (W# w)) = negateInt# (word2Int# w)
integerToInt (Large !s _ arr) =
    let i = word2Int# (unboxWord (indexWordArray arr 0))
    in case s of
        Pos -> i
        Neg -> negateInt# i

#if WORD_SIZE_IN_BITS == 64
-- Nothing
#elif WORD_SIZE_IN_BITS == 32
{-# NOINLINE integerToWord64 #-}
integerToWord64 :: Integer -> Word64#
integerToWord64 = error ("New1/GHC/Integer/Type.hs: line " ++ show (__LINE__ :: Int))

{-# NOINLINE word64ToInteger #-}
word64ToInteger:: Word64# -> Integer
word64ToInteger = error ("New1/GHC/Integer/Type.hs: line " ++ show (__LINE__ :: Int))

{-# NOINLINE integerToInt64 #-}
integerToInt64 :: Integer -> Int64#
integerToInt64 = error ("New1/GHC/Integer/Type.hs: line " ++ show (__LINE__ :: Int))

{-# NOINLINE int64ToInteger #-}
int64ToInteger :: Int64# -> Integer
int64ToInteger = error ("New1/GHC/Integer/Type.hs: line " ++ show (__LINE__ :: Int))
#else
#error WORD_SIZE_IN_BITS not supported
#endif

{-# NOINLINE encodeDoubleInteger #-}
encodeDoubleInteger :: Integer -> Int# -> Double#
encodeDoubleInteger (Small Pos (W# w)) i = encodeDouble# w i
encodeDoubleInteger (Small Neg (W# w)) i = negateDouble# (encodeDouble# w i)

encodeDoubleInteger (Large Pos n arr) i = encodeArrayToDouble n arr i
encodeDoubleInteger (Large Neg n arr) i = negateDouble# (encodeArrayToDouble n arr i)

encodeArrayToDouble :: Int -> ByteArray -> Int# -> Double#
encodeArrayToDouble n arr e0 =
    let (!res, _) = runStrictPrim $ intLoopState 0 (n - 1) (0.0, I# e0) $ \ i (D# d, e) -> do
                        (W# w) <- indexWordArrayM arr i
                        return (D# (d +## encodeDouble# w (unboxInt e)), e + WORD_SIZE_IN_BITS)
    in unboxDouble res

{-# NOINLINE encodeFloatInteger #-}
encodeFloatInteger :: Integer -> Int# -> Float#
encodeFloatInteger = error ("New1/GHC/Integer/Type.hs: line " ++ show (__LINE__ :: Int))

{-# NOINLINE decodeFloatInteger #-}
decodeFloatInteger :: Float# -> (# Integer, Int# #)
decodeFloatInteger = error ("New1/GHC/Integer/Type.hs: line " ++ show (__LINE__ :: Int))

{-# NOINLINE decodeDoubleInteger #-}
decodeDoubleInteger :: Double# -> (# Integer, Int# #)
decodeDoubleInteger d# =
    case decodeDouble_2Int# d# of
        (# isign, mantHigh, mantLow, expn #) ->
            let sign = if isTrue# (isign <# 0#) then Neg else Pos
            in (# Small sign (W# (plusWord# mantLow (uncheckedShiftL# mantHigh 32#))), expn #)


{-# NOINLINE doubleFromInteger #-}
doubleFromInteger :: Integer -> Double#
doubleFromInteger = error ("New1/GHC/Integer/Type.hs: line " ++ show (__LINE__ :: Int))

{-# NOINLINE floatFromInteger #-}
floatFromInteger :: Integer -> Float#
floatFromInteger = error ("New1/GHC/Integer/Type.hs: line " ++ show (__LINE__ :: Int))

{-# NOINLINE andInteger #-}
andInteger :: Integer -> Integer -> Integer
andInteger _ (Small _ 0) = Small Pos 0
andInteger (Small _ 0) _ = Small Pos 0
andInteger (Small Pos a) (Small Pos b) = Small Pos (a .&. b)
andInteger (Small Pos a) (Small Neg b) = Small Pos (a .&. complement (b - 1))
andInteger (Small Neg a) (Small Pos b) = Small Pos (complement (a - 1) .&. b)
andInteger (Small Neg a) (Small Neg b) = Small Neg (1 + ((a - 1) .|. (b - 1)))

andInteger a@(Large _ _ _) b@(Small _ _) = andInteger a (mkLarge b)
andInteger a@(Small _ _) b@(Large _ _ _) = andInteger (mkLarge a) b


andInteger (Large Pos n1 arr1) (Large Pos n2 arr2) = andArray Pos (min n1 n2) arr1 arr2

andInteger _ _ = error ("New1/GHC/Integer/Type.hs: line " ++ show (__LINE__ :: Int))


andArray :: Sign -> Int -> ByteArray -> ByteArray -> Integer
andArray s n arr1 arr2 = runStrictPrim $ do
    !marr <- newWordArray n
    loop marr 0
    !narr <- unsafeFreezeWordArray marr
    finalizeLarge s n narr
  where
    loop !marr !i
        | i < n = do
                !x <- indexWordArrayM arr1 i
                !y <- indexWordArrayM arr2 i
                writeWordArray marr i (x .&. y)
                loop marr (i + 1)
        | otherwise = return ()


{-# NOINLINE orInteger #-}
orInteger :: Integer -> Integer -> Integer
orInteger (Small _ 0) b = b
orInteger a (Small _ 0) = a
orInteger (Small Pos a) (Small Pos b) = Small Pos (a .|. b)
orInteger (Small Pos a) (Small Neg b) = Small Neg (1 + (complement a .&. (b - 1)))
orInteger (Small Neg a) (Small Pos b) = Small Neg (1 + ((a - 1) .&. complement b))
orInteger (Small Neg a) (Small Neg b) = Small Neg (1 + ((a - 1) .&. (b - 1)))

orInteger a@(Large _ _ _) b@(Small _ _) = orInteger a (mkLarge b)
orInteger a@(Small _ _) b@(Large _ _ _) = orInteger (mkLarge a) b

orInteger (Large Pos n1 arr1) (Large Pos n2 arr2) = orArray Pos n1 arr1 n2 arr2

orInteger _ _ = error ("New1/GHC/Integer/Type.hs: line " ++ show (__LINE__ :: Int))



orArray :: Sign -> Int -> ByteArray -> Int -> ByteArray -> Integer
orArray !s !n1 !arr1 !n2 !arr2
    | n1 < n2 = orArray s n2 arr2 n1 arr1
    | otherwise = runStrictPrim $ do
        !marr <- newWordArray n1
        !nlen <- loop1 marr 0
        !narr <- unsafeFreezeWordArray marr
        finalizeLarge s nlen narr
  where
    loop1 !marr !i
        | i < n2 = do
                !x <- indexWordArrayM arr1 i
                !y <- indexWordArrayM arr2 i
                writeWordArray marr i (x .|. y)
                loop1 marr (i + 1)
        | otherwise = loop2 marr i
    loop2 !marr !i
        | i < n1 = do
                -- TODO : Use copyArray here?
                !x <- indexWordArrayM arr1 i
                writeWordArray marr i x
                loop2 marr (i + 1)
        | otherwise = return i

{-# NOINLINE xorInteger #-}
xorInteger :: Integer -> Integer -> Integer
xorInteger a (Small _ 0) = a
xorInteger (Small _ 0) b = b
xorInteger (Large _ n1 arr1) (Large _ n2 arr2) =
    if n1 >= n2
        then xorArray Pos n1 arr1 n2 arr2
        else xorArray Pos n2 arr2 n1 arr1
xorInteger _ _ = error ("New1/GHC/Integer/Type.hs: line " ++ show (__LINE__ :: Int))


xorArray :: Sign -> Int -> ByteArray -> Int -> ByteArray -> Integer
xorArray !s !n1 !arr1 !n2 !arr2 = runStrictPrim $ do
    !marr <- newWordArray n1
    loop1 marr 0
    !narr <- unsafeFreezeWordArray marr
    finalizeLarge s n1 narr
  where
    loop1 !marr !i
        | i < n2 = do
                !x <- indexWordArrayM arr1 i
                !y <- indexWordArrayM arr2 i
                writeWordArray marr i (xor x y)
                loop1 marr (i + 1)
        | otherwise = loop2 marr i
    loop2 !marr !i
        | i < n1 = do
                -- TODO : Use copyArray here?
                !x <- indexWordArrayM arr1 i
                writeWordArray marr i x
                loop2 marr (i + 1)
        | otherwise = return ()

{-# NOINLINE complementInteger #-}
complementInteger :: Integer -> Integer
complementInteger !(Small Pos !a) = Small Neg (a + 1)
complementInteger !(Small Neg !a) = Small Pos (a - 1)
complementInteger !(Large Pos !n !arr) = plusArrayW Neg n arr 1
complementInteger !(Large Neg !n !arr) = minusArrayW Pos n arr 1


{-# NOINLINE shiftLInteger #-}
shiftLInteger :: Integer -> Int# -> Integer
shiftLInteger a 0# = a
shiftLInteger (Small _ 0) _ = (Small Pos 0)
shiftLInteger a@(Small {}) b = shiftLInteger (mkLarge a) b
shiftLInteger (Large !s !n !arr) b = shiftLArray s n arr (I# b)


{-# NOINLINE shiftRInteger #-}
shiftRInteger :: Integer -> Int# -> Integer
shiftRInteger a 0# = a
shiftRInteger (Small _ 0) _ = (Small Pos 0)
shiftRInteger (Small Pos a) b = Small Pos (a `shiftR` (I# b))
shiftRInteger (Large Pos n arr) b = shiftRArray Pos n arr (I# b)
shiftRInteger (Small Neg a) b = Small Neg (((a - 1) `shiftR` (I# b)) + 1)
shiftRInteger (Large Neg n arr) b =
    case minusArrayW Pos n arr 1 of
        Small _ _ -> Small Neg 42
        Large _ !n1 !arr1 ->
            case shiftRArray Pos n1 arr1 (I# b) of
                Small _ a2 -> Small Neg (a2 + 1)
                Large _ !n2 !arr2 -> plusArrayW Neg n2 arr2 1


{-# NOINLINE negateInteger #-}
negateInteger :: Integer -> Integer
negateInteger (Small !s !a) = Small (negateSign s) a
negateInteger (Large !s !n !arr) = Large (negateSign s) n arr

{-# NOINLINE plusInteger #-}
plusInteger :: Integer -> Integer -> Integer
plusInteger !x !y =
    case (# x, y #) of
        (# Small _ 0, b #) -> b
        (# Small Pos !w1, Small Pos !w2 #) -> safePlusWord Pos w1 w2
        (# Small Pos !a, Small Neg !b #) ->
            if a >= b
                then Small Pos (a - b)
                else Small Neg (b - a)
        (# Small Neg a, Small Pos b #) ->
            if a >= b
                then Small Neg (a - b)
                else Small Pos (b - a)
        (# Small Neg !w1, Small Neg !w2 #) -> safePlusWord Neg w1 w2

        (# Large Pos !n !arr, Small Pos !w #) -> plusArrayW Pos n arr w
        (# Small Pos !w, Large Pos !n !arr #) -> plusArrayW Pos n arr w

        (# Large Neg !n !arr, Small Neg !w #) -> plusArrayW Neg n arr w
        (# Small Neg !w, Large Neg !n !arr #) -> plusArrayW Neg n arr w

        (# Large Pos !n !arr, Small Neg !w #) -> minusArrayW Pos n arr w
        (# Small Neg !w, Large Pos !n !arr #) -> minusArrayW Pos n arr w

        (# Small Pos !w, Large Neg !n !arr #) -> minusArrayW Neg n arr w
        (# Large Neg !n !arr, Small Pos !w #) -> minusArrayW Neg n arr w

        (# Large Pos !n1 !arr1, Large Pos !n2 !arr2 #) -> plusArray Pos n1 arr1 n2 arr2
        (# Large Pos !n1 !arr1, Large Neg !n2 !arr2 #) ->
            if gtArray n1 arr1 n2 arr2
                then minusArray Pos n1 arr1 n2 arr2
                else minusArray Neg n2 arr2 n1 arr1
        (# Large Neg !n1 !arr1, Large Pos !n2 !arr2 #) ->
            if gtArray n1 arr1 n2 arr2
                then minusArray Neg n1 arr1 n2 arr2
                else minusArray Pos n2 arr2 n1 arr1
        (# Large Neg !n1 !arr1, Large Neg !n2 !arr2 #) -> plusArray Neg n1 arr1 n2 arr2

{-# INLINE safePlusWord #-}
safePlusWord :: Sign -> Word -> Word -> Integer
safePlusWord !sign !w1 !w2 =
    let (# !c, !s #) = plusWord2 w1 w2
    in if c == 0
        then Small sign s
        else mkPair sign s c

plusArrayW :: Sign -> Int -> ByteArray -> Word -> Integer
plusArrayW !s !n !arr !w = runStrictPrim $ do
    !marr <- newWordArray (n + 1)
    writeWordArray marr n 0
    !x <- indexWordArrayM arr 0
    let (# !cry, !sm #) = plusWord2 x w
    writeWordArray marr 0 sm
    !nlen <- loop1 marr 1 cry
    !narr <- unsafeFreezeWordArray marr
    finalizeLarge s nlen narr
  where
    loop1 !marr !i !carry
        | carry == 0 = loop2 marr i
        | i < n =  do
            !x <- indexWordArrayM arr i
            let (# !cry, !sm #) = plusWord2 x carry
            writeWordArray marr i sm
            loop1 marr (i + 1) cry
        | otherwise = do
            writeWordArray marr i carry
            return $ n + 1
    loop2 !marr !i
        | i < n =  do
            !x <- indexWordArrayM arr i
            writeWordArray marr i x
            loop2 marr (i + 1)
        | otherwise = return n


plusArray :: Sign -> Int -> ByteArray -> Int -> ByteArray -> Integer
plusArray !s !n1 !arr1 !n2 !arr2
    | n1 < n2 = plusArray s n2 arr2 n1 arr1
    | otherwise = runStrictPrim $ do
        marr <- newWordArray (n1 + 1)
        nlen <- loop1 marr 0 0
        narr <- unsafeFreezeWordArray marr
        finalizeLarge s nlen narr
  where
    loop1 !marr !i !carry
        | i < n2 = do
            x <- indexWordArrayM arr1 i
            y <- indexWordArrayM arr2 i
            let (# !cry, !sm #) = plusWord2C x y carry
            writeWordArray marr i sm
            loop1 marr (i + 1) cry
        | otherwise = loop2 marr i carry
    loop2 !marr !i !carry
        | carry == 0 = loop3 marr i
        | i < n1 = do
            x <- indexWordArrayM arr1 i
            let (# !cry, !sm #) = plusWord2 x carry
            writeWordArray marr i sm
            loop2 marr (i + 1) cry
        | otherwise = do
            writeWordArray marr i carry
            return (i + 1)
    loop3 !marr !i
        | i < n1 = do
            x <- indexWordArrayM arr1 i
            writeWordArray marr i x
            loop3 marr (i + 1)
        | otherwise = return i


{-# NOINLINE minusInteger #-}
minusInteger :: Integer -> Integer -> Integer
minusInteger a (Small _ 0) = a
minusInteger (Small _ 0) b = negateInteger b

minusInteger (Small Pos a) (Small Pos b)
    | a >= b = Small Pos (a - b)
    | otherwise = Small Neg (b - a)
minusInteger (Small Pos a) (Small Neg b) = safePlusWord Pos a b
minusInteger (Small Neg a) (Small Pos b) = safePlusWord Neg a b
minusInteger (Small Neg a) (Small Neg b)
    | a > b = Small Neg (a - b)
    | otherwise = Small Pos (b - a)
minusInteger (Small Neg w) (Large Pos n arr) = plusArrayW Neg n arr w
minusInteger (Small Pos w) (Large Pos n arr) = minusArrayW Neg n arr w

minusInteger (Large Pos n arr) (Small Neg w) = plusArrayW Pos n arr w


minusInteger (Large Pos n arr) (Small Pos w) = minusArrayW Pos n arr w


minusInteger (Large Neg n arr) (Small Pos w) = plusArrayW Neg n arr w
minusInteger (Small Pos w) (Large Neg n arr) = plusArrayW Pos n arr w

minusInteger (Large Neg n arr) (Small Neg w) = minusArrayW Neg n arr w
minusInteger (Small Neg w) (Large Neg n arr) = minusArrayW Pos n arr w


minusInteger (Large Pos n1 arr1) (Large Pos n2 arr2)
    | gtArray n1 arr1 n2 arr2 = minusArray Pos n1 arr1 n2 arr2
    | otherwise = minusArray Neg n2 arr2 n1 arr1

minusInteger (Large Neg n1 arr1) (Large Neg n2 arr2)
    | gtArray n1 arr1 n2 arr2 = minusArray Neg n1 arr1 n2 arr2
    | otherwise = minusArray Pos n2 arr2 n1 arr1

minusInteger (Large Neg n1 arr1) (Large Pos n2 arr2) = plusArray Neg n1 arr1 n2 arr2
minusInteger (Large Pos n1 arr1) (Large Neg n2 arr2) = plusArray Pos n1 arr1 n2 arr2


minusArrayW :: Sign -> Int -> ByteArray -> Word -> Integer
minusArrayW  !s !n !arr !w = runStrictPrim $ do
    !marr <- newWordArray (n + 1)
    writeWordArray marr n 0
    !x <- indexWordArrayM arr 0
    let (# !c, !d #) = minusWord2 x w
    writeWordArray marr 0 d
    !nlen <- loop1 marr 1 c
    !narr <- unsafeFreezeWordArray marr
    finalizeLarge s nlen narr
  where
    loop1 !marr !i !carry
        | carry == 0 = loop2 marr i
        | i < n =  do
            !x <- indexWordArrayM arr i
            let (# !c, !d #) = minusWord2 x carry
            writeWordArray marr i d
            loop1 marr (i + 1) c
        | otherwise = do
            writeWordArray marr i carry
            return $ n + 1
    loop2 !marr !i
        | i < n =  do
            !x <- indexWordArrayM arr i
            writeWordArray marr i x
            loop2 marr (i + 1)
        | otherwise = return n


minusArray :: Sign -> Int -> ByteArray -> Int -> ByteArray -> Integer
minusArray !s !n1 !arr1 !n2 !arr2
    | n1 < n2 = plusArray s n2 arr2 n1 arr1
    | otherwise = runStrictPrim $ do --
        !marr <- newWordArray (n1 + 1)
        !nlen <- loop1 marr 0 0
        !narr <- unsafeFreezeWordArray marr
        finalizeLarge s nlen narr
  where
    loop1 !marr !i !carry
        | i < n2 = do
            !x <- indexWordArrayM arr1 i
            !y <- indexWordArrayM arr2 i
            let (# !c, !d #) = minusWord2C x y carry
            writeWordArray marr i d
            loop1 marr (i + 1) c
        | otherwise = loop2 marr i carry
    loop2 !marr !i !carry
        | carry == 0 = loop3 marr i
        | i < n1 = do
            !x <- indexWordArrayM arr1 i
            let (# !c, !d #) = minusWord2 x carry
            writeWordArray marr i d
            loop2 marr (i + 1) c
        | otherwise = do
            writeWordArray marr i carry
            return (i + 1)
    loop3 !marr !i
        | i < n1 = do
            !x <- indexWordArrayM arr1 i
            writeWordArray marr i x
            loop3 marr (i + 1)
        | otherwise = return i

{-# NOINLINE timesInteger #-}
timesInteger :: Integer -> Integer -> Integer
timesInteger !x !y = case (# x, y #) of
    (# Small _ _, Small _ 0 #) -> Small Pos 0
    (# Small _ 0, Small _ _ #) -> Small Pos 0
    (# !a, Small Pos 1 #) -> a
    (# Small Pos 1, !b #) -> b

    (# Small !s1 !w1, Small !s2 !w2 #) ->
            safeTimesWord (timesSign s1 s2) w1 w2

    (# Small !s1 !w1, Large !s2 !n2 !arr2 #) ->
            timesArrayW (timesSign s1 s2) n2 arr2 w1

    (# Large !s1 !n1 !arr1, Small !s2 !w2 #) ->
            timesArrayW (timesSign s1 s2) n1 arr1 w2

    (# Large !s1 !n1 !arr1, Large !s2 !n2 !arr2 #) ->
            timesArray (timesSign s1 s2) n1 arr1 n2 arr2

{-# INLINE safeTimesWord #-}
safeTimesWord :: Sign -> Word -> Word -> Integer
safeTimesWord !s !w1 !w2 =
    let (# !ovf, !prod #) = timesWord2 w1 w2
    in if ovf == 0
        then Small s prod
        else mkPair s prod ovf

timesArrayW :: Sign -> Int -> ByteArray -> Word -> Integer
timesArrayW !s !n !arr !w = runStrictPrim $ do
    !marr <- newWordArrayCleared (n + 1)
    writeWordArray marr (n - 1) 0
    loop marr 0 0
    !narr <- unsafeFreezeWordArray marr
    finalizeLarge s (n + 1) narr
  where
    loop !marr !i !carry
        | i < n = do
            !x <- indexWordArrayM arr i
            let (# !c, !p #) = timesWord2C x w carry
            writeWordArray marr i p
            loop marr (i + 1) c
        | otherwise =
            writeWordArray marr i carry


timesArray :: Sign -> Int -> ByteArray -> Int -> ByteArray -> Integer
timesArray !s !n1 !arr1 !n2 !arr2
    | n1 < n2 = timesArray s n2 arr2 n1 arr1
    | otherwise = runStrictPrim $ do
        !psum <- newPlaceholderWordArray
        outerLoop 0 psum 0
  where
    outerLoop !psumLen !psum !s2
        | s2 < n2 = do
            !w <- indexWordArrayM arr2 s2
            if w == 0
                then outerLoop psumLen psum (s2 + 1)
                else do
                    let !newPsumLen = (max psumLen (n1 + s2 + 1)) + 1
                    !marr <- cloneWordArrayExtend psumLen psum newPsumLen
                    !possLen <- innerLoop marr psumLen psum 0 s2 w 0
                    !narr <- unsafeFreezeWordArray marr
                    outerLoop possLen narr (s2 + 1)
        | otherwise =
            finalizeLarge s psumLen psum

    innerLoop !marr !pn !psum !s1 !s2 !hw !carry
        | s1 + s2 < pn && s1 < n1 = do
            !ps <- indexWordArrayM psum (s1 + s2)
            !x <- indexWordArrayM arr1 s1
            let (# !hc, !hp #) = timesWord2CC x hw carry ps
            writeWordArray marr (s1 + s2) hp
            innerLoop marr pn psum (s1 + 1) s2 hw hc
        | s1 < n1 = do
            !x <- indexWordArrayM arr1 s1
            let (# !hc, !hp #) = timesWord2C x hw carry
            writeWordArray marr (s1 + s2) hp
            innerLoop marr pn psum (s1 + 1) s2 hw hc
        | carry /= 0 = do
            writeWordArray marr (s1 + s2) carry
            return (s1 + s2 + 1)
        | otherwise = return (s1 + s2 + 1)

{-# NOINLINE divModInteger #-}
divModInteger :: Integer -> Integer -> (# Integer, Integer #)
divModInteger _ _ = error ("New1/GHC/Integer/Type.hs: line " ++ show (__LINE__ :: Int))

{-# NOINLINE quotRemInteger #-}
quotRemInteger :: Integer -> Integer -> (# Integer, Integer #)
quotRemInteger _ _ = error ("New1/GHC/Integer/Type.hs: line " ++ show (__LINE__ :: Int))

{-# NOINLINE quotInteger #-}
quotInteger :: Integer -> Integer -> Integer
quotInteger a b =
    let (# q, _ #) = quotRemInteger a b
    in q

{-# NOINLINE remInteger #-}
remInteger :: Integer -> Integer -> Integer
remInteger = error ("New1/GHC/Integer/Type.hs: line " ++ show (__LINE__ :: Int))

{-# NOINLINE compareInteger #-}
compareInteger :: Integer -> Integer -> Ordering
compareInteger = error ("New1/GHC/Integer/Type.hs: line " ++ show (__LINE__ :: Int))

{-# NOINLINE eqInteger #-}
eqInteger :: Integer -> Integer -> Bool
eqInteger (Small Pos a) (Small Pos b) = a == b
eqInteger (Small Neg a) (Small Neg b) = a == b
eqInteger (Small Pos _) (Small Neg _) = False
eqInteger (Small Neg _) (Small Pos _) = False

eqInteger (Small Pos _) (Large Pos _ _) = False
eqInteger (Small Pos _) (Large Neg _ _) = False
eqInteger (Small Neg _) (Large Pos _ _) = False
eqInteger (Small Neg _) (Large Neg _ _) = False

eqInteger (Large Pos _ _) (Small Pos _) = False
eqInteger (Large Pos _ _) (Small Neg _) = False
eqInteger (Large Neg _ _) (Small Pos _) = False
eqInteger (Large Neg _ _) (Small Neg _) = False

eqInteger (Large Pos _ _) (Large Neg _ _) = False
eqInteger (Large Neg _ _) (Large Pos _ _) = False

eqInteger (Large s1 n1 arr1) (Large s2 n2 arr2)
    | s1 /= s2 = False
    | otherwise = eqArray 0 0
  where
    eqArray i1 i2
        | i1 >= n1 && i2 >= n2 = True
        | i1 < n1 && i2 >= n2 = False
        | i1 >= n1 && i2 < n2 = False
        | indexWordArray arr1 i1 /= indexWordArray arr2 i1 = False
        | otherwise = eqArray (i1 + 1) (i2 + 1)

{-# NOINLINE neqInteger #-}
neqInteger :: Integer -> Integer -> Bool
neqInteger a b = not (eqInteger a b)

instance  Eq Integer  where
    (==) = eqInteger
    (/=) = neqInteger

{-# NOINLINE ltInteger #-}
ltInteger :: Integer -> Integer -> Bool
ltInteger (Small Pos a) (Small Pos b) = a < b
ltInteger (Small Pos _) (Small Neg _) = False
ltInteger (Small Neg _) (Small Pos _) = True
ltInteger (Small Neg a) (Small Neg b) = a > b
ltInteger a@(Small {}) b = geInteger b (mkLarge a)
ltInteger a b@(Small {}) = ltInteger a (mkLarge b)
ltInteger (Large s1 n1 arr1) (Large s2 n2 arr2)
    | s1 /= s2 = s1 < s2
    | s1 == Pos = ltArray n1 arr1 n2 arr2
    | otherwise = ltArray n2 arr2 n1 arr1

ltArray :: Int -> ByteArray -> Int -> ByteArray -> Bool
ltArray !n1 !arr1 !n2 !arr2
    | n1 == n2 =
            let check 0 = indexWordArray arr1 0 < indexWordArray arr2 0
                check i =
                    if indexWordArray arr1 i == indexWordArray arr2 i
                        then check (i - 1)
                        else indexWordArray arr1 i < indexWordArray arr2 i
            in check (n1 - 1)
    | n1 > n2 = False
    | n1 < n2 = True
    | otherwise = False


{-# NOINLINE gtInteger #-}
gtInteger :: Integer -> Integer -> Bool
gtInteger (Small Pos a) (Small Pos b) = a > b
gtInteger (Small Pos _) (Small Neg _) = True
gtInteger (Small Neg _) (Small Pos _) = False
gtInteger (Small Neg a) (Small Neg b) = a < b
gtInteger a@(Small {}) b = leInteger b (mkLarge a)
gtInteger a b@(Small {}) = gtInteger a (mkLarge b)
gtInteger (Large !s1 !n1 !arr1) (Large !s2 !n2 !arr2)
    | s1 /= s2 = s1 > s2
    | s1 == Pos = gtArray n1 arr1 n2 arr2
    | otherwise = gtArray n2 arr2 n1 arr1


gtArray :: Int -> ByteArray -> Int -> ByteArray -> Bool
gtArray !n1 !arr1 !n2 !arr2
    | n1 == n2 =
            let check 0 = indexWordArray arr1 0 > indexWordArray arr2 0
                check i =
                    if indexWordArray arr1 i == indexWordArray arr2 i
                        then check (i - 1)
                        else indexWordArray arr1 i > indexWordArray arr2 i
            in check (n1 - 1)
    | n1 > n2 = True
    | n1 < n2 = False
    | otherwise = False

{-# NOINLINE leInteger #-}
leInteger :: Integer -> Integer -> Bool
leInteger a b = not (gtInteger a b)

{-# NOINLINE geInteger #-}
geInteger :: Integer -> Integer -> Bool
geInteger a b = not (ltInteger a b)

instance Ord Integer where
    (<=) = leInteger
    (>)  = gtInteger
    (<)  = ltInteger
    (>=) = geInteger
    compare = compareInteger

{-# NOINLINE absInteger #-}
absInteger :: Integer -> Integer
absInteger (Small Neg a) = Small Pos a
absInteger (Large Neg n arr) = Large Pos n arr
absInteger a = a

{-# NOINLINE signumInteger #-}
signumInteger :: Integer -> Integer
signumInteger = error ("New1/GHC/Integer/Type.hs: line " ++ show (__LINE__ :: Int))

{-# NOINLINE hashInteger #-}
hashInteger :: Integer -> Int#
hashInteger = integerToInt

--------------------------------------------------------------------------------
-- Helpers (not part of the API).

mkLarge :: Integer -> Integer
mkLarge (Small Pos w) = mkSingletonArray Pos w
mkLarge (Small Neg w) = mkSingletonArray Neg w
mkLarge a = a

mkPair :: Sign -> Word -> Word -> Integer
mkPair !sign !lo !hi = runStrictPrim mkLargePair
  where
    mkLargePair :: StrictPrim s Integer
    mkLargePair = do
        !marr <- newWordArray 2
        writeWordArray marr 0 lo
        writeWordArray marr 1 hi
        !narr <- unsafeFreezeWordArray marr
        return $ Large sign 2 narr

mkSingletonArray :: Sign -> Word -> Integer
mkSingletonArray !s !x = runStrictPrim mkSingleton
  where
    mkSingleton :: StrictPrim s Integer
    mkSingleton = do
        !marr <- newWordArray 1
        writeWordArray marr 0 x
        !narr <- unsafeFreezeWordArray marr
        return $ Large s 1 narr

shiftLArray :: Sign -> Int -> ByteArray -> Int -> Integer
shiftLArray !s !n !arr !i
    | i < WORD_SIZE_IN_BITS =
            smallShiftLArray s n arr (# i, WORD_SIZE_IN_BITS - i #)
    | otherwise = do
            let (!q, !r) = quotRem i WORD_SIZE_IN_BITS
            if r == 0
                then wordShiftLArray s n arr q
                else largeShiftLArray s n arr (# q, r, WORD_SIZE_IN_BITS - r #)

smallShiftLArray :: Sign -> Int -> ByteArray -> (# Int, Int #) -> Integer
smallShiftLArray !s !n !arr (# !si, !sj #) = runStrictPrim $ do
    !marr <- newWordArray (n + 1)
    !nlen <- loop marr 0 0
    !narr <- unsafeFreezeWordArray marr
    finalizeLarge s nlen narr
  where
    loop !marr !i !mem
        | i < n =  do
            !x <- indexWordArrayM arr i
            writeWordArray marr i ((unsafeShiftL x si) .|. mem)
            loop marr (i + 1) (unsafeShiftR x sj)
        | mem /= 0 = do
            writeWordArray marr i mem
            return $ i + 1
        | otherwise = return n

-- | TODO : Use copy here
wordShiftLArray :: Sign -> Int -> ByteArray -> Int -> Integer
wordShiftLArray !s !n !arr !q = runStrictPrim $ do
    !marr <- newWordArray (n + q)
    loop1 marr 0
    !narr <- unsafeFreezeWordArray marr
    finalizeLarge s (n + q) narr
  where
    loop1 !marr !i
        | i < q = do
            writeWordArray marr i 0
            loop1 marr (i + 1)
        | otherwise = loop2 marr 0
    loop2 !marr !i
        | i < n =  do
            !x <- indexWordArrayM arr i
            writeWordArray marr (q + i) x
            loop2 marr (i + 1)
        | otherwise = return ()


largeShiftLArray :: Sign -> Int -> ByteArray-> (# Int, Int, Int #) -> Integer
largeShiftLArray !s !n !arr (# !q, !si, !sj #) = runStrictPrim $ do
    !marr <- newWordArray (n + q + 1)
    setWordArray marr 0 q 0
    loop2 marr 0 0
    !narr <- unsafeFreezeWordArray marr
    finalizeLarge s (n + q + 1) narr
  where
    loop2 !marr !i !mem
        | i < n =  do
            !x <- indexWordArrayM arr i
            writeWordArray marr (q + i) ((unsafeShiftL x si) .|. mem)
            loop2 marr (i + 1) (unsafeShiftR x sj)
        | mem /= 0 = do
            writeWordArray marr (q + i) mem
        | otherwise =
            writeWordArray marr (q + i) 0


shiftRArray :: Sign -> Int -> ByteArray -> Int -> Integer
shiftRArray !s !n !arr !i
    | i < WORD_SIZE_IN_BITS =
            smallShiftRArray s n arr (# i, WORD_SIZE_IN_BITS - i #)
    | otherwise = do
            let (!q, !r) = quotRem i WORD_SIZE_IN_BITS
            if q >= n
                then Small Pos 0
                else if r == 0
                    then wordShiftRArray s n arr q
                    else largeShiftRArray s n arr (# q, r, WORD_SIZE_IN_BITS - r #)


smallShiftRArray :: Sign -> Int -> ByteArray -> (# Int, Int #) -> Integer
smallShiftRArray !s !n !arr (# !si, !sj #) = runStrictPrim $ do
    !marr <- newWordArray n
    loop marr (n - 1) 0
    !narr <- unsafeFreezeWordArray marr
    finalizeLarge s n narr
  where
    loop !marr !i !mem
        | i >= 0 =  do
            !x <- indexWordArrayM arr i
            writeWordArray marr i ((unsafeShiftR x si) .|. mem)
            loop marr (i - 1) (unsafeShiftL x sj)
        | otherwise = return ()

wordShiftRArray :: Sign -> Int -> ByteArray -> Int -> Integer
wordShiftRArray !s !n !arr !q = runStrictPrim $ do
    !marr <- newWordArray (n - q)
    copyWordArray marr 0 arr q (n - q)
    !narr <- unsafeFreezeWordArray marr
    finalizeLarge s (n - q) narr


largeShiftRArray :: Sign -> Int -> ByteArray-> (# Int, Int, Int #) -> Integer
largeShiftRArray !s !n !arr (# !q, !si, !sj #) = runStrictPrim $ do
    !marr <- newWordArray (n - q)
    loop marr (n - q - 1) 0
    !narr <- unsafeFreezeWordArray marr
    finalizeLarge s (n - q) narr
  where
    loop !marr !i !mem
        | i >= 0 =  do
            !x <- indexWordArrayM arr (q + i)
            writeWordArray marr i ((unsafeShiftR x si) .|. mem)
            loop marr (i - 1) (unsafeShiftL x sj)
        | otherwise = return ()


finalizeLarge :: Sign -> Int -> ByteArray -> StrictPrim s Integer
finalizeLarge !s !nin !arr = do
    let !len = nonZeroLen nin arr
    !x <-indexWordArrayM arr 0
    return $
        if len <= 0 || (len == 1 && x == 0)
            then Small Pos 0
            else if len == 1
                then Small s x
                else Large s len arr

nonZeroLen :: Int -> ByteArray -> Int
nonZeroLen !len !arr
    | len < 1 = 0
    | otherwise =
        let trim i
                | i < 0 = 0
                | indexWordArray arr i == 0 = trim (i - 1)
                | otherwise = i + 1
        in trim (len - 1)


oneInteger, minusOneInteger :: Integer
oneInteger = Small Pos 1
minusOneInteger = Small Neg 1

{-

twoToTheThirtytwoInteger :: Integer
twoToTheThirtytwoInteger = error ("New1/GHC/Integer/Type.hs: line " ++ show (__LINE__ :: Int))
-}


toList :: Integer -> [Word]
toList (Small Pos w) = [w]
toList (Small Neg w) = [w]
toList (Large _ n arr) =
    unpackArray 0
  where
    unpackArray i
        | i < n = do
                let xs = unpackArray (i + 1)
                    x = indexWordArray arr i
                x : xs
        | otherwise = []

arrayShow :: Int -> ByteArray -> String
arrayShow !len !arr =
    let hexify w =
            let x = showHexW w
            in replicate (16 - length x) '0' ++ x
        digits = dropWhile (== '0') . concatMap hexify . reverse $ unpackArray 0
    in if null digits then "0x0" else "0x" ++ digits
  where
    unpackArray i
        | i < len = do
                let xs = unpackArray (i + 1)
                    x = indexWordArray arr i
                x : xs
        | otherwise = []

absInt :: Int -> Int
absInt x = if x < 0 then -x else x


isMinimal :: Integer -> Bool
isMinimal i =
    case i of
        Small _ _ -> True
        Large _ n arr -> indexWordArray arr (n - 1) /= 0


#endif
