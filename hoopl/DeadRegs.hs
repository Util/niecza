{-# OPTIONS_GHC -Wall -fno-warn-name-shadowing #-}
{-# LANGUAGE ScopedTypeVariables, GADTs, NoMonomorphismRestriction,ViewPatterns #-}
module DeadRegs (deadRegsPass,deadRegsInitFact) where
import Data.Maybe (mapMaybe)
--import Debug.Trace


--import Control.Monad
import Insn
import qualified Data.Set as S

import Compiler.Hoopl
import Util
--import IR
--import OptSupport

-- DeadRegsFact:
-- The set of registers alive at that point
type DeadRegsFact = S.Set Reg


deadRegsInitFact :: S.Set Reg
deadRegsInitFact = S.empty

deadRegsLattice :: DataflowLattice DeadRegsFact
deadRegsLattice = DataflowLattice
 { fact_name = "DeadRegs"
 , fact_bot  = S.empty
 , fact_join = add } where
 add _ (OldFact old) (NewFact new) = (ch,j)
    where 
        j = new `S.union` old
        ch = changeIf (S.size j > S.size old)


usedRegs :: BwdTransfer Insn DeadRegsFact
usedRegs = mkBTransfer3 hack1 ft hack2
 where
  ft :: Insn O O -> DeadRegsFact ->  DeadRegsFact
  ft (Op _ op) f = S.union f (S.fromList $ mapMaybe regID $ exprs op)
  hack1 _ f = f

--  hack2 :: Insn O C -> FactBase a -> a
--  joinFacts lat l (successorFacts n f)
  hack2 node factBase = joinOutFacts deadRegsLattice node factBase
  regID (Reg r) = Just r
  regID _ = Nothing



-- for debugging debugBwdTransfers trace show (\_ _ -> True) $  
deadRegsPass :: BwdPass M Insn DeadRegsFact
deadRegsPass = BwdPass
  { bp_lattice  = deadRegsLattice
  , bp_transfer = usedRegs
  , bp_rewrite  = removeNoop}


removeNoop :: FuelMonad m => BwdRewrite m Insn DeadRegsFact
removeNoop = mkBRewrite s
 where
    s :: (Monad m) => Insn e x -> Fact x DeadRegsFact -> m (Maybe (Graph Insn e x))
    s (Op r (RegSet _)) live =
            if (S.member r live) then return $ Nothing
            else return $ Just emptyGraph
    s _ _ = return $ Nothing


