
open LocalCausalityGraph
open AutomataNetwork

let usage_msg = "pint-lcg [opts] <local state>"

let lcg_type = ref "verbose"
let opt_output = ref "-"

let cmdopts = An_cli.common_cmdopts @ An_cli.input_cmdopts @ [
		("-o", Arg.Set_string opt_output, "<lcg.dot>\tOutput file");
		("-t", Arg.Symbol (["verbose";"worth"], (fun x -> lcg_type := x)), 
					"\tWhich Local Causality Graph (default: "^(!lcg_type)^")");
	]

let args, abort = An_cli.parse cmdopts usage_msg

let an, ctx = An_cli.process_input ()

let goal = match args with 
	  [str_ls] ->
	  	let (a,sig_i) = An_input.parse_string An_parser.local_state str_ls
		in
		[(a, get_automaton_state_id an a sig_i)]
	| _ -> abort ()

let cache = An_localpaths.create_cache ()

let abstract_sols = An_localpaths.abstract_solutions cache an

let verbose_lcg () =
	let lcg = new glc oa_glc_setup ctx goal abstract_sols
	in
	lcg#set_auto_conts false;
	lcg#build;
	lcg

let worth_lcg () =
	let env = An_reach.init_env an ctx goal
	in
	An_reach.worth_lcg env


let lcg_factories = [
	("verbose", verbose_lcg);
	("worth", worth_lcg);
]
		(*;"trimmed";"cutsets";"saturated";"first_ua"],*)

let lcg = (List.assoc !lcg_type lcg_factories) ()

let data = lcg#to_dot

let _ = 
	let channel_out = if !opt_output = "-" then stdout else open_out !opt_output
	in
	output_string channel_out data;
	close_out channel_out

(*
old code that might be ported


let env = Ph_reach.init_env ph ctx pl
in

(if do_extract_graph then 
	let get_Sols = Ph_bounce_seq.get_aBS env.ph env.bs_cache
	in
	let build_glc () =
		let gA = new glc oa_glc_setup env.ctx env.pl env.concrete get_Sols
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
		let _, get_Sols = Ph_reach.unordered_over_approx env get_Sols
		in
		let gB = new glc glc_setup env.ctx env.pl env.concrete get_Sols
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

*)
