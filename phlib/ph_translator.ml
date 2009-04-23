
open Ph_types;;
let string_of_float0 = Util.string_of_float0;;

type piproc_arg_action = ArgReset | ArgUpdate of (string * string) list;;

(* spim_of_ph with stochasticity_absorption *)
let spim_of_ph (ps,hits) init_state properties =
	let chanl_of_process a = "l_"^a
	and p_level (a,i) = a^"("^string_of_int i^")"
	and p_name (a,i) = a^string_of_int i
	and sa_value = function Some sa -> sa
		| None -> int_of_string (List.assoc "stochasticity_absorption" properties)
	in
	let register_metaproc piprocs (p,l) =
		piprocs @ List.map (fun l -> (p,l),[]) (Util.range 0 l)
	in
	let piprocs = List.fold_left register_metaproc [] ps
	in
	let add_pichoice piprocs piproc pi =
		let pis = List.assoc piproc piprocs
		in
		(piproc,pi::pis)::List.remove_assoc piproc piprocs
	in
	let register_hit p2 ((p1,(r,sa)),l) (piprocs,channels,counter) =
		let hitid = "hit"^string_of_int counter
		and p2' = (fst p2,l)
		and notify_level = "!"^chanl_of_process (fst p2)^"("^string_of_int l^")"
		and sa = sa_value sa
		in
		let hitcounter = "c_"^hitid
		and nexts, nextd = notify_level^";%%", [p2',ArgReset]
		in
		let stochasticity_absorption p action =
			if sa = 1 then
				(action^nexts, nextd)
			else (
				action^"if "^hitcounter^" = "^string_of_int sa^" then ("^
					nexts^") else (%%)", nextd@[p,ArgUpdate [hitcounter,"+1"]]
			)
		in
		let piprocs = 
			if p1 = p2 then (
				(* delay *)
				let action = "delay@"^hitid^";"
				in
				let pi = stochasticity_absorption p1 action
				in
				add_pichoice piprocs p2 pi
			) else (
				(* a_i *)
				let pi = ("!"^hitid^";%%", [p1,ArgUpdate []])
				in
				let piprocs = add_pichoice piprocs p1 pi
				in
				(* b_j *)
				let pi = stochasticity_absorption p2 ("?"^hitid^";")
				in
				add_pichoice piprocs p2 pi
			)
		in
		let c = (hitid, r, sa, p2 <> p1)
		in
		(piprocs,c::channels,counter+1)
	in
	let piprocs,channels,counter = Hashtbl.fold register_hit hits (piprocs,[],0)
	in
	let extract_args (p, pis) =
		let extract_args (_, d) = List.flatten 
			(List.map (fun (p,arg_action) -> match arg_action with 
				  ArgUpdate args -> List.map fst args
				| _ -> []) d)
		in
		p, List.flatten (List.map extract_args pis)
	in
	let p_args = List.map extract_args piprocs
	in

	let string_of_picall (p, arg_action) =
		let args = List.assoc p p_args
		in
		(p_name p)^"("^(String.concat "," (match arg_action with
		  ArgUpdate au -> List.map (fun arg ->
		  	arg^try List.assoc arg au with Not_found -> "") args
		| ArgReset -> List.map (fun arg -> "1") args
		))^")"
	in

	let string_of_pi piproc (pis, pid) =
		Util.string_apply "%%" pis (List.map string_of_picall pid)
	in
		
	let string_of_channel (hitid, r, sa, ischan) =
		let r = string_of_float0 (r *. float_of_int sa)
		in
		if ischan then ("new "^hitid^"@"^r^":chan") else ("val "^hitid^"="^r)

	and string_of_piproc (p, choices) =
		let args = List.assoc p p_args
		in
		(p_name p)^"("^(String.concat "," 
				(List.map (fun arg -> arg^":int") args))^") = "
		^ match choices with
		  [] -> "!dead"
		| [pi] -> string_of_pi p pi
		| pis -> "do "^String.concat " or " (List.map (string_of_pi p) pis)
	in

	(* plot list *)
	let plot_list = String.concat ";" (List.flatten
		(List.map (fun (a,l_a) -> 
			List.map (fun i -> p_level (a,i)) (Util.range 0 l_a)) ps))
	

	(* level changes notifiers *)
	and def_notifiers = String.concat "\n"
		(List.map (fun (a,l_a) -> "new "^chanl_of_process a^":chan(int)") ps)

	and notifiers = "let "^String.concat "\nand "
		(List.map (fun (a,l_a) -> 
			a^"(level:int) = ?"^chanl_of_process a^"(level); "^a^"(level)") ps)
	in

	(* channels definitions *)
	let defs = "new dead:chan\n" ^ 
		(String.concat "\n" (List.map string_of_channel channels))
	
	(* processes definitions *)
	and body = "let "^
		String.concat "\nand " (List.map string_of_piproc piprocs)^
		"\n\nlet w() = delay@0.5; w()" (* wake-up process *)

	(* initial state *)
	and run = "run ("^(String.concat " | " (List.map (fun p -> 
						string_of_picall (p,ArgReset)^ "|" ^ p_level p)
						init_state)) ^
					"| w())\n"
	in
	String.concat "\n" [
		"directive sample "^Util.string_of_float0 (float_of_string (List.assoc "sample" properties));
		"directive plot w();"^plot_list;
		"";
		"(* level changes notifiers *)";
		def_notifiers;
		notifiers;
		"";
		defs;
		"";
		body;
		"";
		run
	]
;;

let prism_of_ph (ps,hits) init_state properties =
	let modname p = "proc_"^p
	and statemod p = p
	and hitcounter hitid = "c_"^string_of_int hitid
	and sa_value = function Some sa -> sa
		| None -> int_of_string (List.assoc "stochasticity_absorption" properties)
	in

	let module_of_proc (a,l_a) =
		let decl = (statemod a)^": [0.."^(string_of_int l_a)^"] init "^
					(string_of_int (List.assoc a init_state))
					^"; // state"
		in
		(a, ([decl],[],[]))
	in
	let modules = List.map module_of_proc ps
	in

	let module_update modules (id,(decls,actions,counters)) =
		let _decls,_actions,_counters = List.assoc id modules
		in
		(id, (_decls@decls,_actions@actions,_counters@counters))
		::List.remove_assoc id modules
	in
	let modules_update = List.fold_left module_update
	in
	let string_of_module (a, (decls, actions,counters)) =
		let reset_counters = "("^(String.concat "'=1) & (" counters)^"'=1)"
		in
		let apply = Str.global_replace (Str.regexp_string "%%") reset_counters
		in
		"module "^(modname a)^"\n"^
		"\t"^(String.concat "\n\t" decls)^"\n\n"^
		"\t"^apply (String.concat "\n\t" actions)^"\n\n"^
		"endmodule"
	in

	let prism_is_state a i = 
		statemod a^"="^string_of_int i
	and prism_set_state a i' =
		"("^statemod a^"'="^string_of_int i'^")"
	in

	let register_hit (b,j) (((a,i),(r,sa)),k) (modules, hitid) =
		let modules =
			let sa = sa_value sa
			in
			let r = string_of_float0 (r *. float_of_int sa)
			in
			if (a,i) = (b,j) then (
				let mod_a = 
					if sa = 1 then (
						[],
						["[] "^prism_is_state a i^" -> "^r^": "^prism_set_state a k^";"],
						[]
					) else (
						let hc = hitcounter hitid
						in
						[hc ^": [1.."^string_of_int sa^"] init 1;"],
						["[] "^prism_is_state a i^" & "^hc^"<"^string_of_int sa^
								" -> "^r^": ("^hc^"'="^hc^"+1);"
						;"[] "^prism_is_state a i^" & "^hc^"="^string_of_int sa^
								" -> "^r^": "^prism_set_state a k^" & %%;"],
						[hc]
					)
				in
				modules_update modules [a,mod_a]
			) else (
				let sync = "[h_"^string_of_int hitid^"] "
				in
				let action_a = sync^prism_is_state a i^" -> "^
					r^": "^prism_set_state a i^";"
				and mod_b =
					if sa = 1 then (
						[],
						[sync^prism_is_state b j^" -> "^prism_set_state b k^";"],
						[]
					) else (
						let hc = hitcounter hitid
						in
						[hc ^": [1.."^string_of_int sa^"] init 1;"],
						[sync^prism_is_state b j^" & "^hc^"<"^string_of_int sa^
								" -> "^r^": ("^hc^"'="^hc^"+1);"
						;sync^prism_is_state b j^" & "^hc^"="^string_of_int sa^
								" -> "^r^": "^
								prism_set_state b k^" & %%;"],
						[hc]
					)
				in
				modules_update modules [a,([],[action_a],[]);b,mod_b]
			)
		in modules, hitid + 1
	in
	let modules, _ = Hashtbl.fold register_hit hits (modules,0)
	in


	let header = "ctmc"
	in
	header ^ "\n\n" ^ (String.concat "\n\n" (List.map string_of_module modules))
			^ "\n\n"
;;


