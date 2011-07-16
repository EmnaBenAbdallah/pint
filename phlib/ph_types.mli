(** Process Hiting **)

type metaprocess = string * int (* name * level max *)
type process = string * int (* name * level *)
type sa = int option
type rate = float

type hits = (process, ((process * (rate*sa)) * int)) Hashtbl.t

type ph = metaprocess list * hits

type regulation_sign = Positive | Negative
type regulation = string * int * regulation_sign * string

