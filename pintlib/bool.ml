
type 'a expr = 
	L of 'a | Not of 'a expr | And of ('a expr * 'a expr) | Or of ('a expr * 'a expr)
;;

module type LitType = sig 
	type t
	val to_string : t -> string
end;;

module Manipulator ( Lit : LitType ) =
struct
	module LSet = Set.Make (struct type t = (bool * Lit.t) let compare = compare end)

	let dnf_simplify dnf =
		let rec dnf_simplify = function [] -> [] |
			s1::t -> 
				if List.exists (fun s2 -> LSet.subset s2 s1) t then
					dnf_simplify t
				else
					s1::dnf_simplify t
		in
		let dnf = List.sort (fun s1 s2 -> compare (LSet.cardinal s2) (LSet.cardinal s1)) dnf
		in
		dnf_simplify dnf
	;;

	let dnf expr =
		let rec dnf = function 
			  (Not _ | L _) as l -> l
			| Or (e1, e2) -> Or (dnf e1, dnf e2)
			| And (e1, e2) -> distr (dnf e1, dnf e2) 
		and distr = function 
			  (Or (e1, e2), e) -> Or (distr (e1, e), distr (e2, e))
			| (e, Or (e1, e2)) -> Or (distr (e, e1), distr (e, e2))
			| c -> And c
		and nnf = function (* forward negations to literals *)
			  L _ as l -> l
			| And (e1, e2) -> And (nnf e1, nnf e2)
			| Or (e1, e2) -> Or (nnf e1, nnf e2)
			| Not (And (e1, e2)) -> Or (nnf (Not e1), nnf (Not e2))
			| Not (Or (e1, e2)) -> And (nnf (Not e1), nnf (Not e2))
			| Not (Not e) -> nnf e
			| Not e -> Not (nnf e)
		and to_list = function
			  Or (e1, e2) -> to_list e1 @ to_list e2
			| And (e1, e2) -> [LSet.union (List.hd (to_list e1)) (List.hd (to_list e2))]
			| Not (L x) -> [LSet.singleton (false, x)]
			| L x -> [LSet.singleton (true, x)]
			| _ -> raise (Invalid_argument "dnf.to_list")
		in
		dnf_simplify (to_list (dnf (nnf expr)))
	;;

	let string_of_dnf dnf =
		let lset_to_string lset = LSet.fold (fun (p,x) s -> 
				s^(if p then "" else "~")^Lit.to_string x^";"
			) lset ""
		in
		"("^(String.concat ") V (" (List.map lset_to_string dnf))^")"
	;;

end
;;

