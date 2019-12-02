(* Distributed under the terms of the MIT license.   *)

From MetaCoq.Erasure Require Import EAst.

Fixpoint opt_cases (t : term) :=
  match t with
  | tBox => tBox
  | tRel n => tRel n
  | tVar n => tVar n
  | tEvar n l => tEvar n (List.map opt_cases l)
  | tLambda na t => tLambda na (opt_cases t)
  | tLetIn na t1 t2 => tLetIn na (opt_cases t1) (opt_cases t2)
  | tApp t1 t2 => tApp (opt_cases t1) (opt_cases t2)
  | tConst k => tConst k
  | tConstruct i n => tConstruct i n
  | tCase p tBox ((a, b) :: _) => mkApps b (List.repeat tBox a)
  | tCase p t brs => tCase p (opt_cases t) (List.map (fun '(n, t) => (n, opt_cases t)) brs)
  | tProj p t => tProj p (opt_cases t)
  | tFix mfix id => tFix (List.map (fun d => Build_def term (dname d) (opt_cases (dbody d)) (rarg d)) mfix) id
  | tCoFix mfix id => tCoFix (List.map (fun d => Build_def term (dname d) (opt_cases (dbody d)) (rarg d)) mfix) id
  end.

From Coq Require Import Bool String List Program BinPos Compare_dec Arith Lia.
From MetaCoq.Template Require Import config monad_utils utils BasicAst AstUtils
     UnivSubst Pretty.
From MetaCoq.Checker Require Import uGraph Typing.
From MetaCoq.PCUIC Require Import PCUICAst PCUICAstUtils PCUICInduction
     PCUICLiftSubst PCUICUnivSubst PCUICTyping PCUICNormal PCUICSR
     PCUICGeneration PCUICReflect PCUICEquality PCUICInversion PCUICValidity
     PCUICWeakening PCUICPosition PCUICCumulativity PCUICSafeLemmata PCUICSN TemplateToPCUIC.
From MetaCoq.SafeChecker Require Import PCUICSafeReduce PCUICSafeConversion PCUICSafeChecker SafeTemplateChecker.
From MetaCoq.Erasure Require Import ErasureFunction EPretty.
From MetaCoq.Erasure Require SafeErasureFunction.

Import MonadNotation.

Existing Instance envcheck_monad.
Existing Instance extraction_checker_flags.

Local Open Scope string_scope.

Program Definition run_hnf (p : Ast.program)
  : EnvCheck term :=
  let Σ := List.rev (trans_global (AstUtils.empty_ext p.1)).1 in
  G <- check_wf_env (cf := extraction_checker_flags) Σ ;;
  ret (Monad := envcheck_monad) (@hnf MetaCoq.Template.config.extraction_checker_flags (PCUICAstUtils.empty_ext Σ) _ nil (trans p.2) _).
Next Obligation.
  todo "TODO".
Qed.  
  
Program Definition erase_template_program_check (p : Ast.program)
  : EnvCheck (EAst.global_context * EAst.term) :=
  let Σ := List.rev (trans_global (AstUtils.empty_ext p.1)).1 in
  G <- check_wf_env Σ ;;
  Σ' <- wrap_error (PCUICAstUtils.empty_ext Σ) "erasure of the global context" (erase_global Σ _) ;;
  t <- wrap_error (PCUICAstUtils.empty_ext Σ) ("During erasure of " ++ string_of_term (trans p.2)) (erase (empty_ext Σ) _ nil _ (trans p.2));;
  ret (Monad:=envcheck_monad) (Σ', opt_cases t).

Next Obligation.
  unfold trans_global.
  simpl. unfold wf_ext, empty_ext. simpl.
  unfold on_global_env_ext. destruct H0. constructor.
  split; auto. simpl. todo "on_udecl on empty universe context".
Qed.

Next Obligation.
  unfold trans_global.
  simpl. unfold wf_ext, empty_ext. simpl.
  unfold on_global_env_ext. destruct H0. constructor.
  auto.
Qed.

(** This is a hack to avoid having to handle template polymorphism and make
    erasure fast: we actually admit the proof of wf Σ and never build it. *)

Definition assume_wf_decl {cf : checker_flags} (Σ : global_env_ext) :
  ∥ wf Σ ∥ ->
  ∥ on_udecl Σ.1 Σ.2 ∥ ->
  forall G : universes_graph,
    is_graph_of_uctx G (global_ext_uctx Σ) ->
    forall kn (d : global_decl), EnvCheck (∥ on_global_decl (lift_typing typing) Σ kn d ∥).
Proof.
  intros. apply CorrectDecl. constructor. todo "assumed correct global declaration".
Defined.

Program Fixpoint check_wf_env_only_univs (Σ : global_env)
  : EnvCheck (∑ G, (is_graph_of_uctx G (global_uctx Σ) /\ ∥ wf Σ ∥)) :=
  match Σ with
  | nil => ret (init_graph; _)
  | d :: Σ =>
    G <- check_wf_env_only_univs Σ ;;
    check_fresh d.1 Σ ;;
    let udecl := universes_decl_of_decl d.2 in
    uctx <- check_udecl d.1 Σ _ G.π1 (proj1 G.π2) udecl ;;
    let G' := add_uctx uctx.π1 G.π1 in
    assume_wf_decl (Σ, udecl) _ _ G' _ d.1 d.2 ;;
    match udecl with
        | Monomorphic_ctx _ => ret (G'; _)
        | Polymorphic_ctx _ => ret (G.π1; _)
        | Cumulative_ctx _ => ret (G.π1; _)
        end
    end.
  Next Obligation.
    repeat constructor. apply graph_eq; try reflexivity.
    cbn. symmetry. apply wGraph.VSetProp.singleton_equal_add.
  Qed.
  Next Obligation.
    sq. unfold is_graph_of_uctx, gc_of_uctx; simpl.
    unfold gc_of_uctx in e. simpl in e.
    case_eq (gc_of_constraints (constraints_of_udecl (universes_decl_of_decl g)));
      [|intro HH; rewrite HH in e; discriminate e].
    intros ctrs' Hctrs'. rewrite Hctrs' in *.
    cbn in e. inversion e; subst; clear e.
    unfold global_ext_constraints; simpl.
    rewrite gc_of_constraints_union. rewrite Hctrs'.
    red in i. unfold gc_of_uctx in i; simpl in i.
    case_eq (gc_of_constraints (global_constraints Σ));
      [|intro HH; rewrite HH in i; cbn in i; contradiction i].
    intros Σctrs HΣctrs; rewrite HΣctrs in *; simpl in *.
    subst G. unfold global_ext_levels; simpl. rewrite no_prop_levels_union.
    symmetry; apply add_uctx_make_graph.
  Qed.
  Next Obligation.
    split; sq. 2: constructor; tas.
    unfold is_graph_of_uctx, gc_of_uctx; simpl.
    unfold gc_of_uctx in e. simpl in e.
    case_eq (gc_of_constraints (constraints_of_udecl (universes_decl_of_decl g)));
      [|intro HH; rewrite HH in e; discriminate e].
    intros ctrs' Hctrs'. rewrite Hctrs' in *.
    cbn in e. inversion e; subst; clear e.
    unfold global_ext_constraints; simpl.
    rewrite gc_of_constraints_union.
    assert (eq: monomorphic_constraints_decl g
                = constraints_of_udecl (universes_decl_of_decl g)). {
      destruct g. destruct c, cst_universes; try discriminate; reflexivity.
      destruct m, ind_universes; try discriminate; reflexivity. }
    rewrite eq; clear eq. rewrite Hctrs'.
    red in i. unfold gc_of_uctx in i; simpl in i.
    case_eq (gc_of_constraints (global_constraints Σ));
      [|intro HH; rewrite HH in i; cbn in i; contradiction i].
    intros Σctrs HΣctrs; rewrite HΣctrs in *; simpl in *.
    subst G. unfold global_ext_levels; simpl. rewrite no_prop_levels_union.
    assert (eq: monomorphic_levels_decl g
                = levels_of_udecl (universes_decl_of_decl g)). {
      destruct g. destruct c, cst_universes; try discriminate; reflexivity.
      destruct m, ind_universes; try discriminate; reflexivity. }
    rewrite eq. symmetry; apply add_uctx_make_graph.
  Qed.
  Next Obligation.
    split; sq. 2: constructor; tas.
    unfold global_uctx; simpl.
    assert (eq1: monomorphic_levels_decl g = LevelSet.empty). {
      destruct g. destruct c, cst_universes; try discriminate; reflexivity.
      destruct m, ind_universes; try discriminate; reflexivity. }
    rewrite eq1; clear eq1.
    assert (eq1: monomorphic_constraints_decl g = ConstraintSet.empty). {
      destruct g. destruct c, cst_universes; try discriminate; reflexivity.
      destruct m, ind_universes; try discriminate; reflexivity. }
    rewrite eq1; clear eq1.
    assumption.
  Qed.
  Next Obligation.
    split; sq. 2: constructor; tas.
    unfold global_uctx; simpl.
    assert (eq1: monomorphic_levels_decl g = LevelSet.empty). {
      destruct g. destruct c, cst_universes; try discriminate; reflexivity.
      destruct m, ind_universes; try discriminate; reflexivity. }
    rewrite eq1; clear eq1.
    assert (eq1: monomorphic_constraints_decl g = ConstraintSet.empty). {
      destruct g. destruct c, cst_universes; try discriminate; reflexivity.
      destruct m, ind_universes; try discriminate; reflexivity. }
    rewrite eq1; clear eq1.
    assumption.
  Qed.

Program Definition erase_template_program (p : Ast.program)
  : EnvCheck (EAst.global_context * EAst.term) :=
  let Σ := List.rev (trans_global (AstUtils.empty_ext p.1)).1 in
  G <- check_wf_env_only_univs Σ ;;
  Σ' <- wrap_error (PCUICAstUtils.empty_ext Σ) "erasure of the global context" (SafeErasureFunction.erase_global Σ _) ;;
  t <- wrap_error (PCUICAstUtils.empty_ext Σ) ("During erasure of " ++ string_of_term (trans p.2)) (SafeErasureFunction.erase (empty_ext Σ) _ nil (trans p.2) _);;
  ret (Monad:=envcheck_monad) (Σ', opt_cases t).

Next Obligation.
  unfold trans_global.
  simpl. unfold wf_ext, empty_ext. simpl.
  unfold on_global_env_ext. destruct H0. constructor.
  split; auto. simpl. todo "on_udecl on empty universe context".
Qed.

Next Obligation.
  unfold trans_global.
  simpl. unfold wf_ext, empty_ext. simpl.
  unfold on_global_env_ext. destruct H0. todo "assuming well-typedness".
Qed.

Local Open Scope string_scope.

(** This uses the checker-based erasure *)
Program Definition erase_and_print_template_program_check {cf : checker_flags} (p : Ast.program)
  : string + string :=
  let p := fix_program_universes p in
  match erase_template_program_check p return string + string with
  | CorrectDecl (Σ', t) =>
    inl ("Environment is well-formed and " ++ Pretty.print_term (AstUtils.empty_ext p.1) [] true p.2 ++
         " erases to: " ++ nl ++ EPretty.print_term Σ' [] true false t)
  | EnvError Σ' (AlreadyDeclared id) =>
    inr ("Already declared: " ++ id)
  | EnvError Σ' (IllFormedDecl id e) =>
    inr ("Type error: " ++ PCUICSafeChecker.string_of_type_error Σ' e ++ ", while checking " ++ id)
  end.

(** This uses the retyping-based erasure *)
Program Definition erase_and_print_template_program {cf : checker_flags} (p : Ast.program)
  : string + string :=
  let p := fix_program_universes p in
  match erase_template_program p return string + string with
  | CorrectDecl (Σ', t) =>
    inl ("Environment is well-formed and " ++ Pretty.print_term (AstUtils.empty_ext p.1) [] true p.2 ++
         " erases to: " ++ nl ++ EPretty.print_term Σ' [] true false t)
  | EnvError Σ' (AlreadyDeclared id) =>
    inr ("Already declared: " ++ id)
  | EnvError Σ' (IllFormedDecl id e) =>
    inr ("Type error: " ++ PCUICSafeChecker.string_of_type_error Σ' e ++ ", while checking " ++ id)
  end.

(* Program Definition check_template_program {cf : checker_flags} (p : Ast.program) (ty : Ast.term) *)
(*   : EnvCheck (∥ trans_global (AstUtils.empty_ext (List.rev p.1)) ;;; [] |- trans p.2 : trans ty ∥) := *)
(*   p <- typecheck_program (cf:=cf) ((trans_global (AstUtils.empty_ext p.1)).1, trans p.2) ;; *)
(*   wrap_error "During checking of type constraints" (check p.1 _ _ _ (trans ty));; *)
(*   ret (Monad:=envcheck_monad) _. *)

(* Next Obligation. *)
(*   unfold trans_global. *)
(*   simpl. unfold empty_ext in X. *)
(*   unfold trans_global_decls in X. *)
(*   rewrite <-map_rev in X. *)
(* Qed. *)

(* Program Definition typecheck_template_program' {cf : checker_flags} (p : Ast.program) *)
(*   : EnvCheck (∑ A, ∥ Typing.typing (AstUtils.empty_ext (List.rev p.1)) [] p.2 A ∥) := *)
(*   p <- typecheck_template_program (cf:=cf) p ;; *)
(*   ret (Monad:=envcheck_monad) (p.π1 ; _). *)
