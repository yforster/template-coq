Require Import Template.All.

Ltac do_quote A :=
  let k x := exact x in
  run_template_program (tmQuote A) k.

Notation "'⟨' x '⟩'" := (ltac:(do_quote x)).

Goal True.

  let k x := pose x in
  run_template_program (tmQuote nat) k.

Compute (let cNat := ⟨ nat ⟩ in let cId := ⟨ fun (x : nat) => x ⟩ in (cNat, cId) ).

Fail Compute ( ⟨ fun y : nat => x ⟩).
Compute (fun x : nat => ⟨ x ⟩).
