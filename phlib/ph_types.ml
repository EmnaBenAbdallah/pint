(**
 Generic types
 TODO: move to commonlib
**)

module SSet = Set.Make (struct type t = string let compare = compare end);;
module SMap = Map.Make (struct type t = string let compare = compare end);;
module ISet = Set.Make (struct type t = int let compare = compare end);;
module IMap = Map.Make (struct type t = int let compare = compare end);;

let string_of_set string_of_element elements_getter set =
	let content = String.concat ", " 
		(List.map string_of_element (elements_getter set))
	in
	"{ " ^ content ^" }"
;;

let string_of_iset = string_of_set string_of_int ISet.elements
;;
	

(**
 Process Hitting types
**)

type ternary = True | False | Inconc;;
let string_of_ternary = function True -> "True" | False -> "False" | Inconc -> "Inconc";;

type sort = string
type sortidx = int
type process = sort * sortidx (* name * level *)

let string_of_process (a,i) = a^"_"^string_of_int i;;

type rate = (float * int) option

type hits = (process, ((process * rate) * int)) Hashtbl.t

type ph = process list * hits

type regulation_sign = Positive | Negative
(* gene_a * threshold * sign * gene_b *)
type regulation_t = Regulation of (string * int * regulation_sign * string)

(* (a,i) * (b,j) * j' *)
type hit_t = Hit of (process * process * int)

let hitter = function Hit (ai,_,_) -> ai;;
let target = function Hit (_,bj,_) -> bj;;
let bounce = function Hit (_,(b,_),k) -> (b,k);;

let string_of_action = function
	Hit (ai, bj, k) -> string_of_process ai ^"->"^string_of_process bj^" "^string_of_int k
;;


(* STATE *)
let string_of_state s =
	let folder a i str =
		if i <> 0 then
			str ^ (if str <> "" then ";" else "")
			^ string_of_process (a,i)
		else str
	in
	"["^(SMap.fold folder s "")^"]"
;;
let state0 (ps,_) = List.fold_left (fun s (a,_) -> SMap.add a 0 s) SMap.empty ps
;;
let merge_state state =
	let apply state (a,i) =
		SMap.add a i state
	in
	List.fold_left apply state
;;
let state_value state a = SMap.find a state
;;
let list_of_state state =
	let folder a i ls = (a,i)::ls
	in
	SMap.fold folder state []
;;


type match_p = Any | ProcessLevel of process | Process of string | Matching of (process -> bool)

(* Proc level couple set *)
module PCSet = Set.Make (struct type t = (process * process) 
		let compare (ai,bj) (ai',bj') = 
			let order_couple (x,y) =
				if compare x y <= 0 then (x,y) else (y,x)
			in
			let ai,bj = order_couple (ai,bj)
			and ai',bj' = order_couple (ai',bj')
			in
			let c = compare ai ai'
			in
			if c = 0 then compare bj bj' else c
		end)
;;

module PMap = Map.Make (struct type t = process let compare = compare end);;
module PSet = Set.Make (struct type t = process let compare = compare end);;

module ActionSet = Set.Make (struct type t = hit_t let compare = compare end);;
let uniqise_actions actions = 
	let set = List.fold_left (fun set action ->
				ActionSet.add action set) ActionSet.empty actions
	in ActionSet.elements set
;;
let string_of_actions actions =
	"{ "^(String.concat ", " (List.map string_of_action actions))^" }"
;;
let string_of_actionset set = string_of_actions (ActionSet.elements set)
;;
	

let ph_sigma = function (ps,_) -> List.map fst ps
;;
	
type t_directive = {
	mutable default_rate : float option;
	mutable default_sa : int;
	mutable sample : float
};;

let directive = {
	default_rate = None;
	default_sa = 1;
	sample = 1000.0
};;

