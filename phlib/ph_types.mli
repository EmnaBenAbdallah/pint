(** Process Hitting related types and associated operations. *)

module SSet : Set.S with type elt = string
module SMap : Map.S with type key  = string
module ISet : Set.S with type elt = int
module IMap : Map.S with type key = int

val string_of_set : ('a -> string) -> ('b -> 'a list) -> 'b -> string

(** String representation of an int Set. *)
val string_of_iset : ISet.t -> string

type ternary = True | False | Inconc

(** String representation of ternary. *)
val string_of_ternary : ternary -> string

type sort = string
type sortidx = int
type process = sort * sortidx
module PSet : Set.S with type elt = process
module PMap : Map.S with type key = process
module PCSet : Set.S with type elt = process * process

(** Retruns string representation of a process. *)
val string_of_proc : process -> string

(** Returns string representation of a process Set. *)
val string_of_procs : PSet.t -> string


type rate = (float * int) option
type hits = (process, (process * rate) * sortidx) Hashtbl.t
type ph = process list * hits

type action = Hit of (process * process * int)

(** String representation of an action. *)
val string_of_action : action -> string
(** String representation of a list of actions. *)
val string_of_actions : action list -> string
(** Returns the hitter process involved in the given action. *)
val hitter : action -> process
(** Returns the target process involved in the given action. *)
val target : action -> process
(** Returns the bounce process index involved in the given action. *)
val bounce : action -> int
(** Returns the bounce process involved in the given action. *)
val bounce2 : action -> process


type state = sortidx SMap.t

(** String representation of a state. *)
val string_of_state : int SMap.t -> string

(** Returns the state where all sorts have the process of index 0 present. *)
val state0 : process list -> state

(** [merge_states dest orig] sets the processes in the state [orig] in the state [dest]. *)
val merge_states : state -> state -> state

(** Sets the processes in the given process list present in the given state. *)
val merge_state_with_ps : state -> process list -> state

(** [state_value s a] returns the process index of sort a present in s. *)
val state_value : state -> sort -> sortidx

(** Converts a set into a list of processes. *)
val list_of_state : state -> process list

(** Returns the list of sorts defined in the given Process Hitting.*)
val ph_sigma : ph -> sort list

(** Directives of a Process Hitting model *)
type t_directive = {
  mutable default_rate : float option;
  mutable default_sa : int;
  mutable sample : float;
}
(** Default directives *)
val directive : t_directive

type objective = sort * sortidx * sortidx
module ObjSet : Set.S with type elt = objective
module ObjMap : Map.S with type key = objective

(** String representation of the given objective. *)
val string_of_obj : objective -> string

