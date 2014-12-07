
open Big_int

open PintTypes
open AutomataNetwork


module BigISet = Set.Make (struct type t = big_int let compare = compare_big_int end);;

let log2 = log 2.

let bits n = int_of_float (ceil (log (float_of_int n) /. log2))

let required_bits_per_automaton an =
	let fold_automata _ states b =
		max (bits (List.length states)) b
	in
	Hashtbl.fold fold_automata an.automata 0

let automata_index an = 
	let fold_automata a _ (i, index) =
		let index = SMap.add a i index
		in
		(i+1, index)
	in
	snd (Hashtbl.fold fold_automata an.automata (0, SMap.empty))

(*
let index_automata aindex =
	let fold a i indexa =
		IMap.add i a indexa 
	in
	SMap.fold fold aindex IMap.empty
*)


let single_sid base i ai =
	shift_left_big_int (big_int_of_int ai) (base*i)

let encode_transitions base aindex an =
	let single_sid = single_sid base
	and prepare_cond (b,j) =
		let id = SMap.find b aindex
		in
		let j = big_int_of_int j
		in
		(fun sid -> extract_big_int sid (base*id) base), eq_big_int j
	in
	let fold_transitions (a,i,j) conds etransitions =
		let id = SMap.find a aindex
		in
		let conds = LSSet.elements conds
		in
		let conds = List.map prepare_cond ((a,i)::conds)
		in
		let precond sid = List.for_all 
				(fun (get_comp, test_comp) -> test_comp (get_comp sid))
					conds
		and shift = single_sid id (j-i)
		in
		(precond, shift)::etransitions
	in
	Hashtbl.fold fold_transitions an.conditions []

let sid_of_state base aindex state =
	let fold a i sid =
		let ai = SMap.find a state
		in
		if ai > 0 then
			let aid = single_sid base i ai
			in
			or_big_int aid sid
		else sid
	in
	SMap.fold fold aindex zero_big_int

module BigHashtbl = Hashtbl.Make(struct
		type t = big_int 
		let equal = eq_big_int 
		let hash = Hashtbl.hash 
end)

let prepare_sts an state =
	let base = required_bits_per_automaton an
	and aindex = automata_index an
	in
	let etrs = encode_transitions base aindex an
	and sid0 = sid_of_state base aindex state
	in
	let next_sids sid =
		let fold_etr sids (precond, shift) =
			if precond sid then
				add_big_int sid shift::sids
			else sids
		in
		List.fold_left fold_etr [] etrs
	in
	sid0, next_sids

let reachable_states an state =
	let sid0, next_sids = prepare_sts an state
	and known = BigHashtbl.create 10240
	in
	let rec explore sid (counter, todo) =
		if BigHashtbl.mem known sid then
			(counter, todo)
		else (
			let counter = succ_big_int counter
			in
			BigHashtbl.add known sid ();
			let nexts = next_sids sid
			in
			let todo = List.fold_left (fun bis bi ->
					if BigHashtbl.mem known bi then bis else BigISet.add bi bis) 
					 	todo nexts
			in
			if BigISet.is_empty todo then
				(counter, todo)
			else (
				let sid = BigISet.choose todo
				in
				let todo = BigISet.remove sid todo
				in
				explore sid (counter, todo)
			)
		)
	in
	fst (explore sid0 (zero_big_int, BigISet.empty)), known

let attractors an state =
	let sid0, next = prepare_sts an state
	and index = BigHashtbl.create 10240
	and lowlink = BigHashtbl.create 10240
	and nid = ref 0
	and stack = ref []
	in
	let rec bsccs v =
		BigHashtbl.add index v !nid;
		BigHashtbl.add lowlink v !nid;
		nid := !nid + 1;
		stack := v::!stack;
		let handle_child sccs w =
			if not(BigHashtbl.mem index w) then (
				let sccs' = bsccs w
				in
				let l_v = BigHashtbl.find lowlink v
				and l_w = BigHashtbl.find lowlink w
				in
				BigHashtbl.replace lowlink v (min l_v l_w);
				sccs' @ sccs
			) else (
				if List.mem w !stack then (
					let l_v = BigHashtbl.find lowlink v
					and i_w = BigHashtbl.find index w
					in
					BigHashtbl.replace lowlink v (min l_v i_w);
				);
				sccs
			)
		in
		let sccs = List.fold_left handle_child [] (next v)
		in
		let rec unroll () =
			match !stack with
			  [] -> failwith "unroll empty stack!"
			| a::q ->
				stack := q;
				if a = v then [a] else (a::unroll ())
		in
		let l_v = BigHashtbl.find lowlink v
		and i_v = BigHashtbl.find index v
		in
		if l_v = i_v then 
			match sccs with 
			  [] -> [unroll ()]
			| _ -> (ignore (unroll()); sccs)
		else sccs
	in
	bsccs sid0


