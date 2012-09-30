(*
Copyright or © or Copr. Loïc Paulevé, Morgan Magnin, Olivier Roux (2010)

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

open Ph_abstr_struct;;
open Ph_reach;;

let opt_method = ref "static"
and opt_args = ref []
and opt_list_keys = ref false
and opt_nkp = ref 1
and opt_nkp_coop = ref false
and opt_extract_graph = ref ""
and opt_graph = ref "verbose"
in
let cmdopts = Ui.common_cmdopts @ Ui.input_cmdopts @ [
		("--method", Arg.Symbol (["static";"test"],
				(fun x -> opt_method := x)), "\tMethod");
		("--list-keys", Arg.Set opt_list_keys, "\tList Key Processes");
		("--nkp", Arg.Set_int opt_nkp, "n\tMaximum size of key processes tuples (default: 1)");
		("--nkp-include-coop", Arg.Set opt_nkp_coop, 
			"\tConsider cooperativities as potential key processes (default: false)");
		("--extract-graph", Arg.Set_string opt_extract_graph, 
				"<graph.dot>\tExport abstract structure graph");
		("--graph", Arg.Symbol (["verbose";"trimmed"],
				(fun x -> opt_graph := x)), "\tGraph to export");
	]
and usage_msg = "ph-reach [opts] <a> <i> [<b> <j> [...]]"
and anon_fun arg = opt_args := !opt_args@[arg]
in
Arg.parse cmdopts anon_fun usage_msg;
(if List.length !opt_args < 2 then
	(Arg.usage cmdopts usage_msg; raise Exit)	
);
let rec make_procseq = function [] -> []
	| a::i::tail -> (a, int_of_string i)::make_procseq tail
	| _ -> (Arg.usage cmdopts usage_msg; raise Exit)
in
let pl = make_procseq !opt_args
in

let do_list_keys = !opt_list_keys
and do_extract_graph = !opt_extract_graph <> ""
in
let do_reach = not (do_list_keys or do_extract_graph)
in

let ph, ctx = Ph_util.parse !Ui.opt_channel_in
in

let env = Ph_reach.init_env ph ctx pl
in

(if do_list_keys then
	let is_sort_cooperative a = try String.sub a 0 6 = "__coop" with Invalid_argument _ -> false
	in
	let ignore_proc ai = if !opt_nkp_coop then false else is_sort_cooperative (fst ai)
	in
		
	(* compute graph *)
    let gA = new cwA env.ctx env.pl (get_Sols env)
    in  
    gA#set_auto_conts false;
    gA#build;
    let gA = trimmed_cwA env gA
    in  

	print_endline ("Total nodes: "^string_of_int gA#count_nodes);

    let d_nkp = Hashtbl.create 1000
	and t0 = Sys.time ()
	in

    let visited = key_procs gA !opt_nkp ignore_proc d_nkp (gA#get_leafs ())
	in

	prerr_newline ();
	print_endline ("****** systime: "^string_of_float (Sys.time () -. t0)^"s");
	print_endline ("Visited nodes: "^string_of_int visited);

	let find_coops pss =
		let process_ps ps coops =
			let ps_coops = PSet.filter (fun (a,_) -> is_sort_cooperative a) ps
			in
			PSet.union ps_coops coops
		in
		PSSet.fold process_ps pss PSet.empty
	in
	let handle_proc ai =
		try
			let pss = fst (Hashtbl.find d_nkp (NodeProc ai))
			in
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
			let string_of_ai ai =
				if is_sort_cooperative (fst ai) then
					string_of_rcoops (List.assoc ai coops)
				else
					string_of_proc ai
			in
			let print_ps ps =
				let s = string_of_set ~lbracket:"" ~rbracket:"" ~delim:";" string_of_ai PSet.elements ps
				in
				print_endline s
			in
			print_endline ("Key processes for "^string_of_proc ai^":");
			PSSet.iter print_ps pss

		with Not_found ->
			print_endline (string_of_node (NodeProc ai)^" is not reachable.");
	in
	List.iter handle_proc pl
);
(if do_extract_graph then 
	let get_Sols = Ph_bounce_seq.get_aBS env.ph env.bs_cache
	in
	let gA = new Ph_abstr_struct.cwA env.ctx env.pl get_Sols
	and channel_out = if !opt_extract_graph = "-" then stdout else open_out !opt_extract_graph
	in
	gA#set_auto_conts false;
	gA#build;
	(*gA#debug;*)
	if !opt_graph = "verbose" then
		output_string channel_out gA#to_dot
	else if !opt_graph = "trimmed" then (
		let gA' = trimmed_cwA env gA
		in
		output_string channel_out gA'#to_dot
	);
	close_out channel_out
);
(if do_reach then
	(* run the approximations *)
	let decision = 
	match !opt_method with
		| "static" -> Ph_reach.process_reachability (Ph_reach.init_oldenv ph ctx pl)
		| "test" -> Ph_reach.test env
		| _ -> failwith "Unknown method."
	in
	print_endline (string_of_ternary decision)
)

