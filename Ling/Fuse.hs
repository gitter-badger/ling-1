{-# LANGUAGE LambdaCase      #-}
{-# LANGUAGE TemplateHaskell #-}
module Ling.Fuse where

import           Ling.Norm
import           Ling.Prelude
import           Ling.Proc
import           Ling.Print
import           Ling.Rename
import           Ling.Scoped
import           Ling.SubTerms
import           Ling.Defs
import           Ling.Session

type Allocation = Term

-- isoPrism :: Prism s t a b -> Iso s t (Either s a) (Either b t)
-- isoPrism p pafb = p pafb

data AllocAnn
  = FusedAnn
  | FuseAnn Int
--  | Alloc
--  | Auto

data Fused =
  Fused { _fusedDefs :: !Defs
        , _fusedActs :: !(Order Act)
        }

instance Dottable Fused where
  Fused defs acts `dotP` proc1 = defs `dotP` acts `dotP` proc1

defaultFusion, autoFusion :: AllocAnn -- [Allocation] -> Maybe [Allocation]
defaultFusion = FusedAnn
autoFusion = defaultFusion

makePrisms ''AllocAnn

instance Monoid AllocAnn where
  mempty = defaultFusion
  FusedAnn `mappend` x = x
--x `mappend` FusedAnn = x
  x `mappend` _        = x

_AllocAnn :: Prism' Allocation AllocAnn
_AllocAnn = prism' con pat where
  con = \case
    FusedAnn  -> mkPrimOp (Name "fused") []
    FuseAnn i -> mkPrimOp (Name "fuse" ) [litTerm . integral # i]
    -- Alloc   -> mkPrimOp (Name "alloc") []
    -- Auto    -> mkPrimOp (Name "auto" ) []
  pat = \case
    Def _ (Name "fused") []  -> Just FusedAnn
    Def _ (Name "fuse" ) [i] -> i ^? litTerm . integral . re _FuseAnn
    Def _ (Name "alloc") []  -> Just (FuseAnn 0) -- TEMPORARY, `alloc` is defined as `fuse 0`
    Def _ (Name "auto" ) []  -> Just autoFusion
    t                        -> trace ("[WARNING]: Unexpected allocation annotation: " ++ ppShow t) Nothing

doFuse :: [Allocation] -> Maybe [Allocation]
doFuse anns =
  case anns ^. each . _AllocAnn of
    FusedAnn  -> Just anns
    FuseAnn i
      | i > 0     -> Just $ anns & each . _AllocAnn . _FuseAnn %~ pred
      | otherwise -> Nothing

type NU = [ChanDec] -> Act

fuseDot :: Defs -> Op2 Proc
fuseDot defs = \case
  Act (Nu anns0 newpatt)
    | anns1 <- reduceP $ Scoped defs ø anns0
    , Just anns2 <- doFuse anns1 ->
    case newpatt of
      NewChans k cs
        | [c, d] <- reduceP . Scoped defs ø <$> cs
        -> fuseProc defs . fuseChanDecs (Nu anns2 . NewChans k) [(c, d)]
      _ -> error . unlines $ [ "Unsupported fusion for " ++ pretty newpatt
                             , "Hint: fusion can be disabled using `new/ alloc` instead of `new`" ]
  proc0@NewSlice{} -> (fuseProc defs proc0 `dotP`) . fuseProc defs
  Act (LetA defs') -> (defs' `dotP`) . fuseProc (defs <> defs')
  proc0 -> (proc0 `dotP`) . fuseProc defs

fuseProc :: Defs -> Endom Proc
fuseProc defs = \case
  proc0 `Dot` proc1 -> fuseDot defs proc0 proc1

  Act act -> fuseDot defs (Act act) ø

  -- go recurse...
  Procs procs -> Procs $ procs & each %~ fuseProc defs
  NewSlice cs t x proc0 -> NewSlice cs t x $ fuseProc defs proc0

fuseChanDecs :: NU -> [(ChanDec,ChanDec)] -> Endom Proc
fuseChanDecs _  []           = id
fuseChanDecs nu ((c0,c1):cs) = fuse2Chans nu c0 c1 . fuseChanDecs nu cs

fuseSendRecv :: NU -> ChanDec -> Term -> ChanDec -> VarDec -> Fused
fuseSendRecv nu c0 e c1 (Arg x mty) = Fused (aDef x mty e) (Order [nu cs])
  where
    cs = [c0,c1] & each . cdSession . _Just . rsession %~ sessionStep {-TODO defs-} (mkVar x)

two :: ([a] -> b) -> a -> a -> b
two f x y = f [x, y]

{-
new[c : {A,B}, d : [~A,~B]]

new[c0 : A, d0 : ~A]
new[c1 : B, d1 : ~B]
-}

type Fuse2 a = NU -> ChanDec -> a -> ChanDec -> a -> Fused

fuse2Pats :: Fuse2 CPatt
fuse2Pats nu _c0 pat0 _c1 pat1
  | Just (_, cs0) <- pat0 ^? _ArrayCs
  , Just (_, cs1) <- pat1 ^? _ArrayCs = Fused ø (Order $ zipWith (two nu) cs0 cs1)
  | otherwise                         = error "Fuse.fuse2Pats unsupported split"

fuse2Acts :: Fuse2 Act
fuse2Acts nu c0 act0 c1 act1 =
  case (act0, act1) of
    (Split _c0 pat0, Split _c1 pat1) -> fuse2Pats nu c0 pat0 c1 pat1
    (Send _d0 _ e, Recv _d1 arg) -> fuseSendRecv nu c0 e c1 arg
    (Recv _d0 arg, Send _d1 _ e) -> fuseSendRecv nu c1 e c0 arg
              -- By typing, (c0,c1) and (d0,d1) should be equal, we could assert that for debugging.
    (Split{}, _)    -> error "fuse2Acts/Split: IMPOSSIBLE `split` should match another `split`"
    (Send{}, _)     -> error "fuse2Acts/Send: IMPOSSIBLE `send` should match `recv`"
    (Recv{}, _)     -> error "fuse2Acts/Recv: IMPOSSIBLE `recv` should match `send`"
    (Nu{}, _)       -> error "fuse2Acts/Nu: IMPOSSIBLE `new` does not consume channels"
    (LetA{}, _)     -> error "fuse2Acts/LetA: IMPOSSIBLE `let` does not consume channels"
    (Ax{}, _)       -> error "fuse2Acts/Ax: should be expanded before"
    (At{}, _)       -> error "fuse2Acts/At: should be expanded before"

fuse2Chans :: NU -> ChanDec -> ChanDec -> Endom Proc
fuse2Chans nu cd0 cd1 p0 =
  case mact0 of
    Nothing -> p0 -- error "fuse2Chans: mact0 is Nothing"
    Just actA ->
      let
        (cdA, cdB) = if setOf freeChans actA ^. hasKey c0 then (cd0, cd1) else (cd1, cd0)
        predB :: Set Channel -> Bool
        predB fc = fc ^. hasKey (cdB ^. cdChan)
        mactB = p0 {- was p1 -} ^? {-scoped .-} fetchActProc predB . _Act
      in
      case mactB of
        Nothing ->
          error $ "fuse2Chans: cannot find " ++ pretty (cdB ^. cdChan) ++ " in " ++ pretty p0
        Just actB ->
          p0 & fetchActProc predA .~ toProc (fuse2Acts nu cdA actA cdB actB)
             & fetchActProc predB .~ ø
  where
    c0 = cd0 ^. cdChan
    c1 = cd1 ^. cdChan
    predA :: Set Channel -> Bool
    predA fc = fc ^. hasKey c0 || fc ^. hasKey c1

    -- TODO fuse into one traversal
    mact0 = p0 ^? {-scoped .-} fetchActProc predA . _Act
    -- p1    = p0 &  {-scoped .-} fetchActProc predA .~ ø

fuseProgram :: Defs -> Endom Program
-- fuseProgram = prgDecs . each . _Sig . _3 . _Just . _Proc . _2 %~ fuseProc
fuseProgram pdefs = transProgramTerms (over (_Proc . _2) . fuseProc . (pdefs <>))
{-
fuse2Chans c0 c1 p0 =
  p0 & partsOf (scoped . procActsChans (l2s [c0,c1])) %~ f

  where f [] = []
        f (act0 : acts)
          | c0 `member` freeChans act0 = g act0 acts c0
          | otherwise              = g act0 acts c1
        g act0 acts cA =
          let (acts0,act1:acts1) = span (member cA . freeChans) acts
              (act0',act1')      = fuse2Acts (act0, act1)
          in act0' : acts0 ++ act1' : acts1
-}
