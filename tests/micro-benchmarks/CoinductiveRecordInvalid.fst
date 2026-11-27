module CoinductiveRecordInvalid

(* The [codata] qualifier is only allowed on record type definitions. *)

[@@expect_failure [401]]
codata
type not_a_record =
  | NotARecord

[@@expect_failure [401]]
codata
type record_payload =
  | C { value : int }

[@@expect_failure [401]]
codata
type mixed = { m : int }
and other =
  | Other

[@@expect_failure [401]]
codata noeq
type noeq_record = {
  value : int;
}

[@@expect_failure [401]]
codata unopteq
type unopteq_record = {
  value : int;
}

[@@expect_failure [401]]
codata
let not_a_type : int = 0

[@@expect_failure [401]]
codata
val not_a_type_val : int

[@@expect_failure [401]]
codata
class not_a_class (a:Type) = { meth : a }
