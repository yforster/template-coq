From bedrock Require Export bytestring bytestringtree.
From MetaCoq.Template Require Import MCCompare ReflectEq.

Global Instance reflect_eq_string : ReflectEq Bytestring.t.
Proof.
  unshelve econstructor. exact Bytestring.eqb.
  intros x y.
  pose proof (StringOT.reflect_eq_string x y).
  destruct (Bytestring.eqb x y); econstructor; eauto.
Defined.
