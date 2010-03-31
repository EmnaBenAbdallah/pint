
open Debug;;

open Ph_types;;

type bounce_path = sort * sortidx * ISet.t
type bounce_sequence = action list

let bp_sort (a, _, _) = a;;
let bp_bounce (_, _, js) = js;;
let bp_target (_, i, _) = i;;
let bp_reach s (z,l) = (z, state_value s z, ISet.singleton l);;

module BounceSequenceOT = struct type t = bounce_sequence let compare = compare end
module BS = Set.Make (BounceSequenceOT)
module BPSet = Set.Make (struct type t = bounce_path let compare = compare end)
module BPMap = Map.Make (struct type t = bounce_path let compare = compare end)

let string_of_bounce_path (a, i, js) =
	string_of_process (a,i) ^ " " ^ string_of_iset js
;;
let string_of_bp_set = string_of_set string_of_bounce_path BPSet.elements;;
let string_of_bounce_sequence bs =
	(*"["^(String.concat "; " (List.map (function action -> string_of_process (hitter action)) bs))^"]"*)
	"["^(String.concat "; " (List.map string_of_action bs))^"]"
;;
let string_of_BS = string_of_set string_of_bounce_sequence BS.elements;;

type env = {
	sorts : process list;
	t_hits : hits;
	aBS : (bounce_path, Ph_static.ProcEqSet.t list) Hashtbl.t;
	aDep : (bounce_path, BPSet.t list) Hashtbl.t;
	process_equivalence : sort -> process -> ISet.t;
}

let create_env (ps,hits) = 
	let equivalences = Ph_static.processes_equivalences (ps, hits)
	in
	{
		sorts = ps;
		t_hits = hits;
		aBS = Hashtbl.create 50;
		aDep = Hashtbl.create 50;
		process_equivalence = Ph_static.get_process_equivalence equivalences;
	}
;;

