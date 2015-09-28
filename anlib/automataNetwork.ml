
open Big_int

open PintTypes

type sig_automaton_p = string
type sig_automaton_state = StateId of int | StateLabel of string
type sig_local_state = sig_automaton_p * sig_automaton_state

type automaton_p = string
type automaton_state = int
type local_state = automaton_p * automaton_state

module LSSet = Set.Make (struct type t = local_state let compare = compare end)
module LSMap = Map.Make (struct type t = local_state let compare = compare end)

let lsset_of_list = set_of_list LSSet.empty LSSet.add

type local_transition = (int * (local_state list))

type transition = automaton_p
						* automaton_state
						* automaton_state

let tr_dest (_,_,j) = j

type t = {
	automata: (automaton_p, (sig_automaton_state * automaton_state) list) Hashtbl.t;
	transitions: (local_state, ISet.t) Hashtbl.t;
	conditions: (transition, automaton_state SMap.t) Hashtbl.t;
}

let empty_an ?size:(size=(20,50)) () = {
	automata = Hashtbl.create (fst size);
	transitions = Hashtbl.create (snd size);
	conditions = Hashtbl.create (snd size);
}

let copy_an an = {
	automata = Hashtbl.copy an.automata;
	transitions = Hashtbl.copy an.transitions;
	conditions = Hashtbl.copy an.conditions;
}

let automata_limits an =
	let folder a def lims =
		(a, List.length def - 1)::lims
	in
	Hashtbl.fold folder an.automata []

let automaton_sdomain an a =
	let n = List.length (Hashtbl.find an.automata a)
	in
	Util.srange 0 (n-1)

let get_automaton_state_sig an a i =
	Util.list_lassoc i (Hashtbl.find an.automata a)

let get_automaton_state_id an a sig_i =
	List.assoc sig_i (Hashtbl.find an.automata a)

let string_of_sig_state ?(protect=true) = function
	  StateId i -> string_of_int i
	| StateLabel n -> if protect then "\""^n^"\"" else n

let string_of_astate ?(protect=true) an a i =
	string_of_sig_state ~protect (get_automaton_state_sig an a i)

let string_of_localstate ?(protect=true) an (a,i) =
	(if protect then ("\""^a^"\"") else a)^"="^string_of_astate ~protect an a i

let string_of_localstates an lsset =
	String.concat ", " (List.map (string_of_localstate an) (SMap.bindings lsset))

let string_of_ls (a,i) =
	a^" "^string_of_int i

let string_of_lsset lsset =
	String.concat ", " (List.map string_of_ls (LSSet.elements lsset))


let count_automata an = Hashtbl.length an.automata

let count_local_states an =
	let count a ls_defs c =
		List.length ls_defs + c
	in
	Hashtbl.fold count an.automata 0

let count_states an =
	let count a ls_defs c =
		mult_int_big_int (List.length ls_defs) c
	in
	Hashtbl.fold count an.automata unit_big_int

let count_transitions an =
	Hashtbl.length an.conditions


let has_automaton an name = Hashtbl.mem an.automata name

let declare_automaton an a sigstates =
	assert (not (has_automaton an a));
	let register_sig (sigassoc, i) sig_i =
		Hashtbl.add an.transitions (a,i) ISet.empty;
		(sig_i,i)::sigassoc, i+1
	in
	let sigassoc, _ = List.fold_left register_sig ([], 0) sigstates
	in
	Hashtbl.add an.automata a (List.rev sigassoc)

let declare_transition an a sig_i sig_j sig_conds =
	let i = get_automaton_state_id an a sig_i
	and j = get_automaton_state_id an a sig_j
	and conds = List.fold_left
					(fun cond (b,sig_k) ->
							let k = get_automaton_state_id an b sig_k
							in
							SMap.add b k cond) SMap.empty sig_conds
	in
	let trs = Hashtbl.find an.transitions (a,i)
	in
	Hashtbl.replace an.transitions (a,i) (ISet.add j trs);
	Hashtbl.add an.conditions (a, i, j) conds

let an_replace_trconditions an tr conds =
	while Hashtbl.mem an.conditions tr do
		Hashtbl.remove an.conditions tr
	done;
	match conds with
	  [] -> (match tr with (a,i,j) ->
	  	let js = Hashtbl.find an.transitions (a,i)
		in
		let js = ISet.remove j js
		in
		Hashtbl.replace an.transitions (a,i) js)
	| _ ->
		let conds = List.sort_uniq (SMap.compare compare) conds
		in
		List.iter (Hashtbl.add an.conditions tr) conds

