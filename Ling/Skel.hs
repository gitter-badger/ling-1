module Ling.Skel where

-- Haskell module generated by the BNF converter

import Ling.Abs
import Ling.ErrM
type Result = Err String

failure :: Show a => a -> Result
failure x = Bad $ "Undefined case: " ++ show x

transName :: Name -> Result
transName x = case x of
  Name string -> failure x
transProgram :: Program -> Result
transProgram x = case x of
  Prg decs -> failure x
transDec :: Dec -> Result
transDec x = case x of
  DDef name optsig term -> failure x
  DSig name term -> failure x
  DDat name connames -> failure x
transConName :: ConName -> Result
transConName x = case x of
  CN name -> failure x
transOptSig :: OptSig -> Result
transOptSig x = case x of
  NoSig -> failure x
  SoSig term -> failure x
transVarDec :: VarDec -> Result
transVarDec x = case x of
  VD name term -> failure x
transChanDec :: ChanDec -> Result
transChanDec x = case x of
  CD name optsession -> failure x
transBranch :: Branch -> Result
transBranch x = case x of
  Br conname term -> failure x
transLiteral :: Literal -> Result
transLiteral x = case x of
  LInteger integer -> failure x
  LDouble double -> failure x
  LString string -> failure x
  LChar char -> failure x
transATerm :: ATerm -> Result
transATerm x = case x of
  Var name -> failure x
  Lit literal -> failure x
  Con conname -> failure x
  TTyp -> failure x
  TProto rsessions -> failure x
  Paren term -> failure x
transDTerm :: DTerm -> Result
transDTerm x = case x of
  DTTyp name aterms -> failure x
  DTBnd name term -> failure x
transTerm :: Term -> Result
transTerm x = case x of
  RawApp aterm aterms -> failure x
  Case term branchs -> failure x
  TFun vardec vardecs term -> failure x
  TSig vardec vardecs term -> failure x
  Lam vardec vardecs term -> failure x
  TProc chandecs proc -> failure x
transProc :: Proc -> Result
transProc x = case x of
  Act prefs procs -> failure x
transProcs :: Procs -> Result
transProcs x = case x of
  ZeroP -> failure x
  Prll procs -> failure x
transPref :: Pref -> Result
transPref x = case x of
  Nu chandec1 chandec2 -> failure x
  ParSplit name chandecs -> failure x
  TenSplit name chandecs -> failure x
  SeqSplit name chandecs -> failure x
  Send name aterm -> failure x
  Recv name vardec -> failure x
  NewSlice names aterm name -> failure x
  Ax session names -> failure x
  SplitAx integer session name -> failure x
  At aterm names -> failure x
transOptSession :: OptSession -> Result
transOptSession x = case x of
  NoSession -> failure x
  SoSession rsession -> failure x
transSession :: Session -> Result
transSession x = case x of
  Atm name -> failure x
  End -> failure x
  Par rsessions -> failure x
  Ten rsessions -> failure x
  Seq rsessions -> failure x
  Sort aterm1 aterm2 -> failure x
  Log session -> failure x
  Fwd integer session -> failure x
  Snd dterm csession -> failure x
  Rcv dterm csession -> failure x
  Dual session -> failure x
  Loli session1 session2 -> failure x
transRSession :: RSession -> Result
transRSession x = case x of
  Repl session optrepl -> failure x
transOptRepl :: OptRepl -> Result
transOptRepl x = case x of
  One -> failure x
  Some aterm -> failure x
transCSession :: CSession -> Result
transCSession x = case x of
  Cont session -> failure x
  Done -> failure x

