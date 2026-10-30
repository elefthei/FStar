module CoinductiveRecordInvalid

[@@expect_failure [399]]
[@@coinductive]
type not_a_record =
  | NotARecord

[@@expect_failure [399]]
[@@coinductive]
noeq
type noeq_record = {
  value : int;
}

[@@expect_failure [399]]
[@@coinductive]
unopteq
type unopteq_record = {
  value : int;
}
