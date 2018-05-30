(** Reported by Randy Pollack **)

(** Note that this was supposed to fail in the past *)
Require Import Template.Template.

Section foo.
  Variable x : nat.

  Test Quote x.
  Quote Recursively Definition this_should_not_fail_anymore := x.
  Print this_should_not_fail_anymore.
End foo.
