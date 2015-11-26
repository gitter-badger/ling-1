{-# LANGUAGE LambdaCase      #-}
{-# LANGUAGE TemplateHaskell #-}
module Ling.Raw (module Ling.Abs, module Ling.Raw) where

import           Control.Lens
import           Ling.Abs
import           Ling.Prelude

makePrisms ''Program
makePrisms ''Dec
makePrisms ''Assertion
makePrisms ''ConName
makePrisms ''OptSig
makePrisms ''VarDec
makePrisms ''ChanDec
makePrisms ''Branch
makePrisms ''Literal
makePrisms ''ATerm
makePrisms ''Term
makePrisms ''Proc
makePrisms ''Act
makePrisms ''ASession
makePrisms ''TopCPatt
makePrisms ''CPatt
makePrisms ''OptSession
makePrisms ''RSession
makePrisms ''OptRepl
makePrisms ''CSession

aTerm :: ATerm -> Term
aTerm (Paren t NoSig) = t
aTerm t               = RawApp t []

paren :: Term -> ATerm
paren (RawApp t []) = t
paren t             = Paren t NoSig

pPrll :: [Proc] -> Proc
pPrll = \case
  [p] -> p
  ps  -> PPrll ps

pNxt :: Op2 Proc
pNxt (PPrll []) proc1 = proc1
pNxt proc0 (PPrll []) = proc0
pNxt proc0 proc1      = proc0 `PNxt` proc1

pDot :: Op2 Proc
pDot (PPrll []) proc1 = proc1
pDot proc0 (PPrll []) = proc0
pDot proc0 proc1      = proc0 `PDot` proc1

pDots :: [Proc] -> Proc
pDots = foldr pDot (PPrll [])
