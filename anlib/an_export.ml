
open PintTypes
open AutomataNetwork

type opts = {
	contextual_ptnet: bool;
}

let dump_of_an an ctx = 
	let fold_defs a def_states buf =
		let def_states = List.map fst def_states
		in
		buf ^ 
		"\""^a^"\" ["^(String.concat ", " 
			(List.map string_of_sig_state def_states))^"]\n"
	and fold_tr (a,i,j) cond buf = buf ^
		"\""^a^"\" "^(string_of_astate an a i)^" -> "
			^(string_of_astate an a j) ^
		(if LSSet.is_empty cond then "" else
			(" when "^String.concat " and "
				(List.map (string_of_localstate an) (LSSet.elements cond))))
		^ "\n"
	in
	(Hashtbl.fold fold_defs an.automata "")
	^ "\n" ^
	(Hashtbl.fold fold_tr an.conditions "")


let pep_of_an opts an ctx =
	let idx_of_place places ls =
		try
			(LSMap.find ls places, places)
		with Not_found -> (
			let idx = 1 + LSMap.cardinal places
			in
			let places = LSMap.add ls idx places
			in
			(idx, places)
		)
	in
	let idx_of_places places =
		let fold_ls (idxs, places) ls =
			let idx, places = idx_of_place places ls
			in
			(idx::idxs, places)
		in
		List.fold_left fold_ls ([], places)
	in
	let register_transition (a,i,j) conds (id, places, transitions, tp, pt, ra) =
		let conds = LSSet.elements conds
		in
		let sid = string_of_int id
		and str = a ^ " " ^ (string_of_astate an a i)
					^ " -> " ^ (string_of_astate an a j)
					^ (match conds with [] -> "" | _ -> " when "^
						String.concat " and " 
							(List.map (string_of_localstate an) conds))
		in
		let transitions = (id, sid^"\""^str^"\"")::transitions
		and idxs, places = idx_of_places places conds
		in
		let id_ai, places = idx_of_place places (a,i)
		in
		let id_aj, places = idx_of_place places (a,j)
		in
		let sai = string_of_int id_ai
		and saj = string_of_int id_aj
		and sidxs = List.map string_of_int idxs
		in
		let tp = (sid^"<"^saj)::tp
		and pt = (sai^">"^sid)::pt
		in
		let (tp, pt, ra) = 
			if opts.contextual_ptnet then
				let ra = ra @ List.map (fun sai -> sid^"<"^sai) sidxs
				in
				tp, pt, ra
			else
				let tp = tp @ List.map (fun sai -> sid^"<"^sai) sidxs
				and pt = pt @ List.map (fun sai -> sai^">"^sid) sidxs
				in
				tp, pt, ra
		in
		(id+1, places, transitions, tp, pt, ra)
	in
	let pep = (1, LSMap.empty, [], [], [], [])
	in
	let (_, places, transitions, tp, pt, ra) = 
			Hashtbl.fold register_transition an.conditions pep
	in
	let register_localstate ai id places =
		(id, string_of_int id^"\""^string_of_localstate an ai^"\""
				^(if ctx_has_localstate ai ctx then "M1" else "M0"))::places
	in
	let places = LSMap.fold register_localstate places []
	in
	let places = List.map snd (List.sort compare places)
	and transitions = List.map snd (List.sort compare transitions)
	in
	"PEP\nPTNet\nFORMAT_N\n"
	^ "PL\n" ^ (String.concat "\n" places) ^ "\n"
	^ "TR\n" ^ (String.concat "\n" transitions) ^ "\n"
	^ "TP\n" ^ (String.concat "\n" tp) ^ "\n"
	^ "PT\n" ^ (String.concat "\n" pt) ^ "\n"
	^ (if opts.contextual_ptnet then "RA\n" ^ (String.concat "\n" ra) ^ "\n"
		else "")
;;

let prism_of_an an ctx =
	let a_counter = ref 0
	and a2i = ref SMap.empty
	in
	let index a =
		try SMap.find a !a2i 
		with Not_found -> (
			a_counter := !a_counter + 1;
			a2i := SMap.add a !a_counter !a2i;
			!a_counter
		)
	in
	let modname a = 
		let i = index a
		in
		"A"^string_of_int i
	and varname a =
		let i = index a
		in
		"s"^string_of_int i
	in
	let prism_state (a,i) =
		varname a ^ "=" ^ string_of_int i
	and prism_state' (a,i) = 
		varname a ^ "'=" ^ string_of_int i
	in
	let prism_of_transition a i j conds =
		let conds = LSSet.elements conds
		in
		"\t[] " ^ (String.concat " & " (List.map prism_state ((a,i)::conds)))
			^ " -> (" ^ prism_state' (a,j)^");\n"
	in
	let prism_of_transitions a i =
		let transitions = Hashtbl.find an.transitions (a,i)
		in
		let fold_jump j str_trs =
			let conds_list = Hashtbl.find_all an.conditions (a,i,j)
			in
			let str_conds = List.map (prism_of_transition a i j) conds_list
			in
			str_trs ^ String.concat "" str_conds
		in
		ISet.fold fold_jump transitions ""
	in
	let prism_of_automaton a spec str =
		let ls = snd (List.split spec)
		in
		str
		^ "// automaton \""^a^"\"\n"
		^ "module "^modname a^"\n"
		^ "\t// "
			^ (String.concat "; " (List.map 
					(fun (s_i, i) -> string_of_int i^"=\""
										^string_of_sig_state s_i^"\"") spec))
			^"\n"
		^ "\t"^varname a^": [0.."^string_of_int (List.length spec - 1)^"]"
		^ " init "^string_of_int (ISet.choose (SMap.find a ctx))^";\n\n"
		^ (String.concat "\n" (List.map (prism_of_transitions a) ls))
		^ "\n\nendmodule\n\n"
	in
	"mdp\n\n"
	^ Hashtbl.fold prism_of_automaton an.automata ""
;;


