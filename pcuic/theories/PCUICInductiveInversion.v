(* Distributed under the terms of the MIT license.   *)
Set Warnings "-notation-overridden".

Require Import Equations.Prop.DepElim.
From Coq Require Import Bool String List Lia Arith.
From MetaCoq.Template Require Import config utils.
From MetaCoq.PCUIC Require Import PCUICAst PCUICAstUtils
     PCUICLiftSubst PCUICUnivSubst PCUICTyping PCUICWeakeningEnv PCUICWeakening
     PCUICSubstitution PCUICClosed PCUICCumulativity PCUICGeneration PCUICReduction
     PCUICEquality PCUICConfluence PCUICParallelReductionConfluence
     PCUICContextConversion PCUICUnivSubstitution
     PCUICConversion PCUICInversion PCUICContexts PCUICArities
     PCUICParallelReduction PCUICCtxShape PCUICSpine PCUICInductives PCUICValidity.
     
Close Scope string_scope.

Require Import ssreflect. 

Set Asymmetric Patterns.
Set SimplIsCbn.

From Equations Require Import Equations.

(* TODO Move *)
Definition expand_lets_k Γ k t := 
  (subst (extended_subst Γ 0) k (lift (context_assumptions Γ) (k + #|Γ|) t)).

Definition expand_lets Γ t := expand_lets_k Γ 0 t.

Definition expand_lets_k_ctx Γ k Δ := 
  (subst_context (extended_subst Γ 0) k (lift_context (context_assumptions Γ) (k + #|Γ|) Δ)).

Definition expand_lets_ctx Γ Δ := expand_lets_k_ctx Γ 0 Δ.

Lemma subst_consn_ids_ren n k f : (idsn n ⋅n (tRel k ⋅ ren f) =1 ren (ren_ids n ⋅n (subst_cons_gen k f)))%sigma.
Proof.
  intros i.
  destruct (Nat.leb_spec n i).
  - rewrite subst_consn_ge idsn_length. auto.
    unfold ren. f_equal. rewrite subst_consn_ge ren_ids_length; auto.
    unfold subst_cons_gen. destruct (i - n) eqn:eqin. simpl. auto. simpl. reflexivity.
  - assert (Hr:i < #|ren_ids n|) by (rewrite ren_ids_length; lia).
    assert (Hi:i < #|idsn n|) by (rewrite idsn_length; lia).
    destruct (subst_consn_lt Hi) as [x' [Hnth He]].
    destruct (subst_consn_lt Hr) as [x'' [Hnth' He']].
    rewrite (idsn_lt H) in Hnth.
    rewrite (ren_ids_lt H) in Hnth'.
    injection Hnth as <-. injection Hnth' as <-. rewrite He.
    unfold ren. now rewrite He'.
Qed.

Lemma subst_reli_lift_id i n t : i <= n ->
  subst [tRel i] n (lift (S i) (S n) t) = (lift i n t).
Proof.
  intros ltin.
  sigma.
  apply inst_ext.
  unfold Upn. sigma. unfold shiftk at 1 => /=.
  simpl.
  rewrite ren_shiftk. rewrite subst_consn_ids_ren.
  unfold lift_renaming. rewrite compose_ren.
  intros i'. unfold ren, ids; simpl. f_equal.
  elim: Nat.leb_spec => H'. unfold subst_consn, subst_cons_gen.
  elim: nth_error_spec => [i'' e l|].
  rewrite ren_ids_length /= in l. lia.
  rewrite ren_ids_length /=.
  intros Hn. destruct (S (i + i') - n) eqn:?. lia.
  elim: (Nat.leb_spec n i'). lia. lia.
  unfold subst_consn, subst_cons_gen.
  elim: nth_error_spec => [i'' e l|].
  rewrite (@ren_ids_lt n i') in e. rewrite ren_ids_length in l. auto.
  noconf e. rewrite ren_ids_length in l. 
  elim: Nat.leb_spec; try lia.
  rewrite ren_ids_length /=.
  intros. destruct (i' - n) eqn:?; try lia.
  elim: Nat.leb_spec; try lia.
Qed.

Lemma expand_lets_k_vass Γ na ty k t : 
  expand_lets_k (Γ ++ [{| decl_name := na; decl_body := None; decl_type := ty |}]) k t =
  expand_lets_k Γ k t.
Proof.
  rewrite /expand_lets /expand_lets_k; autorewrite with len.
  rewrite extended_subst_app /=.
  rewrite subst_app_simpl. simpl. autorewrite with len.
  rewrite !Nat.add_1_r.
  rewrite subst_context_lift_id. f_equal.
  rewrite Nat.add_succ_r.
  rewrite subst_reli_lift_id //.
  move: (context_assumptions_length_bound Γ); lia.
Qed.

Lemma expand_lets_vass Γ na ty t : 
  expand_lets (Γ ++ [{| decl_name := na; decl_body := None; decl_type := ty |}]) t =
  expand_lets Γ t.
Proof.
  rewrite /expand_lets; apply expand_lets_k_vass.
Qed.

Lemma expand_lets_k_vdef Γ na b ty k t : 
  expand_lets_k (Γ ++ [{| decl_name := na; decl_body := Some b; decl_type := ty |}]) k t =
  expand_lets_k (subst_context [b] 0 Γ) k (subst [b] (k + #|Γ|) t).
Proof.
  rewrite /expand_lets /expand_lets_k; autorewrite with len.
  rewrite extended_subst_app /=.
  rewrite subst_app_simpl. simpl. autorewrite with len.
  rewrite !subst_empty lift0_id lift0_context.
  epose proof (distr_lift_subst_rec _ [b] (context_assumptions Γ) (k + #|Γ|) 0).
  rewrite !Nat.add_0_r in H.
  f_equal. simpl in H. rewrite Nat.add_assoc.
  rewrite <- H.
  reflexivity.
Qed.

Lemma expand_lets_vdef Γ na b ty t : 
  expand_lets (Γ ++ [{| decl_name := na; decl_body := Some b; decl_type := ty |}]) t =
  expand_lets (subst_context [b] 0 Γ) (subst [b] #|Γ| t).
Proof.
  rewrite /expand_lets; apply expand_lets_k_vdef.
Qed.

Definition expand_lets_k_ctx_vass Γ k Δ na ty :
  expand_lets_k_ctx Γ k (Δ ++ [{| decl_name := na; decl_body := None; decl_type := ty |}]) =
  expand_lets_k_ctx Γ (S k) Δ ++ [{| decl_name := na; decl_body := None; decl_type :=
    expand_lets_k Γ k ty |}].
Proof. 
  now  rewrite /expand_lets_k_ctx lift_context_app subst_context_app /=; simpl.
Qed.

Definition expand_lets_k_ctx_decl Γ k Δ d :
  expand_lets_k_ctx Γ k (Δ ++ [d]) = expand_lets_k_ctx Γ (S k) Δ ++ [map_decl (expand_lets_k Γ k) d].
Proof. 
  rewrite /expand_lets_k_ctx lift_context_app subst_context_app /=; simpl.
  unfold app_context. simpl.
  rewrite /subst_context /fold_context /=.
  f_equal. rewrite compose_map_decl. f_equal.
Qed.

Lemma expand_lets_subst_comm Γ s : 
  expand_lets (subst_context s 0 Γ) ∘ subst s #|Γ| =1 subst s (context_assumptions Γ) ∘ expand_lets Γ.
Proof.
  unfold expand_lets, expand_lets_k; simpl; intros x.
  autorewrite with len.
  rewrite !subst_extended_subst.
  rewrite distr_subst. f_equal.
  autorewrite with len.
  now rewrite commut_lift_subst_rec.
Qed.

Lemma map_expand_lets_subst_comm Γ s :
  map (expand_lets (subst_context s 0 Γ)) ∘ (map (subst s #|Γ|)) =1 
  map (subst s (context_assumptions Γ)) ∘ (map (expand_lets Γ)).
Proof.
  intros l. rewrite !map_map_compose.
  apply map_ext. intros x; apply expand_lets_subst_comm.
Qed.

Lemma map_subst_expand_lets s Γ : 
  context_assumptions Γ = #|s| ->
  subst0 (map (subst0 s) (extended_subst Γ 0)) =1 subst0 s ∘ expand_lets Γ.
Proof.
  intros Hs x; unfold expand_lets, expand_lets_k.
  rewrite distr_subst. f_equal.
  autorewrite with len.
  simpl. rewrite simpl_subst_k //.
Qed.

Lemma map_subst_expand_lets_k s Γ k x : 
  context_assumptions Γ = #|s| ->
  subst (map (subst0 s) (extended_subst Γ 0)) k x = (subst s k ∘ expand_lets_k Γ k) x.
Proof.
  intros Hs; unfold expand_lets, expand_lets_k.
  epose proof (distr_subst_rec _ _ _ 0 _). rewrite -> Nat.add_0_r in H.
  rewrite -> H. clear H. f_equal.
  autorewrite with len.
  simpl. rewrite simpl_subst_k //.
Qed.

Lemma subst_context_map_subst_expand_lets s Γ Δ : 
  context_assumptions Γ = #|s| ->
  subst_context (map (subst0 s) (extended_subst Γ 0)) 0 Δ = subst_context s 0 (expand_lets_ctx Γ Δ).
Proof.
  intros Hs. rewrite !subst_context_alt.
  unfold expand_lets_ctx, expand_lets_k_ctx.
  rewrite subst_context_alt lift_context_alt. autorewrite with len.
  rewrite !mapi_compose. apply mapi_ext.
  intros n x. unfold subst_decl, lift_decl.
  rewrite !compose_map_decl. apply map_decl_ext.
  intros. simpl. rewrite !Nat.add_0_r.
  generalize (Nat.pred #|Δ| - n). intros.
  rewrite map_subst_expand_lets_k //.
Qed.

Lemma subst_context_map_subst_expand_lets_k s Γ Δ k : 
  context_assumptions Γ = #|s| ->
  subst_context (map (subst0 s) (extended_subst Γ 0)) k Δ = subst_context s k (expand_lets_k_ctx Γ k Δ).
Proof.
  intros Hs. rewrite !subst_context_alt.
  unfold expand_lets_ctx, expand_lets_k_ctx.
  rewrite subst_context_alt lift_context_alt. autorewrite with len.
  rewrite !mapi_compose. apply mapi_ext.
  intros n x. unfold subst_decl, lift_decl.
  rewrite !compose_map_decl. apply map_decl_ext.
  intros. simpl.
  rewrite map_subst_expand_lets_k //. f_equal.
  rewrite /expand_lets_k. lia_f_equal.
Qed.

Lemma context_subst_subst_extended_subst inst s Δ : 
  context_subst Δ inst s ->
  s = map (subst0 (List.rev inst)) (extended_subst Δ 0).
Proof.
  intros sp.
  induction sp.
  - simpl; auto.
  - rewrite List.rev_app_distr /= lift0_id. f_equal.
    rewrite lift_extended_subst.
    rewrite map_map_compose. rewrite IHsp. apply map_ext.
    intros. rewrite (subst_app_decomp [_]). f_equal.
    simpl. rewrite simpl_subst ?lift0_id //.
  - simpl. autorewrite with len.
    f_equal; auto.
    rewrite IHsp.
    rewrite distr_subst. f_equal.
    simpl; autorewrite with len.
    pose proof (context_subst_length2 sp).
    rewrite -H. rewrite -(List.rev_length args).
    rewrite -(Nat.add_0_r #|List.rev args|).
    rewrite simpl_subst_rec; try lia.
    now rewrite lift0_id.
Qed.

Lemma spine_subst_extended_subst {cf:checker_flags} {Σ Γ inst s Δ} : 
  spine_subst Σ Γ inst s Δ ->
  s = map (subst0 (List.rev inst)) (extended_subst Δ 0).
Proof.
  intros [_ _ sp _]. now apply context_subst_subst_extended_subst in sp.
Qed.

(* Lemma spine_subst_extended_subst {cf:checker_flags} {Σ Γ inst s Δ} : 
  spine_subst Σ Γ inst s Δ ->
  forall Γ', subst_context s 0 Γ' s = map (subst0 (List.rev inst)) (extended_subst Δ 0).
Proof.
  intros [_ _ sp _]. now apply context_subst_subst_extended_subst in sp.
Qed.
 *)

Definition ind_subst mdecl ind u := inds (inductive_mind ind) u (ind_bodies mdecl).

Ltac pcuic := intuition eauto 5 with pcuic ||
  (try solve [repeat red; cbn in *; intuition auto; eauto 5 with pcuic || (try lia || congruence)]).

(** Inversion principles on inductive/coinductives types following from validity. *)

Lemma isWAT_it_mkProd_or_LetIn_mkApps_Ind_isType {cf:checker_flags} {Σ Γ ind u args} Δ :
  wf Σ.1 ->
  isWfArity_or_Type Σ Γ (it_mkProd_or_LetIn Δ (mkApps (tInd ind u) args)) ->
  isType Σ Γ (it_mkProd_or_LetIn Δ (mkApps (tInd ind u) args)).
Proof.
  intros wfΣ.
  intros [[ctx [s eq]]|H]; auto.
  rewrite destArity_it_mkProd_or_LetIn in eq.
  destruct eq as [da _].
  apply destArity_app_Some in da as [ctx' [da _]].
  rewrite destArity_tInd in da. discriminate.
Qed.

Lemma isWAT_mkApps_Ind_isType {cf:checker_flags} Σ Γ ind u args :
  wf Σ.1 ->
  isWfArity_or_Type Σ Γ (mkApps (tInd ind u) args) ->
  isType Σ Γ (mkApps (tInd ind u) args).
Proof.
  intros wfΣ H.
  now apply (isWAT_it_mkProd_or_LetIn_mkApps_Ind_isType [] wfΣ).
Qed.

Lemma declared_constructor_valid_ty {cf:checker_flags} Σ Γ mdecl idecl i n cdecl u :
  wf Σ.1 ->
  wf_local Σ Γ ->
  declared_constructor Σ.1 mdecl idecl (i, n) cdecl ->
  consistent_instance_ext Σ (ind_universes mdecl) u ->
  isType Σ Γ (type_of_constructor mdecl cdecl (i, n) u).
Proof.
  move=> wfΣ wfΓ declc Hu.
  epose proof (env_prop_typing _ _ validity Σ wfΣ Γ (tConstruct i n u)
    (type_of_constructor mdecl cdecl (i, n) u)).
  forward X by eapply type_Construct; eauto.
  simpl in X.
  unfold type_of_constructor in X |- *.
  destruct (on_declared_constructor _ declc); eauto.
  destruct s as [cshape [Hsorc Hc]].
  destruct Hc as [_ chead cstr_eq [cs Hcs] _ _].
  destruct cshape. rewrite /cdecl_type in cstr_eq.
  rewrite cstr_eq in X |- *. clear -wfΣ declc X.
  move: X. simpl.
  rewrite /subst1 !subst_instance_constr_it_mkProd_or_LetIn !subst_it_mkProd_or_LetIn.
  rewrite !subst_instance_constr_mkApps !subst_mkApps.
  rewrite !subst_instance_context_length Nat.add_0_r.
  rewrite subst_inds_concl_head.
  + simpl. destruct declc as [[onm oni] ?].
    now eapply nth_error_Some_length in oni.
  + rewrite -it_mkProd_or_LetIn_app. apply isWAT_it_mkProd_or_LetIn_mkApps_Ind_isType. auto.
Qed.

Lemma declared_inductive_valid_type {cf:checker_flags} Σ Γ mdecl idecl i u :
  wf Σ.1 ->
  wf_local Σ Γ ->
  declared_inductive Σ.1 mdecl i idecl ->
  consistent_instance_ext Σ (ind_universes mdecl) u ->
  isType Σ Γ (subst_instance_constr u (ind_type idecl)).
Proof.
  move=> wfΣ wfΓ declc Hu.
  pose declc as declc'.
  apply on_declared_inductive in declc' as [onmind onind]; auto.
  apply onArity in onind.
  destruct onind as [s Hs].
  epose proof (PCUICUnivSubstitution.typing_subst_instance_decl Σ) as s'.
  destruct declc.
  specialize (s' [] _ _ _ _ u wfΣ H Hs Hu).
  simpl in s'. eexists; eauto.
  eapply (PCUICWeakening.weaken_ctx (Γ:=[]) Γ); eauto.
Qed.

Lemma type_tFix_inv {cf:checker_flags} (Σ : global_env_ext) Γ mfix idx T : wf Σ ->
  Σ ;;; Γ |- tFix mfix idx : T ->
  { T' & { rarg & {f & (unfold_fix mfix idx = Some (rarg, f))  *
    wf_fixpoint Σ.1  mfix
  * (Σ ;;; Γ |- f : T') * (Σ ;;; Γ |- T' <= T) }}}%type.
Proof.
  intros wfΣ H. depind H.
  - unfold unfold_fix. rewrite e.
    specialize (nth_error_all e a0) as [s Hs].
    specialize (nth_error_all e a1) as [Hty Hlam].
    simpl.
    destruct decl as [name ty body rarg]; simpl in *.
    clear e.
    eexists _, _, _. split.
    + split.
      * eauto.
      * eapply (substitution _ _ _ _ [] _ _ wfΣ); simpl; eauto with wf.
        rename i into hguard. clear -i0 a a0 a1 hguard.
        pose proof a1 as a1'. apply All_rev in a1'.
        unfold fix_subst, fix_context. simpl.
        revert a1'. rewrite <- (@List.rev_length _ mfix).
        rewrite rev_mapi. unfold mapi.
        assert (#|mfix| >= #|List.rev mfix|) by (rewrite List.rev_length; lia).
        assert (He :0 = #|mfix| - #|List.rev mfix|) by (rewrite List.rev_length; auto with arith).
        rewrite {3}He. clear He. revert H.
        assert (forall i, i < #|List.rev mfix| -> nth_error (List.rev mfix) i = nth_error mfix (#|List.rev mfix| - S i)).
        { intros. rewrite nth_error_rev. 1: auto.
          now rewrite List.rev_length List.rev_involutive. }
        revert H.
        generalize (List.rev mfix).
        intros l Hi Hlen H.
        induction H.
        ++ simpl. constructor.
        ++ simpl. constructor.
          ** unfold mapi in IHAll.
              simpl in Hlen. replace (S (#|mfix| - S #|l|)) with (#|mfix| - #|l|) by lia.
              apply IHAll.
              --- intros. simpl in Hi. specialize (Hi (S i)). apply Hi. lia.
              --- lia.
          ** clear IHAll. destruct p.
              simpl in Hlen. assert ((Nat.pred #|mfix| - (#|mfix| - S #|l|)) = #|l|) by lia.
              rewrite H0. rewrite simpl_subst_k.
              --- clear. induction l; simpl; auto with arith.
              --- eapply type_Fix; auto.
                  simpl in Hi. specialize (Hi 0). forward Hi.
                  +++ lia.
                  +++ simpl in Hi.
                      rewrite Hi. f_equal. lia.

    + rewrite simpl_subst_k.
      * now rewrite fix_context_length fix_subst_length.
      * reflexivity.
  - destruct (IHtyping wfΣ) as [T' [rarg [f [[unf fty] Hcumul]]]].
    exists T', rarg, f. intuition auto.
    + eapply cumul_trans; eauto.
    + destruct b. eapply cumul_trans; eauto.
Qed.

Lemma subslet_cofix {cf:checker_flags} (Σ : global_env_ext) Γ mfix :
  wf_local Σ Γ ->
  cofix_guard mfix ->
  All (fun d : def term => ∑ s : Universe.t, Σ;;; Γ |- dtype d : tSort s) mfix ->
  All
  (fun d : def term =>
   Σ;;; Γ ,,, fix_context mfix |- dbody d
   : lift0 #|fix_context mfix| (dtype d)) mfix ->
  wf_cofixpoint Σ.1 mfix -> subslet Σ Γ (cofix_subst mfix) (fix_context mfix).
Proof.
  intros wfΓ hguard types bodies wfcofix.
  pose proof bodies as X1. apply All_rev in X1.
  unfold cofix_subst, fix_context. simpl.
  revert X1. rewrite <- (@List.rev_length _ mfix).
  rewrite rev_mapi. unfold mapi.
  assert (#|mfix| >= #|List.rev mfix|) by (rewrite List.rev_length; lia).
  assert (He :0 = #|mfix| - #|List.rev mfix|) by (rewrite List.rev_length; auto with arith).
  rewrite {3}He. clear He. revert H.
  assert (forall i, i < #|List.rev mfix| -> nth_error (List.rev mfix) i = nth_error mfix (#|List.rev mfix| - S i)).
  { intros. rewrite nth_error_rev. 1: auto.
    now rewrite List.rev_length List.rev_involutive. }
  revert H.
  generalize (List.rev mfix).
  intros l Hi Hlen H.
  induction H.
  ++ simpl. constructor.
  ++ simpl. constructor.
    ** unfold mapi in IHAll.
        simpl in Hlen. replace (S (#|mfix| - S #|l|)) with (#|mfix| - #|l|) by lia.
        apply IHAll.
        --- intros. simpl in Hi. specialize (Hi (S i)). apply Hi. lia.
        --- lia.
    ** clear IHAll.
        simpl in Hlen. assert ((Nat.pred #|mfix| - (#|mfix| - S #|l|)) = #|l|) by lia.
        rewrite H0. rewrite simpl_subst_k.
        --- clear. induction l; simpl; auto with arith.
        --- eapply type_CoFix; auto.
            simpl in Hi. specialize (Hi 0). forward Hi.
            +++ lia.
            +++ simpl in Hi.
                rewrite Hi. f_equal. lia.
Qed.

Lemma type_tCoFix_inv {cf:checker_flags} (Σ : global_env_ext) Γ mfix idx T : wf Σ ->
  Σ ;;; Γ |- tCoFix mfix idx : T ->
  ∑ d, (nth_error mfix idx = Some d) *
    wf_cofixpoint Σ.1 mfix *
    (Σ ;;; Γ |- subst0 (cofix_subst mfix) (dbody d) : (dtype d)) *
    (Σ ;;; Γ |- dtype d <= T).
Proof.
  intros wfΣ H. depind H.
  - exists decl. 
    specialize (nth_error_all e a1) as Hty.
    destruct decl as [name ty body rarg]; simpl in *.
    intuition auto.
    * eapply (substitution _ _ _ (cofix_subst mfix) [] _ _ wfΣ) in Hty. simpl; eauto with wf.
      simpl in Hty.
      rewrite subst_context_nil /= in Hty.
      eapply refine_type; eauto.
      rewrite simpl_subst_k //. now autorewrite with len.
      apply subslet_cofix; auto. 
    * reflexivity.
  - destruct (IHtyping wfΣ) as [d [[[Hnth wfcofix] ?] ?]].
    exists d. intuition auto.
    + eapply cumul_trans; eauto.
    + eapply cumul_trans; eauto.
Qed.

Lemma wf_cofixpoint_all {cf:checker_flags} (Σ : global_env_ext) mfix :
  wf_cofixpoint Σ.1 mfix ->
  ∑ mind, check_recursivity_kind Σ.1 mind CoFinite *
  All (fun d => ∑ ctx i u args, (dtype d) = it_mkProd_or_LetIn ctx (mkApps (tInd {| inductive_mind := mind; inductive_ind := i |} u) args)) mfix.
Proof.
  unfold wf_cofixpoint.
  destruct mfix. discriminate.
  simpl.
  destruct (check_one_cofix d) as [ind|] eqn:hcof.
  intros eqr.
  exists ind.
  destruct (map_option_out (map check_one_cofix mfix)) eqn:eqfixes.
  move/andP: eqr => [eqinds rk].
  split; auto.
  constructor.
  - move: hcof. unfold check_one_cofix.
    destruct d as [dname dbody dtype rarg] => /=.
    destruct (decompose_prod_assum [] dbody) as [ctx concl] eqn:Hdecomp.
    apply decompose_prod_assum_it_mkProd_or_LetIn in Hdecomp.
    destruct (decompose_app concl) eqn:dapp.
    destruct (destInd t) as [[ind' u]|] eqn:dind.
    destruct ind' as [mind ind'].
    move=> [=] Hmind. subst mind.
    exists ctx, ind', u, l0.
    simpl in Hdecomp. rewrite Hdecomp.
    f_equal.
    destruct t; try discriminate.
    simpl in dind. noconf dind.
    apply decompose_app_inv in dapp => //.
    discriminate.
  - clear rk hcof.
    induction mfix in l, eqfixes, eqinds |- *. constructor.
    simpl in *.
    destruct (check_one_cofix a) eqn:hcof; try discriminate.
    destruct (map_option_out (map check_one_cofix mfix)) eqn:hcofs; try discriminate.
    noconf eqfixes.
    specialize (IHmfix _ eq_refl).
    simpl in eqinds.
    move/andP: eqinds => [eqk eql0].
    constructor; auto. clear IHmfix hcofs d.
    destruct a as [dname dbody dtype rarg] => /=.
    unfold check_one_cofix in hcof.
    destruct (decompose_prod_assum [] dbody) as [ctx concl] eqn:Hdecomp.
    apply decompose_prod_assum_it_mkProd_or_LetIn in Hdecomp.
    destruct (decompose_app concl) eqn:dapp.
    destruct (destInd t) as [[ind' u]|] eqn:dind.
    destruct ind' as [mind ind']. noconf hcof.
    exists ctx, ind', u, l.
    simpl in Hdecomp. rewrite Hdecomp.
    f_equal.
    destruct t; try discriminate.
    simpl in dind. noconf dind.
    apply decompose_app_inv in dapp => //.
    rewrite dapp. do 3 f_equal.
    symmetry.
    change (eq_kername ind k) with (PCUICReflect.eqb ind k) in eqk.
    destruct (PCUICReflect.eqb_spec ind k); auto. discriminate.
    discriminate.
  - discriminate.
  - discriminate.
Qed.

Lemma on_constructor_subst' {cf:checker_flags} Σ ind mdecl idecl cshape cdecl : 
  wf Σ -> 
  declared_inductive Σ mdecl ind idecl ->
  on_inductive (lift_typing typing) (Σ, ind_universes mdecl) (inductive_mind ind) mdecl ->
  forall (oib : on_ind_body (lift_typing typing) (Σ, ind_universes mdecl) (inductive_mind ind) mdecl 
           (inductive_ind ind) idecl)
        (onc : on_constructor (lift_typing typing) (Σ, ind_universes mdecl)
          mdecl (inductive_ind ind) idecl (ind_indices oib) cdecl cshape),
  wf_global_ext Σ (ind_universes mdecl) *
  wf_local (Σ, ind_universes mdecl)
   (arities_context (ind_bodies mdecl) ,,, ind_params mdecl ,,, cshape_args cshape) *
  ctx_inst (Σ, ind_universes mdecl)
             (arities_context (ind_bodies mdecl) ,,, ind_params mdecl ,,,
              cshape_args cshape)
             (cshape_indices cshape) 
            (List.rev (lift_context #|cshape_args cshape| 0 (ind_indices oib))). 
Proof.
  move=> wfΣ declm oi oib onc.
  pose proof (on_cargs onc). simpl in X.
  split.
  - split. split.
    2:{ eapply (weaken_lookup_on_global_env'' _ _ (InductiveDecl mdecl)); pcuic. destruct declm; pcuic. }
    red. split; eauto. simpl. eapply (weaken_lookup_on_global_env' _ _ (InductiveDecl mdecl)); eauto.
    destruct declm; pcuic.
    eapply type_local_ctx_wf_local in X => //. clear X.
    eapply weaken_wf_local => //.
    eapply wf_arities_context; eauto. destruct declm; eauto.
    now eapply onParams.
  - apply (on_cindices onc).
Qed.

Lemma on_constructor_subst {cf:checker_flags} Σ ind mdecl idecl cshape cdecl : 
  wf Σ -> 
  declared_inductive Σ mdecl ind idecl ->
  on_inductive (lift_typing typing) (Σ, ind_universes mdecl) (inductive_mind ind) mdecl ->
  forall (oib : on_ind_body (lift_typing typing) (Σ, ind_universes mdecl) (inductive_mind ind) mdecl 
           (inductive_ind ind) idecl)
        (onc : on_constructor (lift_typing typing) (Σ, ind_universes mdecl)
          mdecl (inductive_ind ind) idecl (ind_indices oib) cdecl cshape),
  wf_global_ext Σ (ind_universes mdecl) *
  wf_local (Σ, ind_universes mdecl)
   (arities_context (ind_bodies mdecl) ,,, ind_params mdecl ,,, cshape_args cshape) *
  ∑ inst,
  spine_subst (Σ, ind_universes mdecl)
             (arities_context (ind_bodies mdecl) ,,, ind_params mdecl ,,,
              cshape_args cshape)
             ((to_extended_list_k (ind_params mdecl) #|cshape_args cshape|) ++
              (cshape_indices cshape)) inst
          (ind_params mdecl ,,, ind_indices oib). 
Proof.
  move=> wfΣ declm oi oib onc.
  pose proof (onc.(on_cargs)). simpl in X.
  split. split. split.
  2:{ eapply (weaken_lookup_on_global_env'' _ _ (InductiveDecl mdecl)); pcuic. destruct declm; pcuic. }
  red. split; eauto. simpl. eapply (weaken_lookup_on_global_env' _ _ (InductiveDecl mdecl)); eauto.
  destruct declm; pcuic. 
  eapply type_local_ctx_wf_local in X => //. clear X.
  eapply weaken_wf_local => //.
  eapply wf_arities_context; eauto. destruct declm; eauto.
  now eapply onParams.
  destruct (on_ctype onc).
  rewrite onc.(cstr_eq) in t.
  rewrite -it_mkProd_or_LetIn_app in t.
  eapply inversion_it_mkProd_or_LetIn in t => //.
  unfold cstr_concl_head in t. simpl in t.
  eapply inversion_mkApps in t as [A [ta sp]].
  eapply inversion_Rel in ta as [decl [wfΓ [nth cum']]].
  rewrite nth_error_app_ge in nth. autorewrite with len. lia.
  autorewrite with len in nth.
  all:auto.
  assert ( (#|ind_bodies mdecl| - S (inductive_ind ind) + #|ind_params mdecl| +
  #|cshape_args cshape| -
  (#|cshape_args cshape| + #|ind_params mdecl|)) = #|ind_bodies mdecl| - S (inductive_ind ind)) by lia.
  move: nth; rewrite H; clear H. destruct nth_error eqn:Heq => //.
  simpl.
  move=> [=] Hdecl. eapply (nth_errror_arities_context (Σ, ind_universes mdecl)) in Heq; eauto.
  subst decl.
  rewrite Heq in cum'; clear Heq c.
  assert(closed (ind_type idecl)).
  { pose proof (oib.(onArity)). rewrite (oib.(ind_arity_eq)) in X0 |- *.
    destruct X0 as [s Hs]. now apply subject_closed in Hs. } 
  rewrite lift_closed in cum' => //.
  eapply typing_spine_strengthen in sp; pcuic.
  move: sp. 
  rewrite (oib.(ind_arity_eq)).
  rewrite -it_mkProd_or_LetIn_app.
  move=> sp. simpl in sp.
  apply (arity_typing_spine (Σ, ind_universes mdecl)) in sp as [[Hlen Hleq] [inst Hinst]] => //.
  clear Hlen.
  rewrite [_ ,,, _]app_context_assoc in Hinst.
  now exists inst.
  apply weaken_wf_local => //.

  rewrite [_ ,,, _]app_context_assoc in wfΓ.
  eapply All_local_env_app in wfΓ as [? ?].
  apply on_minductive_wf_params_indices => //. pcuic.
Qed.

Lemma on_constructor_inst {cf:checker_flags} Σ ind u mdecl idecl cshape cdecl : 
  wf Σ.1 -> 
  declared_inductive Σ.1 mdecl ind idecl ->
  on_inductive (lift_typing typing) (Σ.1, ind_universes mdecl) (inductive_mind ind) mdecl ->
  forall (oib : on_ind_body (lift_typing typing) (Σ.1, ind_universes mdecl) (inductive_mind ind) mdecl 
           (inductive_ind ind) idecl)
        (onc : on_constructor (lift_typing typing) (Σ.1, PCUICAst.ind_universes mdecl)
          mdecl (inductive_ind ind) idecl (ind_indices oib) cdecl cshape), 
  consistent_instance_ext Σ (ind_universes mdecl) u ->
  wf_local Σ (subst_instance_context u
    (arities_context (ind_bodies mdecl) ,,, ind_params mdecl ,,, cshape_args cshape)) *
  ∑ inst,
  spine_subst Σ
          (subst_instance_context u
             (arities_context (ind_bodies mdecl) ,,, ind_params mdecl ,,,
              cshape_args cshape))
          (map (subst_instance_constr u)
             (to_extended_list_k (ind_params mdecl) #|cshape_args cshape|) ++
           map (subst_instance_constr u) (cshape_indices cshape)) inst
          (subst_instance_context u (ind_params mdecl) ,,,
           subst_instance_context u (ind_indices oib)). 
Proof.
  move=> wfΣ declm oi oib onc cext.
  destruct (on_constructor_subst Σ.1 ind mdecl idecl _ cdecl wfΣ declm oi oib onc) as [[wfext wfl] [inst sp]].
  eapply wf_local_subst_instance in wfl; eauto. split=> //.
  eapply spine_subst_inst in sp; eauto.
  rewrite map_app in sp. rewrite -subst_instance_context_app.
  eexists ; eauto.
Qed.
Hint Rewrite subst_instance_context_assumptions to_extended_list_k_length : len.
(* 
Lemma expand_lets_k_ctx_subst_id Γ k Δ : 
  closedn_ctx #|Γ| Δ -> 
  subst_context (List.rev (to_extended_list_k Γ k)) 0 (expand_lets_ctx Γ Δ) = 
  expand_lets_k_ctx Γ k (lift_context k 0 Δ).
Proof.
  rewrite /expand_lets_ctx /expand_lets_k_ctx.
  intros clΔ.
Admitted. *)

(*
Lemma expand_lets_k_ctx_idem Γ k Δ : 
  expand_lets_k_ctx Γ k (expand_lets_k_ctx Γ k Δ) =
  expand_lets_k_ctx Γ k Δ.
Proof.
  rewrite /expand_lets_ctx /expand_lets_k_ctx.
  induction Γ in k, Δ |- *.
  - simpl to_extended_list_k; simpl List.rev.
     rewrite !subst0_context /= ?lift0_context /=. reflexivity.
  - destruct a as [na [b|] ty].
    rewrite /expand_lets_k_ctx /=.
    autorewrite with len. simpl to_extended_list_k.
    f_equal.
    rewrite Nat.add_1_r; change  (S k) with (1 + k); rewrite reln_lift.
    rewrite (subst_app_context_gen [_]). simpl.
    rewrite ->( subst_app_context_gen [subst0 (extended_subst Γ 0) (lift  (context_assumptions Γ) #|Γ| b)] (extended_subst Γ 0)).
    simpl. simpl in clΔ.
    rewrite /expand_lets_k_ctx in IHΓ.
    simpl. f_equal.
    specialize (IHΓ (S k)). simpl in IHΓ.
    rewrite Nat.add_1_r Nat.add_succ_r. -IHΓ.

Admitted.*)
Require Import ssrbool.
Section VarCheck.

  Section AllDefs.
  (* Predicate [p k n] where k is the number of binders we passed and n the index of the variable to check. *)
  Variable p : nat -> nat -> bool.

  Fixpoint all_vars k (t : term) : bool :=
  match t with
  | tRel i => p k i
  | tEvar ev args => List.forallb (all_vars k) args
  | tLambda _ T M | tProd _ T M => all_vars k T && all_vars (S k) M
  | tApp u v => all_vars k u && all_vars k v
  | tLetIn na b t b' => all_vars k b && all_vars k t && all_vars (S k) b'
  | tCase ind p c brs =>
    let brs' := List.forallb (test_snd (all_vars k)) brs in
    all_vars k p && all_vars k c && brs'
  | tProj p c => all_vars k c
  | tFix mfix idx =>
    let k' := List.length mfix + k in
    List.forallb (test_def (all_vars k) (all_vars k')) mfix
  | tCoFix mfix idx =>
    let k' := List.length mfix + k in
    List.forallb (test_def (all_vars k) (all_vars k')) mfix
  | tVar _ | tSort _ | tConst _ _ | tInd _ _ | tConstruct _ _ _ => true
  end.

  Lemma all_vars_true k t : (forall k n, p k n) -> all_vars k t.
  Proof.
    intros. revert k.
    induction t using PCUICInduction.term_forall_list_ind; simpl => //; solve_all.
    solve_all.
    all:try now rewrite ?IHt1 ?IHt2 ?IHt3.
    rewrite IHt1 IHt2. eapply All_forallb. solve_all.
    eapply All_forallb; solve_all. unfold test_def.
    now rewrite a b.
    eapply All_forallb; solve_all. unfold test_def.
    now rewrite a b.
  Qed.
  End AllDefs.

  Lemma all_vars_impl (p q : nat -> nat -> bool) k t : (forall k n, p k n -> q k n) -> 
    all_vars p k t -> all_vars q k t.
  Proof.
    intros. revert t k H0.
    induction t using PCUICInduction.term_forall_list_ind; simpl => //; solve_all.
    all:try solve_all.
    all:try now rewrite ?IHt1 ?IHt2 ?IHt3.
    apply /andP. move/andP: H0. intuition auto.
    apply /andP. move/andP: H0. intuition auto.
    apply /andP. move/andP: H0. intuition auto.
    apply /andP. move/andP: H1. intuition auto.
    apply /andP. move/andP: H0. intuition auto.
    apply /andP. move/andP: H0. intuition auto.
    apply /andP. move/andP: H1. intuition auto.
    solve_all.
    solve_all.
    unfold test_def in *.
    apply /andP. move/andP: b. intuition auto.
    solve_all.
    unfold test_def in *.
    apply /andP. move/andP: b. intuition auto.
  Qed.

  Lemma forallb_eq {A} (p q : A -> bool) l :
    All (fun x => p x = q x) l -> forallb p l = forallb q l.
  Proof.
    intros H; induction H; simpl; auto.
    now rewrite p0 IHAll.
  Qed.

  Lemma all_vars_eq_k (p q : nat -> nat -> bool) k k' t : (forall k n, p (k' + k) n = q k n) -> 
    all_vars p (k' + k) t = all_vars q k t.
  Proof.
    intros. revert t k.
    induction t using PCUICInduction.term_forall_list_ind; simpl => //.
    all:try solve_all.
    eapply forallb_eq. solve_all.
    rewrite IHt1 -(IHt2 (S k)). lia_f_equal.
    rewrite IHt1 -(IHt2 (S k)). lia_f_equal.
    rewrite IHt1 -(IHt2 k) -(IHt3 (S k)). lia_f_equal.
    rewrite IHt1 IHt2. bool_congr. eapply forallb_eq. solve_all.
    eapply forallb_eq. solve_all.
    unfold test_def.
    rewrite a -(b (#|m| + k)). lia_f_equal.
    eapply forallb_eq. solve_all.
    unfold test_def.
    rewrite a -(b (#|m| + k)). lia_f_equal.
  Qed.
 
  Lemma all_vars_lift (p : nat -> nat -> bool) n k t : 
    (forall n k' k, k <= n -> p k n -> p (k' + k) (k' + n)) ->
    (forall n k' k, n < k -> p k n -> p (k' + k) n) ->    
    all_vars p k t -> all_vars p (k + n) (lift n k t).
  Proof.
    intros. revert t n k H1.
    induction t using PCUICInduction.term_forall_list_ind; simpl => //; solve_all.
    all:try solve_all.
    - destruct (Nat.leb_spec k n).
      rewrite (Nat.add_comm k n0). now apply H.
      rewrite Nat.add_comm.
      now apply H0.
    - apply /andP. move/andP: H1. intuition eauto.
    - apply /andP. move/andP: H1. intuition eauto.
    - apply /andP. move/andP: H1. intuition eauto.
      move/andP: H2 => [P P']. apply/andP; intuition eauto.
    - apply /andP. move/andP: H1. intuition eauto.
    - apply /andP. move/andP: H1. intuition eauto.
      move/andP: H2 => [P P']. apply/andP; intuition eauto.
      solve_all.
    - autorewrite with len.
      destruct x; rewrite /map_def /test_def; simpl in *.
      apply /andP. move/andP: b; simpl. intuition eauto.
      replace (#|m| + (k + n0)) with ((k + #|m|) + n0) by lia.
      rewrite (Nat.add_comm #|m| k).
      eapply b0. rewrite Nat.add_comm //.
    - autorewrite with len.
      destruct x; rewrite /map_def /test_def; simpl in *.
      apply /andP. move/andP: b; simpl. intuition eauto.
      replace (#|m| + (k + n0)) with ((k + #|m|) + n0) by lia.
      rewrite (Nat.add_comm #|m| k).
      eapply b0. rewrite Nat.add_comm //.
  Qed.

  Lemma all_vars_lift'' (p : nat -> nat -> bool) n k i t : 
    (forall n k' k, k + i <= n -> p k n -> p k (k' + n)) ->
    all_vars p k t -> all_vars p k (lift n (k + i) t).
  Proof.
    intros Pp. revert t n k.
    induction t using PCUICInduction.term_forall_list_ind; simpl => //; solve_all.
    all:try solve_all.
    - destruct (Nat.leb_spec (k + i) n).
      now apply Pp. auto.
    - apply /andP. move/andP: H. intuition eauto.
    - apply /andP. move/andP: H. intuition eauto.
    - apply /andP. move/andP: H. intuition eauto.
      move/andP: H0 => [P P']. apply/andP; intuition eauto.
    - apply /andP. move/andP: H. intuition eauto.
    - apply /andP. move/andP: H. intuition eauto.
      move/andP: H0 => [P P']. apply/andP; intuition eauto.
      solve_all.
    - autorewrite with len.
      destruct x; rewrite /map_def /test_def; simpl in *.
      apply /andP. move/andP: b; simpl. intuition eauto.
      replace (#|m| + (k + i)) with ((k + #|m|) + i) by lia.
      rewrite (Nat.add_comm #|m| k).
      eapply b0. rewrite Nat.add_comm //.
    - autorewrite with len.
      destruct x; rewrite /map_def /test_def; simpl in *.
      apply /andP. move/andP: b; simpl. intuition eauto.
      replace (#|m| + (k + i)) with ((k + #|m|) + i) by lia.
      rewrite (Nat.add_comm #|m| k).
      eapply b0. rewrite Nat.add_comm //.
  Qed.

  Lemma all_vars_lift'' (p : nat -> nat -> bool) n k k' t : 
    (forall n k' n' k, n' <= n -> p k n -> p k (k' + n)) ->
    all_vars p k t -> all_vars p k (lift n k' t).
  Proof.
    intros. revert t n k H0.
    induction t using PCUICInduction.term_forall_list_ind; simpl => //; solve_all.
    all:try solve_all.
    - destruct (Nat.leb_spec k' n).
      eapply H. eauto. auto. auto.
  Admitted.
    (* - apply /andP. move/andP: H1. intuition eauto.
    - apply /andP. move/andP: H1. intuition eauto.
    - apply /andP. move/andP: H1. intuition eauto.
      move/andP: H2 => [P P']. apply/andP; intuition eauto.
    - apply /andP. move/andP: H1. intuition eauto.
    - apply /andP. move/andP: H1. intuition eauto.
      move/andP: H2 => [P P']. apply/andP; intuition eauto.
      solve_all.
    - autorewrite with len.
      destruct x; rewrite /map_def /test_def; simpl in *.
      apply /andP. move/andP: b; simpl. intuition eauto.
      replace (#|m| + (k + n0)) with ((k + #|m|) + n0) by lia.
      rewrite (Nat.add_comm #|m| k).
      eapply b0. rewrite Nat.add_comm //.
    - autorewrite with len.
      destruct x; rewrite /map_def /test_def; simpl in *.
      apply /andP. move/andP: b; simpl. intuition eauto.
      replace (#|m| + (k + n0)) with ((k + #|m|) + n0) by lia.
      rewrite (Nat.add_comm #|m| k).
      eapply b0. rewrite Nat.add_comm //.
  Qed. *)


  Lemma all_vars_lift' (p : nat -> nat -> bool) n k t : 
    (forall k n', p k (if k <=? n' then n + n' else n'))  ->
    all_vars p k (lift n k t).
  Proof.
    intros. revert t k.
    induction t using PCUICInduction.term_forall_list_ind; simpl => //; solve_all.
    all:try solve_all.
    all:try now rewrite ?IHt2 ?IHt2 ?IHt3. apply /andP; intuition eauto.
    rewrite IHt1 -(IHt2 (S k)); apply /andP; intuition auto.
    all:repeat (apply /andP; split; auto).
    rewrite forallb_map. solve_all.
    simpl; auto.
    autorewrite with len; simpl; auto.
    simpl; auto.
    autorewrite with len; simpl; auto.
  Qed.

  Lemma all_vars_subst (p : nat -> nat -> bool) k s t : 
    forallb (all_vars p 0) s ->
    (forall n k' k, k <= n -> p k n -> p (k' + k) (k' + n)) ->
    (forall n k' k, n < k -> p k n -> p (k' + k) n) ->    
    (forall n k, k <= n -> #|s| <= n - k -> p (#|s| + k) n -> p k (n - #|s|)) ->
    (forall n k, n < k -> p (#|s| + k) n -> p k n) ->    
    all_vars p (#|s| + k) t -> all_vars p k (subst s k t).
  Proof.
    intros Hs P1 P2 P3 P4. revert t k.
    induction t using PCUICInduction.term_forall_list_ind; simpl => //; solve_all.
    all:try solve_all.
    all:try now rewrite ?IHt1 ?IHt2 ?IHt3.
    - destruct (Nat.leb_spec k n).
      destruct nth_error eqn:eq.
      eapply nth_error_all in eq; eauto.
      simpl in eq. apply (all_vars_lift _ _ 0); auto.      
      eapply nth_error_None in eq.
      simpl. apply P3; eauto.
      simpl. now apply P4.
    - apply /andP. move/andP: H. intuition eauto.
      now specialize (IHt2 (S k)); rewrite Nat.add_succ_r in IHt2.
    - apply /andP. move/andP: H. intuition eauto.
      now specialize (IHt2 (S k)); rewrite Nat.add_succ_r in IHt2.
    - apply /andP. move/andP: H => [/andP [P P'] Q].
      split. apply/andP. intuition auto.
      now specialize (IHt3 (S k)); rewrite Nat.add_succ_r in IHt3.
    - apply /andP. move/andP: H. intuition eauto.
    - apply /andP. move/andP: H => [/andP [P P'] Q]. intuition eauto.
      apply/andP. intuition auto.
      solve_all.
    - destruct x; simpl in *. autorewrite with len.
      unfold map_def, test_def => /=.
      rewrite /test_def /= in b. move/andP: b => [bd bb].
      apply /andP; split; eauto. specialize (b0 (#|m| + k)).
      apply b0. red. rewrite -bb. lia_f_equal.
    - destruct x; simpl in *. autorewrite with len.
      unfold map_def, test_def => /=.
      rewrite /test_def /= in b. move/andP: b => [bd bb].
      apply /andP; split; eauto. specialize (b0 (#|m| + k)).
      apply b0. red. rewrite -bb. lia_f_equal.
  Qed.
End VarCheck.

Definition no_let Γ (k n : nat) := 
  (n <? k) || 
  match option_map decl_body (nth_error Γ (n - k)) with 
  | Some (Some _) => false
  | _ => true
  end.

Definition no_lets_from Γ k t :=
  all_vars (no_let Γ) k t.
  
Definition option_all (p : term -> bool) (o : option term) : bool :=
  match o with
  | None => true
  | Some b => p b
  end.

Definition test_decl (p : term -> bool) d :=
  p d.(decl_type) && option_all p d.(decl_body).

Definition no_lets_ctx_from Γ k ctx :=
  Alli (fun i => test_decl (no_lets_from Γ (i + k))) 0 (List.rev ctx). 

Lemma no_lets_from_nil : forall k n, no_lets_from [] k n.
Proof.
  intros k n; rewrite /no_lets_from; apply all_vars_true.
  intros k' n'; rewrite /no_let.
  destruct Nat.ltb; simpl => //.
  rewrite nth_error_nil //.
Qed.

Lemma no_lets_ctx_from_nil k Δ : no_lets_ctx_from [] k Δ.
Proof.
  red.
  generalize 0.
  induction Δ using rev_ind; [constructor|].
  rewrite List.rev_app_distr. simpl. constructor.
  simpl. rewrite /test_decl. rewrite !no_lets_from_nil.
  destruct x as [na [?|] ?]; simpl; auto.
  now rewrite no_lets_from_nil.
  apply IHΔ.
Qed.


Lemma smash_context_app_def Γ na b ty :
  smash_context [] (Γ ++ [{| decl_name := na; decl_body := Some b; decl_type := ty |}]) =
  smash_context [] (subst_context [b] 0 Γ).
Proof.
  now rewrite smash_context_app smash_context_acc /= subst_empty lift0_id lift0_context /=
    subst_context_nil app_nil_r (smash_context_subst []).
Qed.

Lemma smash_context_app_ass Γ na ty :
  smash_context [] (Γ ++ [{| decl_name := na; decl_body := None; decl_type := ty |}]) =
  smash_context [] Γ ++ [{| decl_name := na; decl_body := None; decl_type := ty |}].
Proof.
  now rewrite smash_context_app smash_context_acc /= subst_context_lift_id.
Qed.

Lemma lift_context_add k k' n Γ : lift_context (k + k') n Γ = lift_context k n (lift_context k' n Γ).
Proof.
  induction Γ => //.
  rewrite !lift_context_snoc IHΓ; f_equal.
  destruct a as [na [b|] ty]; rewrite /lift_decl /map_decl /=; simpl; f_equal;
  autorewrite with len; rewrite simpl_lift //; try lia.
Qed.

Lemma distr_lift_subst_context_rec n k s Γ k' : lift_context n (k' + k) (subst_context s k' Γ) =
  subst_context (map (lift n k) s) k' (lift_context n (#|s| + k + k') Γ).
Proof.
  rewrite !lift_context_alt !subst_context_alt.
  rewrite !mapi_compose.
  apply mapi_ext.
  intros n' x.
  rewrite /lift_decl /subst_decl !compose_map_decl.
  apply map_decl_ext => y. autorewrite with len.
  replace (Nat.pred #|Γ| - n' + (#|s| + k + k'))
    with ((Nat.pred #|Γ| - n' + k') + #|s| + k) by lia.
  rewrite -distr_lift_subst_rec. f_equal. lia.
Qed.

Lemma subst_context_lift_id Γ k : subst_context [tRel 0] k (lift_context 1 (S k) Γ) = Γ.
Proof.
  rewrite subst_context_alt lift_context_alt.
  rewrite mapi_compose.
  replace Γ with (mapi (fun k x => x) Γ) at 2.
  2:unfold mapi; generalize 0; induction Γ; simpl; intros; auto; congruence.
  apply mapi_ext.
  autorewrite with len.
  intros n [? [?|] ?]; unfold lift_decl, subst_decl, map_decl; simpl.
  generalize (Nat.pred #|Γ| - n).
  intros. 
  now rewrite !Nat.add_succ_r !subst_rel0_lift_id.
  now rewrite !Nat.add_succ_r !subst_rel0_lift_id.
Qed.

Lemma no_lets_from_ext Γ n  k Γ' t : 
  assumption_context Γ' ->
  no_lets_from Γ (n + (#|Γ'| + k)) t ->
  no_lets_from (Γ ,,, Γ') (n + k) t.
Proof.
  intros ass. unfold no_lets_from in *.
  intros allv.
  replace (n + (#|Γ'| + k)) with (#|Γ'| + (n + k)) in allv by lia.
  rewrite -(all_vars_eq_k (fun k' n => no_let Γ k' n) _ _ #|Γ'|) //.
  intros. unfold no_let.
  destruct (Nat.ltb_spec n0 (#|Γ'| + k0)) => /=.
  destruct (Nat.ltb_spec n0 k0) => /= //.
  rewrite nth_error_app_lt. lia.
  destruct nth_error eqn:E => //.
  eapply PCUICParallelReductionConfluence.nth_error_assumption_context in ass; eauto.
  simpl. now rewrite ass.
  destruct (Nat.ltb_spec n0 k0) => /= //.
  lia.
  rewrite nth_error_app_ge. lia.
  now replace (n0 - k0 - #|Γ'|) with (n0 - (#|Γ'| + k0)) by lia.
Qed.

Lemma no_lets_from_ext_left Γ k Γ' t : 
  assumption_context Γ' ->
  no_lets_from Γ k t ->
  no_lets_from (Γ' ,,, Γ) k t.
Proof.
  intros ass. unfold no_lets_from in *.
  eapply all_vars_impl.
  intros k' n. unfold no_let.
  elim: Nat.ltb_spec => /= // Hk'.
  destruct nth_error eqn:eq => /= //;
  destruct (nth_error (Γ' ,,, Γ)) eqn:eq' => /= //.
  rewrite nth_error_app_lt in eq'. eapply nth_error_Some_length in eq; lia.
  now rewrite eq in eq'; noconf eq'.
  move=> _. eapply nth_error_None in eq.
  rewrite nth_error_app_ge in eq' => //.
  eapply nth_error_assumption_context in eq'; eauto.
  now rewrite eq'.
Qed.

Lemma no_lets_ctx_from_ext Γ k Γ' Δ : 
  assumption_context Γ' ->
  no_lets_ctx_from Γ (#|Γ'| + k) Δ ->
  no_lets_ctx_from (Γ ,,, Γ') k Δ.
Proof.
  rewrite /no_lets_ctx_from.
  intros ass a. eapply Alli_impl; eauto.
  simpl; intros.
  unfold test_decl in *.
  apply /andP. move/andP: H; intuition auto.
  now eapply no_lets_from_ext.
  destruct (decl_body x); simpl in * => //.
  now eapply no_lets_from_ext.
Qed.

Lemma option_all_map f g x : option_all f (option_map g x) = option_all (f ∘ g) x.
Proof.
  destruct x; reflexivity.
Qed.

Lemma test_decl_map_decl f g x : test_decl f (map_decl g x) = test_decl (f ∘ g) x.
Proof.
  now rewrite /test_decl /map_decl /= option_all_map.
Qed.

Lemma option_all_ext f g x : f =1 g -> option_all f x = option_all g x.
Proof.
  move=> Hf; destruct x; simpl => //; rewrite Hf; reflexivity.
Qed.

Lemma test_decl_eq f g x : f =1 g -> test_decl f x = test_decl g x.
Proof.
  intros Hf; rewrite /test_decl (Hf (decl_type x)) (option_all_ext f g) //.
Qed.


Lemma option_all_impl (f g : term -> bool) x : (forall x, f x -> g x) -> option_all f x -> option_all g x.
Proof.
  move=> Hf; destruct x; simpl => //; apply Hf.
Qed.

Lemma test_decl_impl (f g : term -> bool) x : (forall x, f x -> g x) -> test_decl f x -> test_decl g x.
Proof.
  intros Hf; rewrite /test_decl.
  move/andP=> [Hd Hb].
  apply/andP; split; eauto.
  eapply option_all_impl; eauto.
Qed.

Lemma no_lets_from_lift Γ k n t : 
  no_lets_from Γ k t -> no_lets_from Γ (k + n) (lift n k t).
Proof.
  intros Hs.
  apply all_vars_lift; auto.
  - clear; intros n k' k.
    unfold no_let.
    destruct (Nat.ltb_spec n k) => /= //; try lia.
    move=> _ Hb.
    destruct (Nat.ltb_spec (k' + n) (k' + k)) => /= //; try lia.
    now replace (k' + n - (k' + k)) with (n - k) by lia.
  - clear. intros n k' k.
    intros Hn _; unfold no_let.
    destruct (Nat.ltb_spec n (k' + k)) => /= //; try lia.
Qed.

Lemma no_lets_from_subst Γ s n t : 
  forallb (no_lets_from Γ 0) s ->
  no_lets_from Γ (#|s| + n) t -> no_lets_from Γ n (subst s n t).
Proof.
  intros Hs.
  apply all_vars_subst; auto.
  - clear; intros n k' k.
    unfold no_let.
    destruct (Nat.ltb_spec n k) => /= //; try lia.
    move=> _ Hb.
    destruct (Nat.ltb_spec (k' + n) (k' + k)) => /= //; try lia.
    now replace (k' + n - (k' + k)) with (n - k) by lia.
  - clear. intros n k' k.
    intros Hn _; unfold no_let.
    destruct (Nat.ltb_spec n (k' + k)) => /= //; try lia.
  - clear; intros n k.
    intros kn snk. unfold no_let.
    destruct (Nat.ltb_spec n (#|s| + k)) => /= //; try lia.
    destruct (Nat.ltb_spec (n - #|s|) k) => /= //; try lia.
    now replace (n - (#|s| + k)) with (n - #|s| - k) by lia.
  - clear; intros n k.
    intros nk. unfold no_let.
    destruct (Nat.ltb_spec n (#|s| + k)) => /= //; try lia.
    destruct (Nat.ltb_spec n k) => /= //; try lia.
Qed.

Lemma no_lets_ctx_from_subst Γ k s Δ : 
  forallb (no_lets_from Γ 0) s ->
  no_lets_ctx_from Γ (#|s| + k) Δ ->
  no_lets_ctx_from Γ k (subst_context s k Δ).
Proof.
  intros hs.
  unfold no_lets_ctx_from.
  rewrite -subst_telescope_subst_context.
  rewrite /subst_telescope. intros a.
  eapply (fst (Alli_mapi _ _ _)).
  eapply Alli_impl; eauto.
  simpl; intros n x.
  rewrite test_decl_map_decl.
  apply test_decl_impl => t.
  clear -hs.
  replace (n + (#|s| + k)) with (#|s| + (n + k)) by lia.
  rewrite (Nat.add_comm k n).
  generalize (n+k). intros n'. 
  now eapply no_lets_from_subst.
Qed.

Lemma no_lets_from_lift_ctx Γ n k t : 
  #|Γ| = n ->
  no_lets_from Γ k (lift n k t).
Proof.
  intros Hn. eapply all_vars_lift'.
  intros. unfold no_let.
  elim: Nat.leb_spec => // Hs /=.
  elim: Nat.ltb_spec => // /= _.
  subst n.
  destruct nth_error eqn:eq.
  eapply nth_error_Some_length in eq. lia.
  now simpl.
  elim: Nat.ltb_spec => // Hs' /=. lia.
Qed.  

Lemma assumption_context_app_inv Γ Δ : assumption_context Γ -> assumption_context Δ ->  
  assumption_context (Γ ++ Δ).
Proof.
  induction 1; try constructor; auto.
Qed.

Lemma expand_lets_no_let Γ k t : 
  no_lets_from (smash_context [] Γ) k (expand_lets_k Γ k t).
Proof.
  unfold expand_lets_k.
  eapply no_lets_from_subst.
  - induction Γ as [|[na [b|] ty] Γ'] using ctx_length_rev_ind; simpl; auto.
    rewrite smash_context_app_def.
    rewrite extended_subst_app /= !subst_empty lift0_id lift0_context.
    rewrite forallb_app. apply /andP. split; auto.
    2:{ simpl. rewrite andb_true_r.
        apply no_lets_from_lift_ctx.
        now  autorewrite with len. }
    eapply H. now autorewrite with len.
    rewrite smash_context_app_ass /=.
    rewrite extended_subst_app /= subst_context_lift_id forallb_app /= andb_true_r.
    apply/andP; split. specialize (H Γ' ltac:(reflexivity)).
    solve_all. eapply no_lets_from_ext_left in H. eapply H. repeat constructor.
    unfold no_let.
    elim: Nat.ltb_spec => // /= _.
    destruct nth_error eqn:eq => //.
    eapply nth_error_assumption_context in eq => /=. now rewrite eq.
    eapply assumption_context_app_inv. apply smash_context_assumption_context; constructor.
    repeat constructor.
  - autorewrite with len. rewrite Nat.add_comm.
    eapply no_lets_from_lift_ctx. now autorewrite with len.
Qed.

Lemma expand_lets_ctx_no_let Γ k Δ : 
  no_lets_ctx_from (smash_context [] Γ) k (expand_lets_k_ctx Γ k Δ).
Proof.
  induction Γ in k, Δ |- *.
  - unfold expand_lets_k_ctx.
    simpl context_assumptions. rewrite ?lift0_context. simpl; rewrite !subst0_context.
    apply no_lets_ctx_from_nil.
    
  - destruct a as [na [b|] ty].
    rewrite /expand_lets_k_ctx /=.
    autorewrite with len.
    rewrite (subst_app_context_gen [_]). simpl.
    rewrite ->( subst_app_context_gen [subst0 (extended_subst Γ 0) (lift  (context_assumptions Γ) #|Γ| b)] (extended_subst Γ 0)).
    simpl.
    rewrite (Nat.add_succ_r k #|Γ|).
    rewrite /expand_lets_k_ctx in IHΓ.
    specialize (IHΓ (S k)).
    eapply (no_lets_ctx_from_subst _ _ [_] _) in IHΓ.
    rewrite Nat.add_1_r.
    eapply IHΓ. simpl.
    now rewrite expand_lets_no_let.

    simpl.    
    rewrite smash_context_acc /= /map_decl /=.
    rewrite ->( subst_app_context_gen [tRel 0] (extended_subst Γ 1)).
    simpl.
    rewrite (lift_context_add 1 _).
    rewrite (lift_extended_subst _ 1).
    epose proof  (distr_lift_subst_context_rec 1 0 (extended_subst Γ 0) _ (k + 1)).
    autorewrite with len in H. 
    replace (#|Γ| + (k + 1)) with (k + S #|Γ|) in H by lia.
    rewrite <- H. clear H. rewrite Nat.add_1_r.
    rewrite subst_context_lift_id.
    rewrite /expand_lets_k_ctx in IHΓ.
    rewrite Nat.add_succ_r.
    specialize (IHΓ (S k) Δ).
    unshelve eapply (no_lets_ctx_from_ext _ k [_] _ _) in IHΓ. 3:eapply IHΓ.
    repeat constructor.
Qed.

Lemma subst_context_no_lets_from Γ k Δ :
  no_lets_ctx_from (smash_context [] Γ) 0 Δ ->
  no_lets_ctx_from Δ k (subst_context (List.rev (to_extended_list_k Γ k)) 0 Δ).
Proof.
Admitted.

Lemma no_lets_from_lift' Γ k n t : 
  no_lets_from Γ k t -> no_lets_from Γ k (lift n (k + #|Γ|) t).
Proof.
  eapply all_vars_lift''. clear; unfold no_let. intros n k' k le.
  destruct (Nat.ltb_spec n k) => /= //; try lia.
  elim: Nat.ltb_spec => /= //; try lia.
  move=> lek.
  destruct nth_error eqn:eq. eapply nth_error_Some_length in eq. lia.
  simpl.
  elim eq': nth_error.
  eapply nth_error_Some_length in eq' => //. lia.
  simpl. auto.
Qed.

Require Import PCUICSigmaCalculus.

Hint Rewrite reln_length : len.

Lemma map_subst_extended_subst Γ k : 
  map (subst0 (List.rev (to_extended_list_k Γ k))) (extended_subst Γ 0) = 
  all_rels Γ k 0.
Proof.
  unfold to_extended_list_k.
  
  induction Γ in k |- *; simpl; auto.
  destruct a as [na [b|] ty]; simpl.
  f_equal. autorewrite with len.
  rewrite lift0_id.
  rewrite distr_subst. autorewrite with len.
  rewrite simpl_subst_k. now autorewrite with len. 
  rewrite IHΓ. now rewrite Nat.add_1_r.
  rewrite IHΓ. now rewrite Nat.add_1_r.
  rewrite nth_error_rev. autorewrite with len => /= //. simpl; lia.
  autorewrite with len. simpl.
  rewrite Nat.sub_succ. rewrite List.rev_involutive.
  change (0 - 0) with 0. rewrite Nat.sub_0_r.
  f_equal.
  rewrite reln_acc nth_error_app_ge; autorewrite with len => //.
  simpl. now rewrite Nat.sub_diag /=.
  rewrite -IHΓ. simpl.
  rewrite reln_acc List.rev_app_distr /=. 
  rewrite (map_subst_app_decomp [tRel k]).
  simpl. rewrite lift_extended_subst.
  rewrite map_map_compose. apply map_ext.
  intros x. f_equal. now rewrite Nat.add_1_r.
  autorewrite with len. simpl.
  rewrite simpl_subst // lift0_id //.
Qed.

Lemma subst_ext_list_ext_subst Γ k' k t :
  subst (List.rev (to_extended_list_k Γ k)) k'
    (subst (extended_subst Γ 0) k'
      (lift (context_assumptions Γ) (k' + #|Γ|) t)) =
  subst (all_rels Γ k 0) k' t.
Proof.
  epose proof (distr_subst_rec _ _ _ 0 _).
  rewrite Nat.add_0_r in H. rewrite -> H. clear H.
  autorewrite with len.
  rewrite simpl_subst_k. now autorewrite with len. 
  now rewrite map_subst_extended_subst.
Qed.

Lemma expand_lets_ctx_o_lets Γ k k' Δ :
  subst_context (List.rev (to_extended_list_k Γ k)) k' (expand_lets_k_ctx Γ k' Δ) = 
  subst_context (all_rels Γ k 0) k' Δ.
Proof.
  revert k k'; induction Δ using rev_ind; simpl; auto.
  intros k k'; rewrite expand_lets_k_ctx_decl /map_decl /=.
  rewrite !subst_context_app /=.
  simpl; unfold app_context.
  f_equal. specialize (IHΔ k (S k')). simpl in IHΔ.
  rewrite -IHΔ.
  destruct x; simpl.
  destruct decl_body; simpl in * => //.
  unfold subst_context, fold_context; simpl.
  f_equal.
  unfold expand_lets_k, subst_context => /=. 
  unfold map_decl; simpl. unfold map_decl. simpl. f_equal.
  destruct (decl_body x); simpl. f_equal.
  now rewrite subst_ext_list_ext_subst. auto.
  now rewrite subst_ext_list_ext_subst.
Qed.

Lemma no_lets_subst_all_rels Γ k k' Δ :
  no_lets_ctx_from Γ k' Δ ->
  closedn_ctx (#|Γ| + k') Δ ->
  subst_context (all_rels Γ k 0) k' Δ = Δ.
Proof.
  intros nolet cl.
  revert k k' nolet cl.
  induction Δ using rev_ind; simpl; auto; intros.
  rewrite subst_context_app. unfold app_context; f_equal.
  simpl. rewrite (IHΔ k (S k')). admit. admit.
  auto.
  rewrite subst_context_snoc /= subst_context_nil /= /snoc.
  f_equal.
  destruct x as [na [b|] ty]; rewrite /subst_decl /map_decl /=.
  f_equal. f_equal.
  rewrite closedn_ctx_app in cl. move/andP: cl => [clb clΓ].
  simpl in clb. rewrite /id andb_true_r /closed_decl /= in clb.
  move/andP: clb =>  [clb clty].
Admitted.


Lemma expand_lets_subst_lift Γ k k' Δ :
  no_lets_ctx_from (smash_context [] Γ) k Δ ->
  no_lets_ctx_from Γ (k + k')  (subst_context (List.rev (to_extended_list_k Γ k')) 0 Δ).
Proof.
Admitted.

(* 
Lemma expand_lets_no_lets Γ k Δ :
  no_lets_ctx_from (smash_context [] Γ) 0 Δ ->
  expand_lets_k_ctx Γ k (subst_context (List.rev (to_extended_list Γ k)) 0 Δ) = 
  lift_context k 0 Δ. 
    
Admitted. *)

Lemma expand_lets_k_ctx_subst_id' Γ k Δ : 
  closedn_ctx #|Γ| Δ -> 
  expand_lets_k_ctx Γ k (subst_context (List.rev (to_extended_list_k Γ k)) 0 
    (expand_lets_ctx Γ Δ)) = expand_lets_k_ctx Γ k (lift_context k 0 Δ).
Proof.
  intros clΔ.
  pose proof (expand_lets_ctx_no_let Γ 0 Δ).
  eapply (expand_lets_subst_lift _ _ k) in X. simpl in X.
  rewrite expand_lets_ctx_o_lets in X |- *.
  rewrite no_lets_subst_all_rels. 2:now rewrite Nat.add_0_r. admit.
  unfold expand_lets_k_ctx at 2.

  rewrite lift_c  


Admitted.
(* 

  induction Γ in k, Δ |- *; intros clΔ.
  - simpl to_extended_list_k; simpl List.rev.
     rewrite !subst0_context /= ?lift0_context /=. unfold expand_lets_k_ctx.
     simpl context_assumptions. rewrite ?lift0_context. simpl; rewrite !subst0_context.
     rewrite lift0_context. now rewrite closed_ctx_lift.
  - destruct a as [na [b|] ty].
    rewrite /expand_lets_k_ctx /=.
    autorewrite with len. simpl to_extended_list_k.
    rewrite Nat.add_1_r; change  (S k) with (1 + k); rewrite reln_lift.
    rewrite (subst_app_context_gen [_]). simpl.
    rewrite ->( subst_app_context_gen [subst0 (extended_subst Γ 0) (lift  (context_assumptions Γ) #|Γ| b)] (extended_subst Γ 0)).
    simpl. simpl in clΔ.
    rewrite /expand_lets_k_ctx in IHΓ.
    simpl. f_equal.
    specialize (IHΓ (S k)). simpl in IHΓ.
    rewrite Nat.add_1_r Nat.add_succ_r. 
Admitted. *)

Lemma on_constructor_inst_pars_indices {cf:checker_flags} Σ ind u mdecl idecl cshape cdecl Γ pars parsubst : 
  wf Σ.1 -> 
  declared_inductive Σ.1 mdecl ind idecl ->
  on_inductive (lift_typing typing) (Σ.1, ind_universes mdecl) (inductive_mind ind) mdecl ->
  forall (oib : on_ind_body (lift_typing typing) (Σ.1, ind_universes mdecl) (inductive_mind ind) mdecl 
           (inductive_ind ind) idecl)
        (onc : on_constructor (lift_typing typing) (Σ.1, PCUICAst.ind_universes mdecl)
          mdecl (inductive_ind ind) idecl (ind_indices oib) cdecl cshape), 
  consistent_instance_ext Σ (ind_universes mdecl) u ->
  spine_subst Σ Γ pars parsubst (subst_instance_context u (ind_params mdecl)) ->
  ∑ inst,
  spine_subst Σ
          (Γ ,,, subst_context parsubst 0 (subst_context (ind_subst mdecl ind u) #|ind_params mdecl|
            (subst_instance_context u (cshape_args cshape))))
          (map (subst parsubst #|cshape_args cshape|)
            (map (subst (ind_subst mdecl ind u) (#|cshape_args cshape| + #|ind_params mdecl|))
              (map (subst_instance_constr u) (cshape_indices cshape))))
          inst
          (lift_context #|cshape_args cshape| 0
          (subst_context parsubst 0 (subst_instance_context u (ind_indices oib)))). 
Proof.
  move=> wfΣ declm oi oib onc cext sp.
  destruct (on_constructor_inst Σ ind u mdecl idecl _ cdecl wfΣ declm oi oib onc) as [wfl [inst sp']]; auto.
  rewrite !subst_instance_context_app in sp'.
  eapply spine_subst_app_inv in sp' as [spl spr]; auto.
  rewrite (spine_subst_extended_subst spl) in spr.
  rewrite subst_context_map_subst_expand_lets in spr; try now autorewrite with len.
  rewrite subst_instance_to_extended_list_k in spr.
  2:now autorewrite with len.
  rewrite lift_context_subst_context.
  rewrite -app_context_assoc in spr.
  eapply spine_subst_subst_first in spr; eauto.
  2:eapply subslet_inds; eauto.
  autorewrite with len in spr.
  rewrite subst_context_app in spr.
  rewrite closed_ctx_subst in spr.
  admit.
  rewrite (closed_ctx_subst(inds (inductive_mind ind) u (ind_bodies mdecl)) _ (subst_context (List.rev _) _ _)) in spr.
  admit. 
  autorewrite with len in spr.
  eapply spine_subst_weaken in spr.
  3:eapply (spine_dom_wf _ _ _ _ _ sp); eauto. 2:eauto.
  rewrite app_context_assoc in spr.
  eapply spine_subst_subst in spr; eauto. 2:eapply sp.
  autorewrite with len in spr.
  rewrite {4}(spine_subst_extended_subst sp) in spr.
  rewrite subst_context_map_subst_expand_lets_k in spr; try now autorewrite with len.
  rewrite List.rev_length. now rewrite -(context_subst_length2 sp).
  rewrite expand_lets_k_ctx_subst_id' in spr. autorewrite with len. admit.
  rewrite -subst_context_map_subst_expand_lets_k in spr; try autorewrite with len.
  rewrite (context_subst_length2 sp). now autorewrite with len.
  rewrite -(spine_subst_extended_subst sp) in spr.
  eexists. eauto.
Admitted.

Definition R_ind_universes  {cf:checker_flags} (Σ : global_env_ext) ind n i i' :=
  R_global_instance Σ (eq_universe (global_ext_constraints Σ))
    (leq_universe (global_ext_constraints Σ)) (IndRef ind) n i i'.

Lemma mkApps_ind_typing_spine {cf:checker_flags} Σ Γ Γ' ind i
  inst ind' i' args args' : 
  wf Σ.1 ->
  wf_local Σ Γ ->
  isWfArity_or_Type Σ Γ (it_mkProd_or_LetIn Γ' (mkApps (tInd ind i) args)) ->
  typing_spine Σ Γ (it_mkProd_or_LetIn Γ' (mkApps (tInd ind i) args)) inst 
    (mkApps (tInd ind' i') args') ->
  ∑ instsubst, (make_context_subst (List.rev Γ') inst [] = Some instsubst) *
  (#|inst| = context_assumptions Γ' /\ ind = ind' /\ R_ind_universes Σ ind #|args| i i') *
  All2 (fun par par' => Σ ;;; Γ |- par = par') (map (subst0 instsubst) args) args' *
  (subslet Σ Γ instsubst Γ').
Proof.
  intros wfΣ wfΓ; revert args args' ind i ind' i' inst.
  revert Γ'. refine (ctx_length_rev_ind _ _ _); simpl.
  - intros args args' ind i ind' i' inst wat Hsp.
    depelim Hsp.
    eapply invert_cumul_ind_l in c as [i'' [args'' [? ?]]]; auto.
    eapply red_mkApps_tInd in r as [? [eq ?]]; auto. solve_discr.
    exists nil.
    intuition auto. clear i0.
    revert args' a. clear -b wfΣ wfΓ. induction b; intros args' H; depelim H; constructor.
    rewrite subst_empty.
    transitivity y; auto. symmetry.
    now eapply red_conv. now eauto.
    eapply invert_cumul_prod_r in c as [? [? [? [[? ?] ?]]]]; auto.
    eapply red_mkApps_tInd in r as [? [eq ?]]; auto. now solve_discr.
  - intros d Γ' IH args args' ind i ind' i' inst wat Hsp.
    rewrite it_mkProd_or_LetIn_app in Hsp.
    destruct d as [na [b|] ty]; simpl in *; rewrite /mkProd_or_LetIn /= in Hsp.
    + rewrite context_assumptions_app /= Nat.add_0_r.
      eapply typing_spine_letin_inv in Hsp; auto.
      rewrite /subst1 subst_it_mkProd_or_LetIn /= in Hsp.
      specialize (IH (subst_context [b] 0 Γ')).
      forward IH by rewrite subst_context_length; lia.
      rewrite subst_mkApps Nat.add_0_r in Hsp.
      specialize (IH (map (subst [b] #|Γ'|) args) args' ind i ind' i' inst).
      forward IH. {
        move: wat; rewrite it_mkProd_or_LetIn_app /= /mkProd_or_LetIn /= => wat.
        eapply isWAT_tLetIn_red in wat; auto.
        now rewrite /subst1 subst_it_mkProd_or_LetIn subst_mkApps Nat.add_0_r
        in wat. }
      rewrite context_assumptions_subst in IH.
      intuition auto.
      destruct X as [isub [[[Hisub Hinst] Hargs] Hs]].
      eexists. intuition auto.
      eapply make_context_subst_spec in Hisub.
      eapply make_context_subst_spec_inv.
      rewrite List.rev_app_distr. simpl.
      rewrite List.rev_involutive.
      eapply (context_subst_subst [{| decl_name := na; decl_body := Some b;  decl_type := ty |}] [] [b] Γ').
      rewrite -{2}  (subst_empty 0 b). eapply context_subst_def. constructor.
      now rewrite List.rev_involutive in Hisub.
      now autorewrite with len in H2.
      rewrite map_map_compose in Hargs.
      assert (map (subst0 isub ∘ subst [b] #|Γ'|) args = map (subst0 (isub ++ [b])) args) as <-.
      { eapply map_ext => x. simpl.
        assert(#|Γ'| = #|isub|).
        { apply make_context_subst_spec in Hisub.
          apply context_subst_length in Hisub.
          now rewrite List.rev_involutive subst_context_length in Hisub. }
        rewrite H0.
        now rewrite -(subst_app_simpl isub [b] 0). }
      exact Hargs. 
      eapply subslet_app; eauto. rewrite -{1}(subst_empty 0 b). repeat constructor.
      rewrite !subst_empty.
      rewrite it_mkProd_or_LetIn_app /= /mkProd_or_LetIn /= in wat.
      now eapply isWAT_tLetIn_dom in wat.
    + rewrite context_assumptions_app /=.
      pose proof (typing_spine_WAT_concl Hsp).
      depelim Hsp.
      eapply invert_cumul_prod_l in c as [? [? [? [[? ?] ?]]]]; auto.
      eapply red_mkApps_tInd in r as [? [eq ?]]; auto. now solve_discr.
      eapply cumul_Prod_inv in c as [conva cumulB].
      eapply (substitution_cumul0 _ _ _ _ _ _ hd) in cumulB; auto.
      rewrite /subst1 subst_it_mkProd_or_LetIn /= in cumulB.
      specialize (IH (subst_context [hd] 0 Γ')).
      forward IH by rewrite subst_context_length; lia.
      specialize (IH (map (subst [hd] #|Γ'|) args) args' ind i ind' i' tl). all:auto.
      have isWATs: isWfArity_or_Type Σ Γ
      (it_mkProd_or_LetIn (subst_context [hd] 0 Γ')
          (mkApps (tInd ind i) (map (subst [hd] #|Γ'|) args))). {
        move: wat; rewrite it_mkProd_or_LetIn_app /= /mkProd_or_LetIn /= => wat.
        eapply isWAT_tProd in wat; auto. destruct wat as [isty wat].
        epose proof (isWAT_subst wfΣ (Γ:=Γ) (Δ:=[vass na ty])).
        forward X0. constructor; auto.
        specialize (X0 (it_mkProd_or_LetIn Γ' (mkApps (tInd ind i) args)) [hd]).
        forward X0. constructor. constructor. rewrite subst_empty; auto.
        eapply isWAT_tProd in i0; auto. destruct i0. 
        eapply type_Cumul with A; auto. now eapply conv_cumul.
        now rewrite /subst1 subst_it_mkProd_or_LetIn subst_mkApps Nat.add_0_r
        in X0. }
      rewrite subst_mkApps Nat.add_0_r in cumulB. simpl in *. 
      rewrite context_assumptions_subst in IH.
      eapply typing_spine_strengthen in Hsp.
      3:eapply cumulB. all:eauto.
      intuition auto.
      destruct X1 as [isub [[[Hisub [Htl [Hind Hu]]] Hargs] Hs]].
      exists (isub ++ [hd])%list. rewrite List.rev_app_distr.
      autorewrite with len in Hu.
      intuition auto. 2:lia.
      * apply make_context_subst_spec_inv.
        apply make_context_subst_spec in Hisub.
        rewrite List.rev_app_distr !List.rev_involutive in Hisub |- *.
        eapply (context_subst_subst [{| decl_name := na; decl_body := None; decl_type := ty |}] [hd] [hd] Γ'); auto.
        eapply (context_subst_ass _ [] []). constructor.
      * assert (map (subst0 isub ∘ subst [hd] #|Γ'|) args = map (subst0 (isub ++ [hd])) args) as <-.
      { eapply map_ext => x. simpl.
        assert(#|Γ'| = #|isub|).
        { apply make_context_subst_spec in Hisub.
          apply context_subst_length in Hisub.
          now rewrite List.rev_involutive subst_context_length in Hisub. }
        rewrite H.
        now rewrite -(subst_app_simpl isub [hd] 0). }
        now rewrite map_map_compose in Hargs.
      * eapply subslet_app; auto.
        constructor. constructor. rewrite subst_empty.
        rewrite it_mkProd_or_LetIn_app /= /mkProd_or_LetIn /= in wat.
        eapply isWAT_tProd in wat as [Hty _]; auto.
        eapply type_Cumul; eauto. now eapply conv_cumul.
Qed.

Lemma wf_cofixpoint_typing_spine {cf:checker_flags} (Σ : global_env_ext) Γ ind u mfix idx d args args' : 
  wf Σ.1 -> wf_local Σ Γ ->
  wf_cofixpoint Σ.1 mfix ->
  nth_error mfix idx = Some d ->
  isWfArity_or_Type Σ Γ (dtype d) ->
  typing_spine Σ Γ (dtype d) args (mkApps (tInd ind u) args') ->
  check_recursivity_kind Σ (inductive_mind ind) CoFinite.
Proof.
  intros wfΣ wfΓ wfcofix Hnth wat sp.
  apply wf_cofixpoint_all in wfcofix.
  destruct wfcofix as [mind [cr allfix]].
  eapply nth_error_all in allfix; eauto.
  simpl in allfix.
  destruct allfix as [ctx [i [u' [args'' eqty]]]].
  rewrite {}eqty in sp wat.
  eapply mkApps_ind_typing_spine in sp; auto.
  destruct sp as [instsub [[[makes [Hargs [Hind Hu]]] subs] subsl]].
  now subst ind.
Qed.

Lemma Construct_Ind_ind_eq {cf:checker_flags} {Σ} (wfΣ : wf Σ.1):
  forall {Γ n i args u i' args' u' mdecl idecl cdecl},
  Σ ;;; Γ |- mkApps (tConstruct i n u) args : mkApps (tInd i' u') args' ->
  forall (Hdecl : declared_constructor Σ.1 mdecl idecl (i, n) cdecl),
  let '(onind, oib, existT cshape (hnth, onc)) := on_declared_constructor wfΣ Hdecl in
  (i = i') * 
  (* Universe instances match *)
  R_ind_universes Σ i (context_assumptions (ind_params mdecl) + #|cshape_indices cshape|) u u' *
  consistent_instance_ext Σ (ind_universes mdecl) u' *    
  (#|args| = (ind_npars mdecl + context_assumptions cshape.(cshape_args))%nat) *
  ∑ parsubst argsubst parsubst' argsubst',
    let parctx := (subst_instance_context u (ind_params mdecl)) in
    let parctx' := (subst_instance_context u' (ind_params mdecl)) in
    let argctx := (subst_context parsubst 0
    ((subst_context (inds (inductive_mind i) u mdecl.(ind_bodies)) #|ind_params mdecl|
    (subst_instance_context u cshape.(cshape_args))))) in
    let argctx2 := (subst_context parsubst' 0
    ((subst_context (inds (inductive_mind i) u' mdecl.(ind_bodies)) #|ind_params mdecl|
    (subst_instance_context u' cshape.(cshape_args))))) in
    let argctx' := (subst_context parsubst' 0 (subst_instance_context u' oib.(ind_indices))) in
    
    spine_subst Σ Γ (firstn (ind_npars mdecl) args) parsubst parctx *
    spine_subst Σ Γ (firstn (ind_npars mdecl) args') parsubst' parctx' *
    spine_subst Σ Γ (skipn (ind_npars mdecl) args) argsubst argctx *
    spine_subst Σ Γ (skipn (ind_npars mdecl) args')  argsubst' argctx' *

    ∑ s, type_local_ctx (lift_typing typing) Σ Γ argctx2 s *
    (** Parameters match *)
    (All2 (fun par par' => Σ ;;; Γ |- par = par') 
      (firstn mdecl.(ind_npars) args) 
      (firstn mdecl.(ind_npars) args') * 

    (** Indices match *)
    All2 (fun par par' => Σ ;;; Γ |- par = par') 
      (map (subst0 (argsubst ++ parsubst) ∘ 
      subst (inds (inductive_mind i) u mdecl.(ind_bodies)) (#|cshape.(cshape_args)| + #|ind_params mdecl|)
      ∘ (subst_instance_constr u)) 
        cshape.(cshape_indices))
      (skipn mdecl.(ind_npars) args')).

Proof.
  intros Γ n i args u i' args' u' mdecl idecl cdecl h declc.
  unfold on_declared_constructor.
  destruct (on_declared_constructor _ declc). destruct s as [? [_ onc]].
  unshelve epose proof (env_prop_typing _ _ validity _ _ _ _ _ h) as vi'; eauto using typing_wf_local.
  eapply inversion_mkApps in h; auto.
  destruct h as [T [hC hs]].
  apply inversion_Construct in hC
    as [mdecl' [idecl' [cdecl' [hΓ [isdecl [const htc]]]]]]; auto.
  assert (vty:=declared_constructor_valid_ty _ _ _ _ _ _ _ _ wfΣ hΓ isdecl const). 
  eapply typing_spine_strengthen in hs. 3:eapply htc. all:eauto.
  destruct (declared_constructor_inj isdecl declc) as [? [? ?]].
  subst mdecl' idecl' cdecl'. clear isdecl.
  destruct p as [onmind onind]. clear onc.
  destruct declc as [decli declc].
  remember (on_declared_inductive wfΣ decli). clear onmind onind.
  destruct p.
  rename o into onmind. rename o0 into onind.
  destruct declared_constructor_inv as [cshape [_ onc]].
  simpl in onc. unfold on_declared_inductive in Heqp.
  injection Heqp. intros indeq _. 
  move: onc Heqp. rewrite -indeq.
  intros onc Heqp. clear Heqp. simpl in onc.
  pose proof (on_constructor_inst _ _ _ _ _ _ _ wfΣ decli onmind onind onc const).
  destruct onc as [argslength conclhead cshape_eq [cs' t] cargs cinds]; simpl.
  simpl in *. 
  unfold type_of_constructor in hs. simpl in hs.
  unfold cdecl_type in cshape_eq.
  rewrite cshape_eq in hs.  
  rewrite !subst_instance_constr_it_mkProd_or_LetIn in hs.
  rewrite !subst_it_mkProd_or_LetIn subst_instance_context_length Nat.add_0_r in hs.
  rewrite subst_instance_constr_mkApps subst_mkApps subst_instance_context_length in hs.
  assert (Hind : inductive_ind i < #|ind_bodies mdecl|).
  { red in decli. destruct decli. clear -e.
    now eapply nth_error_Some_length in e. }
  rewrite (subst_inds_concl_head i) in hs => //.
  rewrite -it_mkProd_or_LetIn_app in hs.
  assert(ind_npars mdecl = PCUICAst.context_assumptions (ind_params mdecl)).
  { now pose (onNpars _ _ _ _ onmind). }
  assert (closed_ctx (ind_params mdecl)).
  { destruct onmind.
    red in onParams. now apply closed_wf_local in onParams. }
  eapply mkApps_ind_typing_spine in hs as [isubst [[[Hisubst [Hargslen [Hi Hu]]] Hargs] Hs]]; auto.
  subst i'.
  eapply (isWAT_mkApps_Ind wfΣ decli) in vi' as (parsubst & argsubst & (spars & sargs) & cons) => //.
  unfold on_declared_inductive in sargs. simpl in sargs. rewrite -indeq in sargs. clear indeq.
  split=> //. split=> //.
  split; auto. split => //.
  now autorewrite with len in Hu.
  now rewrite Hargslen context_assumptions_app !context_assumptions_subst !subst_instance_context_assumptions; lia.

  exists (skipn #|cshape.(cshape_args)| isubst), (firstn #|cshape.(cshape_args)| isubst).
  apply make_context_subst_spec in Hisubst.
  move: Hisubst.
  rewrite List.rev_involutive.
  move/context_subst_app.
  rewrite !subst_context_length !subst_instance_context_length.
  rewrite context_assumptions_subst subst_instance_context_assumptions -H.
  move=>  [argsub parsub].
  rewrite closed_ctx_subst in parsub.
  now rewrite closedn_subst_instance_context.
  eapply subslet_app_inv in Hs.
  move: Hs. autorewrite with len. intuition auto.
  rewrite closed_ctx_subst in a0 => //.
  now rewrite closedn_subst_instance_context.

  (*rewrite -Heqp in spars sargs. simpl in *. clear Heqp. *)
  exists parsubst, argsubst.
  assert(wfar : wf_local Σ
  (Γ ,,, subst_instance_context u' (arities_context (ind_bodies mdecl)))).
  { eapply weaken_wf_local => //.
    eapply wf_local_instantiate => //; destruct decli; eauto.
    eapply wf_arities_context => //; eauto. }
  assert(wfpars : wf_local Σ (subst_instance_context u (ind_params mdecl))).
    { eapply on_minductive_wf_params => //; eauto. }
      
  intuition auto; try split; auto.
  - apply weaken_wf_local => //.
  - pose proof (subslet_length a0). rewrite subst_instance_context_length in H1.
    rewrite -H1 -subst_app_context.
    eapply (substitution_wf_local _ _ (subst_instance_context u (arities_context (ind_bodies mdecl) ,,, ind_params mdecl))); eauto.
    rewrite subst_instance_context_app; eapply subslet_app; eauto.
    now rewrite closed_ctx_subst ?closedn_subst_instance_context.
    eapply (weaken_subslet _ _ _ _ []) => //.
    now eapply subslet_inds; eauto.
    rewrite -app_context_assoc.
    eapply weaken_wf_local => //.
    rewrite -subst_instance_context_app. 
    apply a.
  - exists (subst_instance_univ u' (cshape_sort cshape)). split.
    move/onParams: onmind. rewrite /on_context.
    pose proof (wf_local_instantiate Σ (InductiveDecl mdecl) (ind_params mdecl) u').
    move=> H'. eapply X in H'; eauto.
    2:destruct decli; eauto.
    clear -wfar wfpars wfΣ hΓ cons decli t cargs sargs H0 H' a spars a0.
    eapply (subst_type_local_ctx _ _ [] 
      (subst_context (inds (inductive_mind i) u' (ind_bodies mdecl)) 0 (subst_instance_context u' (ind_params mdecl)))) => //.
    simpl. eapply weaken_wf_local => //.
    rewrite closed_ctx_subst => //.
    now rewrite closedn_subst_instance_context.
    simpl. rewrite -(subst_instance_context_length u' (ind_params mdecl)).
    eapply (subst_type_local_ctx _ _ _ (subst_instance_context u' (arities_context (ind_bodies mdecl)))) => //.
    eapply weaken_wf_local => //.
    rewrite -app_context_assoc.
    eapply weaken_type_local_ctx => //.
    rewrite -subst_instance_context_app.
    eapply type_local_ctx_instantiate => //; destruct decli; eauto.
    eapply (weaken_subslet _ _ _ _ []) => //.
    now eapply subslet_inds; eauto.
    rewrite closed_ctx_subst ?closedn_subst_instance_context. auto.
    apply spars.
    
    move: (All2_firstn  _ _ _ _ _ mdecl.(ind_npars) Hargs).
    move: (All2_skipn  _ _ _ _ _ mdecl.(ind_npars) Hargs).
    clear Hargs.
    rewrite !map_map_compose !map_app.
    rewrite -map_map_compose.
    rewrite (firstn_app_left _ 0).
    { rewrite !map_length to_extended_list_k_length. lia. }
    rewrite /= app_nil_r.
    rewrite skipn_all_app_eq.
    autorewrite with len.  lia.
    rewrite !map_map_compose.
    assert (#|cshape.(cshape_args)| <= #|isubst|).
    apply context_subst_length in argsub.
    autorewrite with len in argsub.
    now apply firstn_length_le_inv.

    rewrite -(firstn_skipn #|cshape.(cshape_args)| isubst).
    rewrite -[map _ (to_extended_list_k _ _)]
               (map_map_compose _ _ _ (subst_instance_constr u)
                              (fun x => subst _ _ (subst _ _ x))).
    rewrite subst_instance_to_extended_list_k.
    rewrite -[map _ (to_extended_list_k _ _)]map_map_compose. 
    rewrite -to_extended_list_k_map_subst.
    rewrite subst_instance_context_length. lia.
    rewrite map_subst_app_to_extended_list_k.
    rewrite firstn_length_le => //.
    
    erewrite subst_to_extended_list_k.
    rewrite map_lift0. split. eauto.
    rewrite firstn_skipn. rewrite firstn_skipn in All2_skipn.
    now rewrite firstn_skipn.

    apply make_context_subst_spec_inv. now rewrite List.rev_involutive.

  - rewrite it_mkProd_or_LetIn_app.
    right. unfold type_of_constructor in vty.
    rewrite cshape_eq in vty. move: vty.
    rewrite !subst_instance_constr_it_mkProd_or_LetIn.
    rewrite !subst_it_mkProd_or_LetIn subst_instance_context_length Nat.add_0_r.
    rewrite subst_instance_constr_mkApps subst_mkApps subst_instance_context_length.
    rewrite subst_inds_concl_head. all:simpl; auto.
Qed.

Notation "⋆" := ltac:(solve [pcuic]) (only parsing).

Lemma build_branches_type_red {cf:checker_flags} (p p' : term) (ind : inductive)
	(mdecl : PCUICAst.mutual_inductive_body)
    (idecl : PCUICAst.one_inductive_body) (pars : list term) 
    (u : Instance.t) (brtys : list (nat × term)) Σ Γ :
  wf Σ ->
  red1 Σ Γ p p' ->
  map_option_out (build_branches_type ind mdecl idecl pars u p) = Some brtys ->
  ∑ brtys' : list (nat × term),
    map_option_out (build_branches_type ind mdecl idecl pars u p') =
    Some brtys' × All2 (on_Trel_eq (red1 Σ Γ) snd fst) brtys brtys'.
Proof.
  intros wfΣ redp.
  unfold build_branches_type.
  unfold mapi.
  generalize 0 at 3 6.
  induction (ind_ctors idecl) in brtys |- *. simpl.
  intros _ [= <-]. exists []; split; auto.
  simpl. intros n.
  destruct a. destruct p0.
  destruct (instantiate_params (subst_instance_context u (PCUICAst.ind_params mdecl))
  pars
  (subst0 (inds (inductive_mind ind) u (PCUICAst.ind_bodies mdecl))
     (subst_instance_constr u t))).
  destruct decompose_prod_assum.
  destruct chop.
  destruct map_option_out eqn:Heq.
  specialize (IHl _ _ Heq).
  destruct IHl. intros [= <-].
  exists ((n0,
  PCUICAst.it_mkProd_or_LetIn c
    (mkApps (lift0 #|c| p')
       (l1 ++
        [mkApps (tConstruct ind n u) (l0 ++ PCUICAst.to_extended_list c)]))) :: x).
  destruct p0 as [l' r'].
  rewrite {}l'.
  split; auto.
  constructor; auto. simpl. split; auto.
  2:discriminate. clear Heq.
  2:discriminate.
  eapply red1_it_mkProd_or_LetIn.
  eapply red1_mkApps_f.
  eapply (weakening_red1 Σ Γ [] c) => //.
Qed.

Lemma conv_decls_fix_context_gen {cf:checker_flags} Σ Γ mfix mfix1 :
  wf Σ.1 ->
  All2 (fun d d' => conv Σ Γ d.(dtype) d'.(dtype)) mfix mfix1 ->
  forall Γ' Γ'',
  conv_context Σ (Γ ,,, Γ') (Γ ,,, Γ'') ->
  context_relation (fun Δ Δ' : PCUICAst.context => conv_decls Σ (Γ ,,, Γ' ,,, Δ) (Γ ,,, Γ'' ,,, Δ'))
    (fix_context_gen #|Γ'| mfix) (fix_context_gen #|Γ''| mfix1).
Proof.    
  intros wfΣ.
  induction 1. constructor. simpl.
  intros Γ' Γ'' convctx.

  assert(conv_decls Σ (Γ ,,, Γ' ,,, []) (Γ ,,, Γ'' ,,, [])
  (PCUICAst.vass (dname x) (lift0 #|Γ'| (dtype x)))
  (PCUICAst.vass (dname y) (lift0 #|Γ''| (dtype y)))).
  { constructor.
  pose proof (context_relation_length _ _ _  convctx).
  rewrite !app_length in H. assert(#|Γ'|  = #|Γ''|) by lia.
  rewrite -H0.
  apply (weakening_conv _ _ []); auto. }

  apply context_relation_app_inv. rewrite !List.rev_length; autorewrite with len.
  now apply All2_length in X.
  constructor => //.
  eapply (context_relation_impl (P:= (fun Δ Δ' : PCUICAst.context =>
  conv_decls Σ
  (Γ ,,, (vass (dname x) (lift0 #|Γ'| (dtype x)) :: Γ') ,,, Δ)
  (Γ ,,, (vass (dname y) (lift0 #|Γ''| (dtype y)) :: Γ'') ,,, Δ')))).
  intros. now rewrite !app_context_assoc.
  eapply IHX. simpl.
  constructor => //.
Qed.

Lemma conv_decls_fix_context {cf:checker_flags} Σ Γ mfix mfix1 :
  wf Σ.1 ->
  All2 (fun d d' => conv Σ Γ d.(dtype) d'.(dtype)) mfix mfix1 ->
  context_relation (fun Δ Δ' : PCUICAst.context => conv_decls Σ (Γ ,,, Δ) (Γ ,,, Δ'))
    (fix_context mfix) (fix_context mfix1).
Proof.    
  intros wfΣ a.
  apply (conv_decls_fix_context_gen _ _  _ _ wfΣ a [] []).
  apply conv_ctx_refl. 
Qed.

Lemma isLambda_red1 Σ Γ b b' : isLambda b -> red1 Σ Γ b b' -> isLambda b'.
Proof.
  destruct b; simpl; try discriminate.
  intros _ red.
  depelim red.
  symmetry in H; apply mkApps_Fix_spec in H. simpl in H. intuition.
  constructor. constructor.
Qed.

Lemma Case_Construct_ind_eq {cf:checker_flags} Σ (hΣ : ∥ wf Σ.1 ∥) 
  {Γ ind ind' npar pred i u brs args} :
  (∑ T, Σ ;;; Γ |- tCase (ind, npar) pred (mkApps (tConstruct ind' i u) args) brs : T) ->
  ind = ind'.
Proof.
  destruct hΣ as [wΣ].
  intros [A h].
  apply inversion_Case in h as ih ; auto.
  destruct ih
    as [uni [args' [mdecl [idecl [pty [indctx [pctx [ps [btys [? [? [? [? [ht0 [? ?]]]]]]]]]]]]]]].
    pose proof ht0 as typec.
    eapply inversion_mkApps in typec as [A' [tyc tyargs]]; auto.
    eapply (inversion_Construct Σ wΣ) in tyc as [mdecl' [idecl' [cdecl' [wfl [declc [Hu tyc]]]]]].
    epose proof (PCUICInductiveInversion.Construct_Ind_ind_eq _ ht0 declc); eauto.
    destruct on_declared_constructor as [[onmind oib] [cs [? ?]]].
    simpl in *.
    intuition auto.
Qed.

Lemma Proj_Constuct_ind_eq {cf:checker_flags} Σ (hΣ : ∥ wf Σ.1 ∥) {Γ i i' pars narg c u l} :
  (∑ T, Σ ;;; Γ |- tProj (i, pars, narg) (mkApps (tConstruct i' c u) l) : T) ->
  i = i'.
Proof.
  destruct hΣ as [wΣ].
  intros [T h].
  apply inversion_Proj in h ; auto.
  destruct h as [uni [mdecl [idecl [pdecl [args' [? [hc [? ?]]]]]]]].
  pose proof hc as typec.
  eapply inversion_mkApps in typec as [A' [tyc tyargs]]; auto.
  eapply (inversion_Construct Σ wΣ) in tyc as [mdecl' [idecl' [cdecl' [wfl [declc [Hu tyc]]]]]].
  epose proof (PCUICInductiveInversion.Construct_Ind_ind_eq _ hc declc); eauto.
  destruct on_declared_constructor as [[onmind oib] [cs [? ?]]].
  simpl in *.
  intuition auto.
Qed.

Lemma Proj_Constuct_projargs {cf:checker_flags} Σ (hΣ : ∥ wf Σ.1 ∥) {Γ i pars narg c u l} :
  (∑ T, Σ ;;; Γ |- tProj (i, pars, narg) (mkApps (tConstruct i c u) l) : T) ->
  pars + narg < #|l|.
Proof.
  destruct hΣ as [wΣ].
  intros [T h].
  apply inversion_Proj in h ; auto.
  destruct h as [uni [mdecl [idecl [pdecl [args' [? [hc [? ?]]]]]]]].
  clear c0.
  pose proof hc as typec.
  eapply inversion_mkApps in typec as [A' [tyc tyargs]]; auto.
  eapply (inversion_Construct Σ wΣ) in tyc as [mdecl' [idecl' [cdecl' [wfl [declc [Hu tyc]]]]]].
  pose proof (declared_inductive_inj d.p1 declc.p1) as [? ?]; subst mdecl' idecl'.
  set (declc' :=  
   (conj (let (x, _) := d in x) declc.p2) : declared_constructor Σ.1  mdecl idecl (i, c) cdecl').
  epose proof (PCUICInductiveInversion.Construct_Ind_ind_eq _ hc declc'); eauto.
  simpl in X.
  destruct (on_declared_projection wΣ d).
  set (oib := declared_inductive_inv _ _ _ _) in *.
  simpl in *. 
  set (foo := (All2_nth_error_Some _ _ _ _)) in X.
  clearbody foo.
  destruct (ind_cshapes oib) as [|? []] eqn:Heq; try contradiction.
  destruct foo as [t' [ntht' onc]].
  destruct c; simpl in ntht'; try discriminate.
  noconf ntht'.
  2:{ rewrite nth_error_nil in ntht'. discriminate. }
  destruct X as [[[_ Ru] Hl] Hpars]. rewrite Hl.
  destruct d as [decli [nthp parseq]].
  simpl in *. rewrite parseq.
  destruct y as [[_ onps] onp]. lia.
Qed.

Ltac unf_env := 
  change PCUICEnvironment.it_mkProd_or_LetIn with it_mkProd_or_LetIn in *; 
  change PCUICEnvironment.to_extended_list_k with to_extended_list_k in *; 
  change PCUICEnvironment.ind_params with ind_params in *.

Derive Signature for positive_cstr.


Lemma positive_cstr_it_mkProd_or_LetIn mdecl i Γ Δ t : 
  positive_cstr mdecl i Γ (it_mkProd_or_LetIn Δ t) ->
  All_local_env (fun Δ ty _ => positive_cstr_arg mdecl i (Γ ,,, Δ) ty)
    (smash_context [] Δ) *
  positive_cstr mdecl i (Γ ,,, smash_context [] Δ) (expand_lets Δ t).
Proof.
  revert Γ t; unfold expand_lets, expand_lets_k;
   induction Δ as [|[na [b|] ty] Δ] using ctx_length_rev_ind; intros Γ t.
  - simpl; intuition auto. now rewrite subst_empty lift0_id.
  - rewrite it_mkProd_or_LetIn_app /=; intros H; depelim H.
    solve_discr. rewrite smash_context_app_def.
    rewrite /subst1 subst_it_mkProd_or_LetIn in H.
    specialize (X (subst_context [b] 0 Δ) ltac:(autorewrite with len; lia) _ _ H).
    simpl; autorewrite with len in X |- *.
    destruct X; split; auto. simpl.
    rewrite extended_subst_app /= !subst_empty !lift0_id lift0_context.
    rewrite subst_app_simpl; autorewrite with len => /=.
    simpl.
    epose proof (distr_lift_subst_rec _ [b] (context_assumptions Δ) #|Δ| 0).
    rewrite !Nat.add_0_r in H0. now erewrite <- H0.
  - rewrite it_mkProd_or_LetIn_app /=; intros H; depelim H.
    solve_discr. rewrite smash_context_app_ass.
    specialize (X Δ ltac:(autorewrite with len; lia) _ _ H).
    simpl; autorewrite with len in X |- *.
    destruct X; split; auto. simpl.
    eapply All_local_env_app_inv; split.
    constructor; auto.
    eapply (All_local_env_impl _ _ _ a). intros; auto.
    now rewrite app_context_assoc. simpl.
    rewrite extended_subst_app /=.
    rewrite subst_app_simpl; autorewrite with len => /=.
    simpl.
    rewrite subst_context_lift_id.
    rewrite Nat.add_comm Nat.add_1_r subst_reli_lift_id. 
    apply context_assumptions_length_bound. now rewrite app_context_assoc.
Qed.

Lemma closedn_expand_lets k (Γ : context) t : 
  closedn (k + context_assumptions Γ) (expand_lets Γ t) -> 
  closedn (k + #|Γ|) t.
Proof.
  revert k t.
  induction Γ as [|[na [b|] ty] Γ] using ctx_length_rev_ind; intros k t; simpl; auto.
  - now rewrite /expand_lets /expand_lets_k subst_empty lift0_id.
  - autorewrite with len.
    rewrite !expand_lets_vdef.
    specialize (H (subst_context [b] 0 Γ) ltac:(autorewrite with len; lia)).
    autorewrite with len in H.
    intros cl.
    specialize (H _ _ cl).
    eapply (closedn_subst_eq' _ k) in H.
    simpl in *. now rewrite Nat.add_assoc.
  - autorewrite with len.
    rewrite !expand_lets_vass. simpl. intros cl.
    specialize (H Γ ltac:(autorewrite with len; lia)).
    rewrite (Nat.add_comm _ 1) Nat.add_assoc in cl.
    now rewrite (Nat.add_comm _ 1) Nat.add_assoc.
Qed.

Lemma expand_lets_it_mkProd_or_LetIn Γ Δ k t : 
  expand_lets_k Γ k (it_mkProd_or_LetIn Δ t) = 
  it_mkProd_or_LetIn (expand_lets_k_ctx Γ k Δ) (expand_lets_k Γ (k + #|Δ|) t).
Proof.
  revert k; induction Δ as [|[na [b|] ty] Δ] using ctx_length_rev_ind; simpl; auto; intros k.
  - now rewrite /expand_lets_k_ctx /= Nat.add_0_r.
  - rewrite it_mkProd_or_LetIn_app /= /mkProd_or_LetIn /=.
    rewrite /expand_lets_ctx expand_lets_k_ctx_decl /= it_mkProd_or_LetIn_app.
    simpl. f_equal. rewrite app_length /=.
    simpl. rewrite Nat.add_1_r Nat.add_succ_r.
    now rewrite -(H Δ ltac:(lia) (S k)).
  - rewrite it_mkProd_or_LetIn_app /= /mkProd_or_LetIn /=.
    rewrite /expand_lets_ctx expand_lets_k_ctx_decl /= it_mkProd_or_LetIn_app.
    simpl. f_equal. rewrite app_length /=.
    simpl. rewrite Nat.add_1_r Nat.add_succ_r.
    now rewrite -(H Δ ltac:(lia) (S k)).
Qed.

Lemma expand_lets_k_mkApps Γ k f args : 
  expand_lets_k Γ k (mkApps f args) =
  mkApps (expand_lets_k Γ k f) (map (expand_lets_k Γ k) args).
Proof.
  now rewrite /expand_lets_k lift_mkApps subst_mkApps map_map_compose.
Qed.
Lemma expand_lets_mkApps Γ f args : 
  expand_lets Γ (mkApps f args) =
  mkApps (expand_lets Γ f) (map (expand_lets Γ) args).
Proof.
  now rewrite /expand_lets expand_lets_k_mkApps.
Qed.  
 
Lemma expand_lets_cstr_head k Γ : 
  expand_lets Γ (tRel (k + #|Γ|)) = tRel (k + context_assumptions Γ).
Proof.
  rewrite /expand_lets /expand_lets_k. 
  rewrite lift_rel_ge. lia.
  rewrite subst_rel_gt. autorewrite with len. lia.
  autorewrite with len. lia_f_equal.
Qed.

Lemma positive_cstr_closed_indices {cf:checker_flags} {Σ : global_env_ext} (wfΣ : wf Σ.1):
  forall {i mdecl idecl cdecl ind_indices cs},
  on_constructor (lift_typing typing) (Σ.1, ind_universes mdecl) mdecl i idecl ind_indices cdecl cs -> 
  All (closedn (#|ind_params mdecl| + #|cshape_args cs|)) (cshape_indices cs).
Proof.
  intros.
  pose proof (X.(on_ctype_positive)).
  rewrite X.(cstr_eq) in X0. unf_env.
  rewrite -it_mkProd_or_LetIn_app in X0.
  eapply positive_cstr_it_mkProd_or_LetIn in X0 as [hpars hpos].
  rewrite app_context_nil_l in hpos.
  rewrite expand_lets_mkApps in hpos.
  unfold cstr_concl_head in hpos.
  have subsrel := expand_lets_cstr_head (#|ind_bodies mdecl| - S i) (cshape_args cs  ++ ind_params mdecl).
  rewrite app_length (Nat.add_comm #|(cshape_args cs)|) Nat.add_assoc in subsrel. rewrite {}subsrel in hpos.
  rewrite context_assumptions_app in hpos. depelim hpos; solve_discr.
  simpl in H; noconf H.
  eapply All_map_inv in a.
  eapply All_app in a as [ _ a].
  eapply (All_impl a).
  clear. intros.
  autorewrite with len in H; simpl in H.
  rewrite -context_assumptions_app in H.
  apply (closedn_expand_lets 0) in H => //.
  autorewrite with len in H.
  now rewrite Nat.add_comm.
Qed.

Lemma declared_inductive_lookup_inductive {Σ ind mdecl idecl} :
  declared_inductive Σ mdecl ind idecl ->
  lookup_inductive Σ ind = Some (mdecl, idecl).
Proof.
  rewrite /declared_inductive /lookup_inductive.
  intros []. red in H. now rewrite /lookup_minductive H H0.
Qed.

Lemma constructor_cumulative_indices {cf:checker_flags} {Σ : global_env_ext} (wfΣ : wf Σ.1) :
  forall {ind mdecl idecl cdecl ind_indices cs u u' napp},
  declared_inductive Σ mdecl ind idecl ->
  on_constructor (lift_typing typing) (Σ.1, ind_universes mdecl) mdecl (inductive_ind ind) idecl ind_indices cdecl cs -> 
  R_global_instance Σ (eq_universe Σ) (leq_universe Σ) (IndRef ind) napp u u' ->
  forall Γ pars pars' parsubst parsubst',
  spine_subst Σ Γ pars parsubst (subst_instance_context u (ind_params mdecl)) ->
  spine_subst Σ Γ pars' parsubst' (subst_instance_context u' (ind_params mdecl)) ->  
  All2 (conv Σ Γ) pars pars' ->
  let argctx := 
      (subst_context (ind_subst mdecl ind u) #|ind_params mdecl| (subst_instance_context u (cshape_args cs)))
  in
  let argctx' :=
     (subst_context (ind_subst mdecl ind u') #|ind_params mdecl| (subst_instance_context u' (cshape_args cs)))
  in
  let pargctx := subst_context parsubst 0 argctx in
  let pargctx' := subst_context parsubst' 0 argctx' in
  All2_local_env (fun Γ' _ _ x y => Σ ;;; Γ ,,, Γ' |- x <= y) 
    (smash_context [] pargctx) (smash_context [] pargctx') *
  All2 (conv Σ (Γ ,,, smash_context [] pargctx))
    (map (subst parsubst (context_assumptions (cshape_args cs)))
      (map (expand_lets argctx) (map (subst_instance_constr u) (cshape_indices cs))))
    (map (subst parsubst' (context_assumptions (cshape_args cs)))
      (map (expand_lets argctx') (map (subst_instance_constr u') (cshape_indices cs)))).
Proof.
  intros. move: H0.
  unfold R_global_instance.
  simpl. rewrite (declared_inductive_lookup_inductive H).
  eapply on_declared_inductive in H as [onind oib]; eauto.
  rewrite oib.(ind_arity_eq). 
  rewrite !destArity_it_mkProd_or_LetIn. simpl.
  rewrite app_context_nil_l context_assumptions_app.
  elim: leb_spec_Set => comp.
  destruct ind_variance eqn:indv.
  pose proof (X.(on_ctype_variance)) as respv.
  specialize (respv _ indv).
  simpl in respv.
  unfold respects_variance in respv.
  destruct variance_universes as [[v i] i'] eqn:vu.
  destruct respv as [args idx].
  (* We need to strengthen respects variance to allow arbitrary parameter substitutions *)
  (** Morally, if variance_universes l = v i i' and R_universe_instance_variance l u u' then
      i and i' can be substituted respectively by u and u'.
      The hard part might be to show that (Σ.1, v) can also be turned into Σ by instanciating
      i and i' by u and u'.
  *)
Admitted.

  
Lemma wt_ind_app_variance {cf:checker_flags} {Σ : global_env_ext} {Γ ind u l}:
  wf Σ.1 ->
  isWfArity_or_Type Σ Γ (mkApps (tInd ind u) l) ->
  ∑ mdecl, (lookup_inductive Σ ind = Some mdecl) *
  (global_variance Σ (IndRef ind) #|l| = ind_variance (fst mdecl)).
Proof.
  move=> wfΣ.
  move/isWAT_mkApps_Ind_isType => [s wat].
  red in wat. eapply inversion_mkApps in wat as [ty [Hind Hargs]]; auto.
  eapply inversion_Ind in Hind as [mdecl [idecl [wfΓ [decli [cu cum]]]]]; auto.
  eapply typing_spine_strengthen in Hargs; eauto. clear cum.
  exists (mdecl, idecl).
  assert (lookup_inductive Σ ind = Some (mdecl, idecl)).
  { destruct decli as [decli declmi].
    rewrite /lookup_inductive. red in decli. rewrite /lookup_minductive decli.
    now rewrite declmi. }
  split; auto.
  simpl. rewrite H.
  pose proof decli as decli'.
  eapply on_declared_inductive in decli' as [onmi oni]; auto.
  rewrite oni.(ind_arity_eq) in Hargs |- *.
  rewrite !destArity_it_mkProd_or_LetIn. simpl.
  rewrite app_context_nil_l.
  rewrite !subst_instance_constr_it_mkProd_or_LetIn in Hargs.
  rewrite -it_mkProd_or_LetIn_app in Hargs.
  eapply arity_typing_spine in Hargs; auto.
  destruct Hargs as [[Hl Hleq] ?]. rewrite Hl.
  autorewrite with len. now rewrite context_assumptions_app Nat.leb_refl.
  eapply weaken_wf_local; auto.
  rewrite -[_ ++ _]subst_instance_context_app.
  eapply on_minductive_wf_params_indices_inst; eauto with pcuic.
Qed.