let partial an sset =
	let an' = empty_an ~size:(SSet.cardinal sset, 50) ()
	in
	let match_lsset =
		SMap.for_all (fun a _ -> SSet.mem a sset)
	in
	let register_localstate a (sigs,i) =
		Hashtbl.add an'.transitions (a,i) ISet.empty
	in
	let register_automaton a def =
		if SSet.mem a sset then
			(Hashtbl.add an'.automata a def;
			List.iter (register_localstate a) def)
	and register_condition (a,i,j) lsset =
		if SSet.mem a sset && match_lsset lsset then
			let trs = Hashtbl.find an'.transitions (a,i)
			in
			(Hashtbl.replace an'.transitions (a,i) (ISet.add j trs);
			Hashtbl.add an'.conditions (a,i,j) lsset)
	in
	Hashtbl.iter register_automaton an.automata ;
	Hashtbl.iter register_condition an.conditions;
	an'

let simplify an =
	let conditions = Hashtbl.create (Hashtbl.length an.conditions / 2)
	and sd = Hashtbl.fold (fun a def -> SMap.add a (List.map snd def))
				an.automata SMap.empty
	in
	let simplify_transition a i j =
		let vs = Hashtbl.find_all an.conditions (a,i,j)
		in
		let vs = ValSet.simplify sd vs
		in
		List.iter (Hashtbl.add conditions (a,i,j)) vs
	in
	let simplify_transitions (a,i) js =
		ISet.iter (simplify_transition a i) js
	in
	Hashtbl.iter simplify_transitions an.transitions;
	{an with conditions = conditions}


let constants an =
	let get_constants a is cset =
		if List.for_all (fun (_,i) ->
			ISet.is_empty (Hashtbl.find	an.transitions (a,i))) is then
				SSet.add a cset else cset
	in
	Hashtbl.fold get_constants an.automata SSet.empty

let remove_constants an ctx =
	let cset = constants an
	and ukn = SMap.fold (fun a is uset ->
							if ISet.cardinal is > 1 then SSet.add a uset
								else uset) ctx SSet.empty
	in
	let cset = SSet.diff cset ukn
	in
	let ctx' = Util.smap_remove_keys ctx cset
	and an' = empty_an ~size:(Hashtbl.length an.automata - SSet.cardinal cset, 50) ()
	in
	let match_lsset lsset =
		(* ensure that the conditions match with the constant automata init value *)
		SSet.for_all (fun a ->
			try ISet.mem (SMap.find a lsset) (SMap.find a ctx)
			with Not_found -> true) cset
	in
	let register_localstate a (sigs,i) =
		Hashtbl.add an'.transitions (a,i) ISet.empty
	in
	let register_automaton a def =
		if not (SSet.mem a cset) then
			(Hashtbl.add an'.automata a def;
			List.iter (register_localstate a) def)
	and register_condition (a,i,j) lsset =
		if match_lsset lsset then
			let trs = Hashtbl.find an'.transitions (a,i)
			and lsset = Util.smap_remove_keys lsset cset
			in
			(Hashtbl.replace an'.transitions (a,i) (ISet.add j trs);
			Hashtbl.add an'.conditions (a,i,j) lsset)
	in
	Hashtbl.iter register_automaton an.automata ;
	Hashtbl.iter register_condition an.conditions;
	an', ctx'

let string_of_state an s =
	String.concat ", " (List.map (string_of_localstate an) (SMap.bindings s))

let resolve_siglocalstates an =
	List.map (fun (a,sig_i) -> (a,get_automaton_state_id an a sig_i))
(**
	Context
**)

let ctx_of_siglocalstates ?(complete=false) an sls =
	let fold_localstate ctx (a,sig_i) =
		let i = get_automaton_state_id an a sig_i
		in
		Ph_types.ctx_add_proc (a,i) ctx
	in
	let ctx = List.fold_left fold_localstate Ph_types.ctx_empty sls
	in
	if complete then
	let complete_ctx a _ ctx =
		if not (SMap.mem a ctx) then
			SMap.add a (ISet.singleton 0) ctx
		else ctx
	in
	Hashtbl.fold complete_ctx an.automata ctx
	else ctx

let ctx_has_localstate = Ph_types.ctx_has_proc

let ctx_of_lsset ps =
	let group (a,i) ctx =
		let is = try SMap.find a ctx with Not_found -> ISet.empty
		in
		let is = ISet.add i is
		in
		SMap.add a is ctx
	in
	LSSet.fold group ps SMap.empty

let lsset_of_ctx ctx =
	let register a is ps =
		let register i ps =
			LSSet.add (a,i) ps
		in
		ISet.fold register is ps
	in
	SMap.fold register ctx LSSet.empty

let lsset_of_state s =
	SMap.fold (fun a i s -> LSSet.add (a,i) s) s LSSet.empty

let is_substate s s' =
	SMap.for_all (fun a i -> try i = SMap.find a s'
					with Not_found -> false) s

let an_compl_ctx an ctx =
	let fold a is ctx =
		let js = automaton_sdomain an a
		in
		let js = ISet.diff js is
		in
		SMap.add a js ctx
	in
	SMap.fold fold ctx SMap.empty

let condition_matches ctx cond =
	let ls_matches a i =
		try ISet.mem i (SMap.find a ctx)
		with Not_found -> false
	in
	SMap.for_all ls_matches cond

