(*
Copyright or © or Copr. Loïc Paulevé (2012)

loic.pauleve@irccyn.ec-nantes.fr

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

open Big_int;;
open Ph_types;;

let cmdopts = Ui.common_cmdopts @ Ui.input_cmdopts
and usage_msg = "ph-stable"
in
let anon_fun _ = (Arg.usage cmdopts usage_msg; raise Exit)
in
Arg.parse cmdopts anon_fun usage_msg;

let (sorts_def, actions) = fst (Ph_util.parse !Ui.opt_channel_in)
in

let nb_states = Ph_util.count_states (sorts_def, actions)
in
output_string stderr ("["^(!Ui.opt_filename_in)^"] total: "^string_of_big_int nb_states^" states\n"); flush stderr;

let register_action bj ((ai,_),_) hits = (ai,bj)::hits
in
let hits = Hashtbl.fold register_action actions []
in

let fps = Ph_fixpoint.fixpoints (sorts_def, hits)
in
print_endline (String.concat "\n" (List.map string_of_procs fps))
;;

