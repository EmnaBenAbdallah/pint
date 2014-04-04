(* Copyright or © or Copr. Loïc Paulevé, Morgan Magnin, Olivier Roux (2010)

loic.pauleve@irccyn.ec-nantes.fr
morgan.magnin@irccyn.ec-nantes.fr
olivier.roux@irccyn.ec-nantes.fr

This software is a computer program whose purpose is to provide Process
Hitting related tools.

This software is governed by the CeCILL license under French law and
abiding by the rules of distribution of free software.  You can  use, 
modify and/ or redistribute the software under the terms of the
CeCILL license as circulated by CEA, CNRS and INRIA at the following URL
"http://www.cecill.info". 

As a counterpart to the access to the source code and  rights to copy,
modify and redistribute granted by the license, users are provided only
with a limited warranty  and the software's author, the holder of the
economic rights, and the successive licensors  have only  limited
liability. 

In this respect, the user's attention is drawn to the risks associated
with loading,  using,  modifying and/or developing or reproducing the
software by the user in light of its specific status of free software,
that may mean  that it is complicated to manipulate,  and  that  also
therefore means  that it is reserved for developers  and  experienced
professionals having in-depth computer knowledge. Users are therefore
encouraged to load and test the software's suitability as regards their
requirements in conditions enabling the security of their systems and/or 
data to be ensured and,  more generally, to use and operate it in the 
same conditions as regards security. 

The fact that you are presently reading this means that you have had
knowledge of the CeCILL license and that you accept its terms.
*)

open Debug;;
open Ph_types;;

open Ph_glc;;
open Ph_reach;;

let opt_method = ref "static"
and opt_args = ref []
and opt_cutsets_n = ref 0
and opt_cutsets_n_coop = ref false
and opt_cutsets_n_reduce = ref true
and opt_extract_graph = ref ""
and opt_graph = ref "verbose"
and opt_coop_priority = ref false
in
let cmdopts = Ui.common_cmdopts @ Ui.input_cmdopts @ [
		("--method", Arg.Symbol (["static";"test"],
				(fun x -> opt_method := x)), "\tMethod");
		("--coop-priority", Arg.Set opt_coop_priority, 
									"\tAssume hits on cooperative sorts of higher priority");
		("--cutsets", Arg.Set_int opt_cutsets_n, "\tCompute cutsets with given maximum size");
		("--cutsets-include-coop", Arg.Set opt_cutsets_n_coop, 
			"\tConsider cooperativities in cutsets (default: false)");
		("--no-cutsets-reduce", Arg.Clear opt_cutsets_n_reduce, 
			"\tDisable static reduction of causality abstract structre");
		("--output-glc", Arg.Set_string opt_extract_graph, 
				"<graph.dot>\tExport the Graph of Local Causality (GLC)");
		("--glc", Arg.Symbol (["verbose";"trimmed";"cutsets";"saturated";"first_ua"],
				(fun x -> opt_graph := x)), "\tGLC to export");
	]
and usage_msg = "ph-reach [opts] <a> <i> [<b> <j> [...]]"
and anon_fun arg = opt_args := !opt_args@[arg]
in
Arg.parse cmdopts anon_fun usage_msg;
let l = List.length !opt_args
in
(if l < 2 || l mod 2 <> 0 then (Arg.usage cmdopts usage_msg; raise Exit));
let pl = Ui.proclist_from_stringlist !opt_args
in

let do_cutsets = !opt_cutsets_n > 0
and do_extract_graph = !opt_extract_graph <> ""
in
let do_reach = not (do_cutsets || do_extract_graph)
in

let ph, ctx = Ph_util.parse !Ui.opt_channel_in
in

let env = Ph_reach.init_env ph ctx pl
in

