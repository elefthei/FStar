module CoinductiveRecord

open FStar.Tactics.V2

(* The [codata] qualifier is currently a purely syntactic marker on
   record types; records declared with it behave like ordinary records. *)

codata
type stream_cell (a:Type) = {
  hd : a;
  tl : nat;
}

let mk (x:int) : stream_cell int = { hd = x; tl = 0 }

let get_hd (s:stream_cell int) : int = s.hd

let upd (s:stream_cell int) : stream_cell int = { s with tl = s.tl + 1 }

let _ = assert (get_hd (mk 42) == 42)
let _ = assert ((upd (mk 1)).tl == 1)

let test_pat (s:stream_cell int) : int =
  match s with
  | { hd = h; tl = _ } -> h

(* Field-name disambiguation by type also works. *)
let typed_access (s:stream_cell bool) = s.hd

noeq
type with_fun = {
  f : int -> int;
  n : int;
}

let wf : with_fun = { f = (fun x -> x + 1); n = 0 }
let _ = assert (wf.f 1 == 2)

let reflect_codata () : Tac unit =
  match lookup_typ (cur_env ()) ["CoinductiveRecord"; "stream_cell"] with
  | Some se ->
    begin match sigelt_quals se with
    | [RecordType (_, _, true)] -> ()
    | _ -> fail "RecordType did not expose the codata flag"
    end
  | None -> fail "stream_cell was not found"

let _ = assert True by (reflect_codata ())

(* The record constructor carries the flag too. *)
let ctor_codata_flag (nm:string) : Tac bool =
  match lookup_typ (top_env ()) (explode_qn nm) with
  | None -> fail ("not found: " ^ nm)
  | Some se ->
    let rec go (qs:list qualifier) : Tac bool =
      match qs with
      | RecordConstructor (_, _, b) :: _ -> b
      | _ :: qs -> go qs
      | [] -> fail ("not a record constructor: " ^ nm)
    in
    go (sigelt_quals se)

let _ = assert True by (guard (ctor_codata_flag (`%Mkstream_cell)))

type plain = { v : int }

let codata_flag (nm:string) : Tac bool =
  match lookup_typ (top_env ()) (explode_qn nm) with
  | None -> fail ("not found: " ^ nm)
  | Some se ->
    let rec go (qs:list qualifier) : Tac bool =
      match qs with
      | RecordType (_, _, b) :: _ -> b
      | _ :: qs -> go qs
      | [] -> fail ("not a record: " ^ nm)
    in
    go (sigelt_quals se)

let _ = assert True by (guard (not (codata_flag (`%plain))))
let _ = assert True by (guard (not (ctor_codata_flag (`%Mkplain))))

(* The qualifier applies to every record in a mutually recursive block. *)
codata
type ping = { pong_of : nat; next_ping : option pong }
and pong = { ping_of : nat }

let _ = assert True by (guard (codata_flag (`%ping)))
let _ = assert True by (guard (codata_flag (`%pong)))
let _ = assert True by (guard (ctor_codata_flag (`%Mkping)))
