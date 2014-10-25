(*
Copyright or © or Copr. Loïc Paulevé (2013)

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

(** [resolve !Ph_instance.cooperativities ctx ab] returns the set of process indexes that are
		coherent with ctx *)
val resolve: (Ph_types.sort list * (Ph_types.sortidx list -> int)) PintTypes.SMap.t
					-> Ph_types.ctx -> Ph_types.sort -> Ph_types.sortidx list


(** [local_fixed_points !Ph_instance.cooperativities ph ai] returns the list of semi-global states
		which are sufficient to ensure ai (local) stability *)
val local_fixed_points: ?level1:bool -> 'a PintTypes.SMap.t -> Ph_types.ph -> Ph_types.process -> Ph_types.state list


val build_reflection: ?coop_label:string option -> ?rsa:PintTypes.stochatime -> (string -> int)
						-> string list
			-> (string * (string list * (Ph_types.sortidx list -> int)))
				* (Ph_types.process * (Ph_types.action * PintTypes.stochatime) list) option

val build_cooperation: ?coop_label:string option -> ?rsa:PintTypes.stochatime -> (string -> int)
						-> Ph_types.state_matching_t
			-> string * (int list * int list) * (Ph_types.process list * (Ph_types.action * PintTypes.stochatime) list)

val regulators: Ph_instance.cooperativities_t -> string -> PintTypes.SSet.t

val coherent_ctx: Ph_instance.cooperativities_t -> Ph_types.ctx -> Ph_types.ctx