(if do_cutsets then
	let is_sort_cooperative a = 
		(try String.sub a 0 1 = "_" with Invalid_argument _ -> false) 
			|| SMap.mem a !Ph_instance.cooperativities
	in
	let ignore_proc ai = if !opt_cutsets_n_coop then false else is_sort_cooperative (fst ai)
	in
		
	(* compute graph *)
    let gA = new glc oa_glc_setup env.ctx env.pl (get_Sols env)
    in  
    gA#set_auto_conts false;
    gA#build;
    let gA = bot_trimmed_cwA env gA
    in  
	let gA = if !opt_cutsets_n_reduce then
		let gA = cleanup_gA_for_cutsets gA
		in
		top_trimmed_cwA env gA;
		gA else gA
	in
	print_endline ("#nodes = "^string_of_int gA#count_nodes);
	print_endline ("#procs = "^string_of_int gA#count_procs);
	print_endline ("#objs = "^string_of_int gA#count_objs);

    let (d_nkp, index_proc) = cutsets gA !opt_cutsets_n ignore_proc gA#leafs
	in

	(* TODO
	let find_coops pss =
		let process_ps ps coops =
			let ps_coops = PSet.filter (fun (a,_) -> is_sort_cooperative a) ps
			in
			PSet.union ps_coops coops
		in
		PSSet.fold process_ps pss PSet.empty
	in
	*)
		(* TODO 
			let coops = find_coops pss
			in
			let coops = Ph_static.resolve_cooperativities ph (PSet.elements coops)
			in
			let string_of_rcoops psl =
				let string_of_rcoop =
					string_of_set ~lbracket:"<" ~rbracket:">" ~delim:"," string_of_proc PSet.elements
				in
				String.concat ";" (List.map string_of_rcoop psl)
			in
		*)

	let resolve_ps = 
		List.map (Hashtbl.find index_proc)
	in
	let string_of_ai ai =
		(*if is_sort_cooperative (fst ai) then TODO
			string_of_rcoops (List.assoc ai coops)
		else*)
			string_of_proc ai
	in
	let print_ps ps =
		let s = String.concat ";" (List.map string_of_ai ps)
		in
		print_endline s
	in
	let handle_proc ai =
		try
			let pss = fst (Hashtbl.find d_nkp (NodeProc ai))
			in
			let n = PSSet.cardinal pss
			in
			print_endline ("# "^string_of_int n^" key process(es) for "^string_of_proc ai^":");
			let elts = PSSet.elements pss
			in
			let elts = List.map resolve_ps elts
			in
			let elts = List.map (List.sort compare) elts
			in
			let elts = List.sort (fun a b ->
					let c = compare (List.length a) (List.length b)
					in
					if c <> 0 then c else compare a b) elts
			in
			List.iter print_ps elts

		with Not_found ->
			print_endline (string_of_node (NodeProc ai)^" is not reachable.");
	in
	List.iter handle_proc pl
);
(if do_extract_graph then 
	let get_Sols = Ph_bounce_seq.get_aBS env.ph env.bs_cache
	in
	let build_glc () =
		let gA = new glc oa_glc_setup env.ctx env.pl get_Sols
		in
		gA#set_auto_conts false;
		gA#build;
		gA
	and build_saturated_glc () =
		let glc_setup = 
			if !opt_coop_priority then
				coop_priority_ua_glc_setup
			else 
				ua_glc_setup
		in
		let gB = new glc glc_setup env.ctx env.pl get_Sols
		in
		gB#build;
		gB#saturate_ctx;
		gB
	in
	let output_glc (glc : #graph) =
		let channel_out = if !opt_extract_graph = "-" then stdout else open_out !opt_extract_graph
		in
		output_string channel_out glc#to_dot;
		close_out channel_out
	in
	(*gA#debug;*)
	let glc = 
		if !opt_graph = "verbose" then
			build_glc ()
		else if !opt_graph = "trimmed" then
			let gA = bot_trimmed_cwA env (build_glc ())
			in
			top_trimmed_cwA env gA;
			gA
		else if !opt_graph = "cutsets" then
			let gA = bot_trimmed_cwA env (build_glc ())
			in  
			let gA = cleanup_gA_for_cutsets gA
			in
			top_trimmed_cwA env gA;
			gA
		else if !opt_graph = "saturated" then
			build_saturated_glc ()
		else if !opt_graph = "first_ua" then
			let pGLC = ref Ph_reach.NullGLC
			in
			ignore
				(if !opt_coop_priority then
					Ph_reach.coop_priority_reachability ~saveGLC:pGLC env
				else
					Ph_reach.local_reachability ~saveGLC:pGLC env);
			match !pGLC with
				GLC glc -> glc
			| NullGLC -> failwith "No GLC satisfies the under-approximation"
		else
			failwith "invalid graph argument"
	in
	output_glc glc
);
(if do_reach then
	(* run the approximations *)
	let decision = 
	match !opt_method with
		| "static" ->
			if !opt_coop_priority then
				Ph_reach.coop_priority_reachability env
			else
				Ph_reach.local_reachability env
		| _ -> failwith "Unknown method."
	in
	print_endline (string_of_ternary decision)
)

