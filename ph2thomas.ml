(*
Copyright or © or Copr. Maxime Folschette, Loïc Paulevé (2012)

maxime.folschette@irccyn.ec-nantes.fr
loic.pauleve@ens-cachan.org

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

let opt_dotfile = ref ""
and opt_asp = ref ""
and opt_format = ref "active"
and opt_enum = ref false
and opt_fullenum = ref false
in
let cmdopts = Ui.common_cmdopts @ Ui.input_cmdopts @ [
	("--dot", Arg.Set_string  opt_dotfile, 
		"<graph.dot>\tExport the interaction graph to the given file.");
	("--debug-asp", Arg.Set_string  opt_asp, 
		"<file.lp>\tExport the generated ASP program.");
	("--format", Arg.Symbol (["active"; "AB"; "iter"], (fun x -> opt_format := x)),
		("\tParameter format (default: "^ (!opt_format) ^")."));
	("--enumerate", Arg.Set opt_enum, "\tPerform parameterization enumeration.");
	("--full-enumerate", Arg.Set opt_fullenum, "\tPerform parameterization enumeration, including intervals.");
	]
and usage_msg = "ph2thomas [opts]"
in
let anon_fun _ = (Arg.usage cmdopts usage_msg; raise Exit)
in
Arg.parse cmdopts anon_fun usage_msg;

let cmdopts = Ui.common_cmdopts @ Ui.input_cmdopts
and usage_msg = "ph-stable"
in
let anon_fun _ = (Arg.usage cmdopts usage_msg; raise Exit)
in
Arg.parse cmdopts anon_fun usage_msg;

let check_clingo () =
	if Sys.command "clingo -v" <> 0 then
		failwith ("The program 'clingo' is not in your path. Please download it at "
					^"http://sourceforge.net/projects/potassco/files/clingo/")
in

check_clingo ();
let asp_path = Filename.concat Distenv.pint_share_path "contrib/ph2thomas"
in

let debug_asp data =
	if !opt_asp <> "" then
		let cout = open_out !opt_asp
		in
		(output_string cout data;
		close_out cout)

(*
and readall cin =
	let bs = 2048
	in
	let buffer = Buffer.create bs
	in
	let string = String.create bs
	and chars_read = ref 1
	in
	while !chars_read <> 0 do
		chars_read := input cin string 0 bs;
		Buffer.add_substring buffer string 0 !chars_read
	done;
	close_in cin;
	Buffer.contents buffer;
*)
in

let run_process_io cmdline input_data =
	dbg cmdline;
	let pin, pout = Unix.open_process cmdline
	in
	output_string pout input_data;
	close_out pout;
	pin
in

let ph, ctx = Ph_util.parse !Ui.opt_channel_in
in

let asp_data = Ph_translator.asp_of_ph ph ctx
in
debug_asp asp_data;

let clauses = Ph2thomas_coop.create_clauses ()
in
Ph2thomas_coop.input_clauses clauses (run_process_io 
	("clingo 0 --verbose=0 "^(Filename.concat asp_path "phinfercoop.lp")^" -")
		asp_data);
(*
Ph2thomas_coop.input_clauses clauses (run_process_io 
	("clingo 0 --verbose=0 "^(Filename.concat asp_path "phinfercoop1.lp")^" -")
		asp_data);
Ph2thomas_coop.input_clauses clauses (run_process_io 
	("clingo 0 --verbose=0 "^(Filename.concat asp_path "phinfercoop2.lp")^" -")
		asp_data);*)

let asp_coop = Ph2thomas_coop.asp_of_clauses clauses
in

let asp_data = asp_data ^ asp_coop
in
debug_asp asp_data;

dbg "Inferring Interaction Graph...";
let igin = run_process_io
	("clingo 0 --verbose=0 "^(Filename.concat asp_path "phinferIG.lp")^" -")
		asp_data
in
let ig = Ph2thomas_ig.input_graph igin
in
(if !opt_dotfile <> "" then
	let cout = open_out !opt_dotfile
	in
	(output_string cout (Ph2thomas_ig.dot_of_graph ig);
	close_out cout)
);
let asp_data = asp_data ^ (Ph2thomas_ig.asp_of_graph ig)
in
debug_asp asp_data;

dbg "Inferring Parameters..";
let pin = run_process_io
	("clingo 0 --verbose=0 "^(Filename.concat asp_path "phinferK.lp")^" -")
		asp_data
in
let params = Ph2thomas_param.input_params pin ig
in
let string_of_params = 
	match !opt_format with
		  "AB" -> Ph2thomas_param.string_AB_of_params
		| "active" -> Ph2thomas_param.string_active_of_params
		| "iter" -> Ph2thomas_param.string_iter_of_params
		| f -> failwith ("Invalid format '" ^ f ^ "'")
in
print_string (string_of_params ig params);
flush_all ();

if !opt_enum or !opt_fullenum then (
	let asp_data = asp_data ^ (Ph2thomas_param.asp_for_enum ig params)
	in
	debug_asp asp_data;
	let cmdline = "clingo 0 --verbose=1 "^(Filename.concat asp_path "phenumK.lp")^" -"
	in
	dbg cmdline;
	let pout = Unix.open_process_out cmdline
	in
	(if not !opt_fullenum then
		output_string pout 
			":- enum_param(A,P,I), enum_param(A,P,J), I != J, not infered_param(A,P).\n"
	);
	output_string pout asp_data;
	ignore(Unix.close_process_out pout);
)

