module CoinductiveRecordInvalid

[@@expect_failure [401]; coinductive]
type not_a_record =
  | NotARecord

[@@expect_failure [401]; coinductive]
noeq
type noeq_record = {
  value : int;
}

[@@expect_failure [401]; coinductive]
unopteq
type unopteq_record = {
  value : int;
}

[@@expect_failure [401]; coinductive]
let not_a_type : int = 0