let next_BS (handler, merger, stopper, init) env bp =
	let a, i, reachset = bp
	in
	let actions_from_hits j = List.map (function (hitter,_),k -> Hit (hitter, (a,j), k))
	in
	let t_actions = List.map (fun j -> 
					let hits = Hashtbl.find_all env.t_hits (a,j)
					in
					actions_from_hits j hits) (Util.range 0 (List.assoc a env.sorts))
	in
	let t_actions = Array.of_list t_actions
	in
	let rec handle_seqs response = function
		  [] -> false, response
		| seq::seqs ->
			let r = handler seq
			in
			let response = merger response r
			in
			if stopper r then
				true, response
			else
				handle_seqs response seqs
	in

	let hitters_of_seq = List.map hitter
	in
	let is_surseq seq hitters =
		let hitters' = hitters_of_seq seq
		in
		let hitters' = List.filter (fun ai -> List.mem ai hitters) hitters'
		in
		hitters' = hitters
		(*
		let ret = hitters' = hitters
		in
		print_endline ("is_surseq "^string_of_bounce_sequence seq^" "^(String.concat ";" (List.map string_of_process hitters))^" = "^
						string_of_bool ret);
		ret *)
	in
	let seq_is_looping seq j =
		List.exists (function Hit (_,(_,j'),_) -> j = j') seq
	and seq_is_redundant done_seqs seq =
		List.exists (function hitters -> is_surseq seq hitters) done_seqs
	in
	let step i seqs (steps', done_seqs, response) =
		if ISet.mem i reachset then
			(* handle each sequence in seqs *)
			let success, response = handle_seqs response seqs
			in
			success, (steps', (List.map hitters_of_seq seqs)@done_seqs, response)
		else (
			(* actions on (a,i) *)
			let actions = t_actions.(i)
			in
			(* cross actions to all paths ending in i, 
				make them end to their respective bounce
			*)
			let push_seq steps' seq =
				let push_action steps' action =
					let j = bounce action
					in
					if seq_is_looping seq j then
						steps'
					else
						let seq = seq @ [action]
						in
						if seq_is_redundant done_seqs seq then
							steps'
						else
							let seqsj = try List.assoc j steps' with Not_found -> []
							in
							(j, seq::seqsj)::List.remove_assoc j steps'
				in
				List.fold_left push_action steps' actions
			in
			let steps' = List.fold_left push_seq steps' seqs
			in
			false, (steps', done_seqs, response)
		)
	in
	let rec handle_steps args = function
		  [] -> false, args
		| (i, seqs)::steps ->
			let success, args = step i seqs args
			in
			if success then
				success, args
			else
				handle_steps args steps
	in
	let rec bfs response done_seqs = function
		  [] -> response
		| steps ->
			let success, (steps, done_seqs, response) = handle_steps ([], done_seqs, response) steps
			in
			(* starts by handling winning steps *)
			let steps = List.sort (fun (i,_) (i',_) -> 
							let ri, ri' = ISet.mem i reachset, ISet.mem i' reachset
							in
							if ri = ri' then compare i i' else if ri then -1 else 1)
						steps
			in
			if success then response else (bfs response done_seqs steps)
	in

	bfs init [] [i, [[]]]
;;

exception ExecuteCrash
let rec execute env bp s stack =
	(if BPSet.mem bp stack then raise ExecuteCrash);

	let stack = BPSet.add bp stack
	and a = bp_sort bp
	in
	let rec execute_seq s = function 
		  [] -> s
		| action::seq -> 
			let b,j = hitter action
			in
			let sb = state_value s b
			in
			let reach = env.process_equivalence a (b,j)
			in
			let s = execute env (b, sb, reach) s stack
			in
			let sa = state_value s a
			in
			if sa <> snd (target action) then
				execute env (a, sa, bp_bounce bp) s stack
			else 
				let s = SMap.add a (bounce action) s
				in
				execute_seq s seq
	in
	let handler seq =
		(*print_endline ("? "^string_of_bounce_sequence seq^"...");*)
		try
			let s = execute_seq s seq
			in
			(*print_endline ("1 "^string_of_bounce_sequence seq);*)
			(true, s)
		with ExecuteCrash -> (
			(*print_endline ("0 "^string_of_bounce_sequence seq);*)
			(false, s)
		)
	and merger r l = l
	and stopper (success, s) = success
	in
	let success, s = next_BS (handler, merger, stopper, (false, s)) env bp
	in
	if success then s else raise ExecuteCrash
;;

let process_reachability_using_execute env bpzl s =
	dbg "+ running execute...";
	try
		let s = execute env bpzl s BPSet.empty
		in
		(*DEBUG*) 
			dbg "execute successful.";
			dbg (string_of_state s);
		(**)
		true
	with ExecuteCrash -> (
		dbg "execute failed.";
		false
	)
;;

let abstr_seq env a seq = 
	let folder hitters action =
		let (b,j) = hitter action
		in
		if b <> a then 
			let js = env.process_equivalence a (b,j)
			in
			Ph_static.ProcEqSet.add (b,js) hitters
		else hitters
	in
	List.fold_left folder Ph_static.ProcEqSet.empty seq
;;
let dep s aseq =
	let fold (a,js) bps =
		BPSet.add (a, state_value s a, js) bps
	in
	Ph_static.ProcEqSet.fold fold aseq BPSet.empty
;;

let string_of_aBS aBS = "[ "^(String.concat "; " (List.map Ph_static.string_of_proceqset aBS))^" ]"
;;
let compute_aBS env bp =
	let a, i, reachset = bp
	in
	let rec walk history results j visited =
		if ISet.mem j reachset then
			history::List.filter (fun bps -> not(Ph_static.ProcEqSet.subset history bps)) results
		else
			let visited = ISet.add j visited
			and actions = Hashtbl.find_all env.t_hits (a,j)
			in
			let folder results = function ((b,j),_), k ->
				if ISet.mem k visited then
					results
				else 
					let history = 
						if b <> a then 
							let js = env.process_equivalence a (b,j)
							in
							let peq = (b, js)
							in
							Ph_static.ProcEqSet.add peq history
						else
							history
					in
					if List.exists (fun bps -> Ph_static.ProcEqSet.subset bps history) results then
						results
					else
						walk history results k visited
			in
			List.fold_left folder results actions
	in
	(*DEBUG*) dbg_noendl ("- computing aBS("^string_of_bounce_path bp^")..."); (**)
	let aBS = walk Ph_static.ProcEqSet.empty [] i ISet.empty
	in  
	(*DEBUG*) dbg (" "^string_of_aBS aBS); (**)
	Hashtbl.add env.aBS bp aBS;
	aBS
;;
let get_aBS env bp =
	try Hashtbl.find env.aBS bp
	with Not_found -> compute_aBS env bp
;;

(* TODO: get rid of s here (add dependency in compute_aBS) *)
let directly_compute_aBS env s bp =
	let a, i, reachset = bp
	in
	let rec walk history results j visited =
		if ISet.mem j reachset then
			history::List.filter (fun bps -> not(BPSet.subset history bps)) results
		else
			let visited = ISet.add j visited
			and actions = Hashtbl.find_all env.t_hits (a,j)
			in
			let folder results = function ((b,j),_), k ->
				if ISet.mem k visited then
					results
				else 
					let history = 
						if b <> a then 
							let js = env.process_equivalence a (b,j)
							in
							let bp = (b, state_value s b, js)
							in
							BPSet.add bp history
						else
							history
					in
					if List.exists (fun bps -> BPSet.subset bps history) results then
						results
					else
						walk history results k visited
			in
			List.fold_left folder results actions
	in
	walk BPSet.empty [] i ISet.empty
;;

let string_of_aDep bps_list = 
	"[ "^ (String.concat "; " (List.map (string_of_set string_of_bounce_path BPSet.elements) bps_list))^" ]"
;;

let reach_bounce_path s (a,i) =
	(a, state_value s a, ISet.singleton i)
;;

let rec compute_aDep env s bp =
	let aBS = get_aBS env bp
	in
	let aDep = List.map (fun peqs -> 
		let tr (b, js) bps =
			BPSet.add (b, state_value s b, js) bps
		in
		Ph_static.ProcEqSet.fold tr peqs BPSet.empty) aBS
	in
	(*DEBUG*) dbg ("- aDep(s, "^string_of_bounce_path bp^") = "^string_of_aDep aDep); (**)
	Hashtbl.add env.aDep bp aDep;
	(* resolv dependences *)
	let resolv_bp bp =
		if not (Hashtbl.mem env.aDep bp) then
			ignore (compute_aDep env s bp)
	in
	List.iter (BPSet.iter resolv_bp) aDep;
	aDep
;;
(* TODO: support multiple s *)
let get_aDep env s bp =
	try Hashtbl.find env.aDep bp
	with Not_found -> compute_aDep env s bp
;;

let cleanup_aDep env =
	(* build reversed aDep *)
	let raDep = Hashtbl.create (Hashtbl.length env.aDep)
	in
	let folder bp bps_list (trues,keys) =
		let register bps =
			let register bp' =
				Hashtbl.add raDep bp' bp
			in
			BPSet.iter register bps
		in
		List.iter register bps_list;
		(if bps_list = [BPSet.empty] then
			BPSet.add bp trues
		else trues), bp::keys
	in
	let green, keys = Hashtbl.fold folder env.aDep (BPSet.empty, [])
	in
	(* colourise *)
	let rec colourise visited currents =
		if BPSet.is_empty currents then
			visited
		else 
			let visited = BPSet.union visited currents
			in
			let fold bp coloured =
				let parents = Hashtbl.find_all raDep bp
				in
				let fold_parent coloured pbp =
					if BPSet.mem pbp visited then coloured
					else
						let bps_list = Hashtbl.find env.aDep pbp
						in
						if List.exists (fun bps -> BPSet.subset bps visited) bps_list then
							BPSet.add pbp coloured
						else
							coloured
				in
				List.fold_left fold_parent coloured parents
			in
			let coloured = BPSet.fold fold currents BPSet.empty
			in
			colourise visited coloured
	in
	let green = colourise BPSet.empty green
	in
	(* remove uncoloured nodes *)
	let cleanup key =
		if BPSet.mem key green then 
			(* remove uncoloured choices *)
			let aDep = Hashtbl.find env.aDep key
			in
			let aDep = List.filter (fun bps -> BPSet.subset bps green) aDep
			in
			Hashtbl.replace env.aDep key aDep
		else
			(* remove key *)
			Hashtbl.remove env.aDep key
	in
	List.iter cleanup keys
;;

let dot_idx_from_bp (a,i,js) =
	"\"" ^ a^" "^string_of_int i^"->"^string_of_iset js^"\""
;;

let dot_from_aDep env =
	let idx = ref 0
	in
	let folder bp bpss str =
		let fold_bps str bps = (
			idx := !idx + 1;
			let child_id = "child"^string_of_int (!idx)
			in
			let fold_bp bp' str =
				str ^
				"  " ^ child_id ^" -> "^dot_idx_from_bp bp'^"\n"
			in
			str ^ 
			"  " ^ child_id^"[label=ALL shape=box]\n" ^
			"  " ^ dot_idx_from_bp bp^ " -> "^child_id^"\n" ^
			(BPSet.fold fold_bp bps "")
		) in
		List.fold_left fold_bps str bpss
	in
	Hashtbl.fold folder env.aDep "digraph aDep {\n" ^ "}"
;;

let rec link_choices _D = function _,[] | [],_ -> _D
	| (k::tk, v::tv) -> 
		let _D = BPMap.add k v _D
		in link_choices _D (tk,tv)
;;


let fold_concretions2 (bps,_D) (handler, merger, stopper) env s root =
	let rec fold_concretions _D visited bps =
		let bps = BPSet.diff bps visited
		in
		if BPSet.is_empty bps then
			handler (visited, _D)
		else
			let visited = BPSet.union bps visited
			in
			let bps = BPSet.elements bps
			in
			let selectors = List.map (fun bp -> get_aDep env s bp) bps
			in
			let handler choices =
				let _D = link_choices _D (bps,choices)
				in
				let bps' = List.fold_left BPSet.union BPSet.empty choices
				in
				fold_concretions _D visited bps'
			in
			Util.cross_forward (handler, merger, stopper) selectors
	in
	fold_concretions _D bps (BPSet.singleton root)
;;
let fold_concretions = fold_concretions2 (BPSet.empty, BPMap.empty)
;;

let dot_from_concretion (bps,_D) =
	let fold bp bps str = 
		let fold_bp bp' str = str ^
			"  " ^ dot_idx_from_bp bp ^" -> " ^dot_idx_from_bp bp'^"\n"
		in
		BPSet.fold fold_bp bps str
	in
	BPMap.fold fold _D "digraph concretion {\n" ^ "}"
;;

let concretion_has_cycle (_,_D) root =
	let rec walk stack bp =
		(if BPSet.mem bp stack then raise ExecuteCrash);
		let stack = BPSet.add bp stack
		in
		let childs = BPMap.find bp _D
		in
		BPSet.iter (walk stack) childs
	in
	try
		walk BPSet.empty root;
		false
	with ExecuteCrash ->
		true
;;

let concretion_sort_independence (bps, _D) =
	let fold bp sorts =
		let a = bp_sort bp
		in
		if SSet.mem a sorts then
			raise Not_found
		else
			SSet.add a sorts
	in
	try
		ignore (BPSet.fold fold bps SSet.empty);
		true
	with Not_found ->
		false
;;

(* TODO: handle equivalent processes *)
let bp_singlebounce (_,_,js) = ISet.min_elt js;;

let top a _D root =
	let rec top root = match root with (b, j, js) ->
		if b = a then 
			ISet.singleton (bp_singlebounce root)
		else
			let fold bp res =
				ISet.union res (top bp)
			in
			BPSet.fold fold (BPMap.find root _D) ISet.empty
	in
	top root
;;

module IS2 = Set.Make(struct type t = ISet.t let compare = ISet.compare end)

let order_bps (bps,_D) ignore =
	let rec order_bps root bps =
		if BPMap.mem root ignore then
			bps
		else
			let bps = if List.mem root bps then bps else root::bps
			in
			let childs = BPMap.find root _D
			in
			BPSet.fold order_bps childs bps
	in
	order_bps
;;

let concretion_saturation_valid (bps, _D) env s bpzl =
	let missing_bps (bps, _D) satured root =
		if BPMap.mem root satured then 
			[], BPMap.find root satured
		else (
			(* fetch childs' tops *)
			let fold_child bp map =
				let fold_sort a top map =
					let atops = try SMap.find a map with Not_found -> IS2.empty
					in
					let atops' = 
						if a = bp_sort bp && a = bp_sort root then
							atops (* ignore direct child of same sort *)
						else
							let atops, atopsinter = IS2.partition (fun top' -> ISet.is_empty (ISet.inter top' top)) atops
							in
							if IS2.is_empty atopsinter then
								IS2.add top atops
							else
								let atop' = IS2.fold (fun top' atop -> ISet.union top' atop) atopsinter top
								in
								IS2.add atop' atops
					in
					SMap.add a atops' map
				in
				SMap.fold fold_sort (BPMap.find bp satured) map
			in
			let childs = BPMap.find root _D
			in
			let map = BPSet.fold fold_child childs SMap.empty
			in
			(* links between childs' tops *)
			let get_missing a tops (missing, topm) =
				let fold top (st1, missing, top') =
					let t2 = ISet.min_elt top
					and top' = ISet.union top' top
					in
					match st1 with
					  None -> (Some t2, missing, top')
					| Some t1 -> (
						st1, 
						(a, t1, ISet.singleton t2)
							::(a, t2, ISet.singleton t1)
							::missing,
						top'
					)
				in
				let _, missing, atop = IS2.fold fold tops (None, missing, ISet.empty)
				in
				let missing = List.filter (fun bp -> not (BPSet.mem bp childs)) missing
				in
				missing, SMap.add a atop topm
			in
			let missing, futuretopmap = SMap.fold get_missing map ([], SMap.empty)
			in
			(* forward between childs and root sort *)
			let a = bp_sort root
			in
			let missing = try
					(* find direct child of same sort *)
					let has_direct_child bp =
						if bp_sort bp = a && bp_singlebounce bp = bp_singlebounce root then
							raise Not_found
					in
					BPSet.iter has_direct_child childs;
					(* check if forwarding is needed *)
					let atop = SMap.find a futuretopmap
					in
					if ISet.mem (bp_target root) atop
							|| ISet.mem (bp_singlebounce root) atop then
						raise Not_found
					else
						(a, ISet.min_elt atop, bp_bounce root)::missing
				with Not_found -> missing
			in
			let futuretopmap = SMap.add a (ISet.singleton (bp_singlebounce root)) futuretopmap
			in
			missing, futuretopmap
		)
	in
	let flip = ref 0
	in
	let rec sature (bps, _D) satured = function [] -> true, (bps, _D)
		| root::tosature ->
			if !Debug.dodebug then (
				flip := 1 - !flip;
				Util.dump_to_file ("dbg-current-concretion-"^string_of_int (!flip)^".dot") (dot_from_concretion (bps,_D))
			);
			let missing, topm = missing_bps (bps, _D) satured root
			in
			if missing = [] then (* saturation done *)
				let satured = BPMap.add root topm satured
				in
				sature (bps, _D) satured tosature
			else (
				dbg_noendl ("[adding "^(String.concat " + " (List.map string_of_bounce_path missing))^"] ");
				let rec push_missing (bps, _D) tosature = function
					  [] -> sature (bps, _D) satured tosature
					| bp::missing ->
						(* merge concretion *)
						let handler (bps, _D) =
							(* link with root *)
							let _D = BPMap.add root (BPSet.add bp (BPMap.find root _D)) _D
							in
							(* ensure loop-free solution *)
							if concretion_has_cycle (bps,_D) bpzl then
								(false, (bps, _D))
							else (
								(* prepend new nodes to tosature *)
								let tosature = order_bps (bps,_D) satured bp tosature
								in
								(* push next missing *)
								push_missing (bps, _D) tosature missing
							)
						and stopper (ret, _) = ret
						and merger _ d2 = d2
						in
						try fold_concretions2 (bps,_D) (handler,merger,stopper) env s bp
						with Not_found -> (false, (bps,_D))
				in
				push_missing (bps, _D) (root::tosature) missing
			)
	in

	let get_satured bp satured =
		if not (BPMap.mem bp _D) || BPSet.is_empty (BPMap.find bp _D) then
			let b = bp_singlebounce bp
			in
			let topmap = SMap.add (bp_sort bp) (ISet.singleton b) SMap.empty
			in
			BPMap.add bp topmap satured
		else
			satured
	in
	let satured = BPSet.fold get_satured bps BPMap.empty
	in
	let tosature = order_bps (bps,_D) satured bpzl []
	in
	let success, concretion = sature (bps, _D) satured tosature
	in
	if success && !Debug.dodebug then Util.dump_to_file "dbg-concretion.dot" (dot_from_concretion concretion);
	success
;;

let process_reachability env zl s =
	let bpzl = bp_reach s zl
	in
	(* Under-approximate ExecuteCrash *)
	dbg "+ under-approximating ExecuteCrash...";
	ignore (compute_aDep env s bpzl);
	(if !Debug.dodebug then Util.dump_to_file "dbg-reach_aDep-init.dot" (dot_from_aDep env));
	dbg "- cleanup...";
	cleanup_aDep env;
	if not (Hashtbl.mem env.aDep bpzl) then (
		dbg "+ early decision: false";
		false
	) else (
		dbg "+ no conclusion.";
		(if !Debug.dodebug then Util.dump_to_file "dbg-reach_aDep-clean.dot" (dot_from_aDep env));

		(* Over-approximate ExecuteCrash *)
		dbg "+ over-approximating ExecuteCrash...";
		let handler (bps,_D) =
			dbg_noendl "  - handling a concretion... ";
			(* 1. check for cycle-free concretion *)
			if concretion_has_cycle (bps,_D) bpzl then (
				dbg "cycle.";
				false
			(* 2. independence *)
			) else if concretion_sort_independence (bps, _D) then (
				dbg "sort independence.";
				true
			(* 3. scheduling saturation *)
			) else if concretion_saturation_valid (bps, _D) env s bpzl then (
				dbg "valid saturation.";
				true
			) else (
				dbg "inconclusive.";
				false
			)
		and merger r l = r || l
		and valid v = v
		in
		let ret = fold_concretions (handler, merger, valid) env s bpzl
		in
		if valid ret then (
			dbg "+ early decision: true";
			true
		) else (
			(* Can not statically conclude. *)
			dbg "+ can not statically decide.";
			process_reachability_using_execute env bpzl s
		)
	)
;;


let test env bpzl s =
	let handler seq =
		print_endline ("handling sequence "^string_of_bounce_sequence seq)
	in
	ignore (next_BS (handler, (fun () () -> ()), (fun () -> false), ()) env bpzl);
	raise Exit
;;

