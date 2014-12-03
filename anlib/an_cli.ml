
open Ph_types
open AutomataNetwork

let common_cmdopts = [
	("--no-debug", Arg.Clear Debug.dodebug, "Disable debugging");
	("--debug", Arg.Set Debug.dodebug, "Enable debugging");
	("--debug-level", Arg.Set_int Debug.debuglevel, "Maximum debug level");
	("--version", Arg.Unit (fun () ->
			print_endline ("Pint version "^Distenv.version);
			ignore(exit 0)), "Print Pint version and quit");
	]


(**
	Input options
 **)
let opt_channel_in = ref stdin
let opt_filename_in = ref "<stdin>"

let setup_opt_channel_in filename =
	opt_filename_in := filename;
	opt_channel_in := open_in filename

let opt_override_ctx = ref []

let setup_opt_initial_ctx opt =
	opt_override_ctx := An_input.parse_string An_parser.local_state_list opt

let input_cmdopts = [
	("-i", Arg.String setup_opt_channel_in, "<model.an>\tInput filename");
	("--initial-state", Arg.String setup_opt_initial_ctx,
		"<local state list>\tInitial state");
	("--initial-context", Arg.String setup_opt_initial_ctx,
		"<local state list>\tInitial context (equivalent to --initial-state)");
	]

(**
	Main usage
 **)


let parse cmdopts usage_msg = 
	let opt_anonargs = ref ([]:string list)
	in
	let anon_fun arg = opt_anonargs := !opt_anonargs @ [arg]
	in
	Arg.parse cmdopts anon_fun usage_msg;
	!opt_anonargs, (fun () -> Arg.usage cmdopts usage_msg; raise Exit)

let process_input () =
	let an, ctx = An_input.parse !opt_channel_in
	in
	let user_ctx = ctx_of_siglocalstates an !opt_override_ctx
	in
	let ctx = ctx_override_by_ctx ctx user_ctx
	in
	an, ctx

let parse_local_state an data =
	let (a,sig_i) = An_input.parse_string An_parser.local_state data
	in
	(a, get_automaton_state_id an a sig_i)


