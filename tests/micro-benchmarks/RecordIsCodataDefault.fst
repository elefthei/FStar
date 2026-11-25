module RecordIsCodataDefault

(* Records now carry an internal [is_codata] flag (defaulting to false).
   This checks that every way of introducing a record still behaves as an
   ordinary (inductive) record. *)

open FStar.Tactics.V2

type point = { x : int; y : int }

let p0 : point = { x = 1; y = 2 }
let p1 = { p0 with y = 3 }
let _ = assert (p1.x == 1 /\ p1.y == 3)
let get_x ({ x }) : int = x
let _ = assert (get_x p1 == 1)

(* A record within a mutually inductive block *)
type tree = | Leaf | Node of node
and node = { left : tree; v : nat; right : tree }

let rec size (t:tree) : nat =
  match t with
  | Leaf -> 0
  | Node n -> size n.left + 1 + size n.right

let _ = assert_norm (size (Node { left = Leaf; v = 0; right = Leaf }) == 1)

(* A variant whose constructor carries a record payload *)
type shape = | Circle { radius : nat } | Rect { w : nat; h : nat }

let area (s:shape) : nat =
  match s with
  | Circle { radius } -> radius * radius
  | Rect { w; h } -> w * h

let _ = assert_norm (area (Rect { w = 2; h = 3 }) == 6)

(* Type classes are records too *)
class has_zero (a:Type) = { zero : a }
instance has_zero_int : has_zero int = { zero = 0 }
let _ = assert (zero #int == 0)

(* Reflection still sees the record qualifiers *)
let has_record_qual (nm:string) : Tac bool =
  match lookup_typ (top_env ()) (explode_qn nm) with
  | None -> fail "not found"
  | Some se ->
    List.Tot.existsb (fun q -> RecordType? q) (sigelt_quals se)

let _ = assert True by (guard (has_record_qual (`%point)))
let _ = assert True by (guard (has_record_qual (`%node)))
let _ = assert True by (guard (not (has_record_qual (`%tree))))
