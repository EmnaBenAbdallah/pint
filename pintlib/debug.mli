(** Debugging control. *)

(** Set to [true] if debug messages should be displayed. *)
val dodebug : bool ref

(** Maximum debug level to display *)
val debuglevel : int ref

(** [dbglevel ()] returns the maximum debug level (0 for none) *)
val dbglevel : unit -> int

(** [dbg msg] prints [msg^"\n"] to standard error channel. *)
val dbg : ?level:int -> string -> unit

(** [dbg_noendl] prints [msg] to standard error channel. *)
val dbg_noendl : ?level:int -> string -> unit

val tic : unit -> float
val toc : ?level:int -> ?label:string -> float -> unit

