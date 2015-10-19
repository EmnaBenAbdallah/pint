
open Debug

let cached_has_clingo = ref false
let clingo_checked = ref false

let has_clingo () =
	try
		let cin = Unix.open_process_in "clingo -v"
		in
		let line = input_line cin
		in
		Str.string_partial_match
			(Str.regexp "clingo version 4\\.") line 0
	with _ -> false

let has_clingo () =
	(if not !clingo_checked then
		(cached_has_clingo := has_clingo ();
		clingo_checked := true));
	!cached_has_clingo

let check_clingo () =
	if not (has_clingo ()) then
		failwith "Clingo version 4 is required (http://sourceforge.net/projects/potassco/files/clingo/)"


let solver () =
	check_clingo ();
	dbg ~level:2 "Invoking clingo...";
	Unix.open_process "clingo --verbose=0 -"

let decl asp pred =
	let s = pred^".\n"
	in
	dbg_noendl ~level:5 s;
	output_string (snd asp) s;
	asp

let decls asp preds =
	let decl = decl asp
	in
	let decl p = ignore(decl p)
	in
	List.iter decl preds;
	asp

let sat (cin, cout) =
	close_out cout;
	let rec get_last_line last_line =
		try
			let last_line = input_line cin
			in
			dbg ~level:2 last_line;
			get_last_line last_line
		with End_of_file -> last_line
	in
	let last_line = get_last_line ""
	in
	let ret = last_line = "SATISFIABLE"
	in
	ignore(Unix.close_process (cin, cout));
	ret
