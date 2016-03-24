
open Debug

open PintTypes

open LocalCausalityGraph
open AutomataNetwork

open Ph_types

open ASP_solver

let any_instance = "LCG"

let automaton_asp a =
	"\""^a^"\""

let obj_asp (a,i,j) =
	"obj("^automaton_asp a^","^string_of_int i^","^string_of_int j^")"

let sol_asp obj n =
	"sol("^obj_asp obj^","^string_of_int n^")"

let ls_asp (a,i) =
	"ls("^automaton_asp a^","^string_of_int i^")"

let edge_asp ?(instance=any_instance) n1 n2 =
	"edge("^instance^","^n1^","^n2^")"

let init_asp ?(instance=any_instance) a i =
	"init("^instance^","^automaton_asp a^","^string_of_int i^")"

let indep_asp ?(instance=any_instance) a i ls2 =
	"indep("^instance^","^automaton_asp a^","^string_of_int i^","^ls_asp ls2^")"

let bool_asp a =
	"boolean("^automaton_asp a^")"


let unordua_asp = [
	(* objective per initial state *)
	"edge(LCG,ls(A,I),obj(A,J,I)) :- edge(LCG,_,ls(A,I)), init(LCG,A,J)";

	"conn(LCG,X,Y) :- edge(LCG,X,Y)";
	"conn(LCG,X,Y) :- edge(LCG,X,Z), conn(LCG,Z,Y)";
	":- conn(LCG,X,X)"; (* no cycle *)
	(* context saturation *)
	"init(LCG,A,I) :- edge(LCG,N,ls(A,I)), N != goal";
	(* sufficient continuity *)
	"edge(LCG,obj(A,I,J),obj(A,K,J)) :- not boolean(A), conn(LCG,obj(A,I,J),ls(A,K)), J != K";
	(* synchronisation independence *)
	":- indep(LCG,A,I,ls(A,J)), I != J";
	"indep(LCG,A,I,N) :- indep(LCG,A,I,ls(B,J)), B != A, edge(LCG,ls(B,J),N)";
	"indep(LCG,A,I,N) :- indep(LCG,A,I,obj(B,J,K)), edge(LCG,obj(B,J,K),N)";
	"indep(LCG,A,I,N) :- indep(LCG,A,I,sol(obj(B,J,K),L)), edge(LCG,sol(obj(B,J,K),L),N)";
]

let asp_lcg asp lcg =
	let nodesol_asp obj asp (i, n) =
		let orig = sol_asp obj i
		in
		let children = lcg#childs n
		in
		let asp = List.fold_left (fun asp ->
			(function NodeProc ai ->
				decl asp (edge_asp orig (ls_asp ai)^" :- "^edge_asp "_" orig)
			| _ -> asp)) asp children
		in
		match n with
		  NodeSyncSol (_, states, _) ->
			let asp_indep state asp =
				if SMap.cardinal state > 1 then
				let asp_indep_ls a i asp =
					SMap.fold (fun b j asp ->
						if b <> a then
							decl asp (indep_asp a i (b,j)^" :- "^edge_asp "_" orig)
						else asp) state asp
				in
				SMap.fold asp_indep_ls state asp else asp
			in
			StateSet.fold asp_indep states asp
		| _ -> asp
	in
	let nodeobj_asp n asp = match n with
		  NodeObj obj ->
			let orig = obj_asp obj
			in
			let children = lcg#childs n
			in
			let sols = List.filter (function NodeSol _ | NodeSyncSol _ -> true | _ -> false) children
			in
			let isols = List.mapi (fun i s -> (i,s)) sols
			in
			let buf =
				match sols with [] -> "" | _ ->
					let asp_sols = List.mapi (fun i _ ->
						edge_asp orig (sol_asp obj i)) sols
					in
					"1 {"^(String.concat "; " asp_sols)^"} 1 "
			in
			let asp = decl asp (buf^":- "^edge_asp "_" orig)
			in
			List.fold_left (nodesol_asp obj) asp isols

		| _ -> asp
	in
	NodeSet.fold nodeobj_asp lcg#nodes asp

let asp_ctx ?(instance=any_instance) asp ctx =
	SMap.fold (fun a is asp ->
		ISet.fold (fun i asp ->
			decl asp (init_asp ~instance a i)) is asp) ctx asp

let unordered_ua an ctx goal sols =
	dbg ~level:1 ". unordered under-approximation (ASP implementation)";
	let asp = solver ()
	in
	let asp = SSet.fold (fun a asp -> decl asp (bool_asp a))
				(boolean_automata an) asp
	and instance = "uua"
	in
	let lcg = new glc oa_glc_setup ctx goal sols make_unord_sol
	in
	lcg#set_auto_conts false;
	lcg#build;
	lcg#saturate_ctx;
	let asp = asp_lcg asp lcg
	in
	let asp = asp_ctx ~instance asp ctx
	in
	let goal = List.rev goal
	in
	let gl, pre_goals = List.hd goal, List.tl goal
	in
	let asp = List.fold_left (fun asp ai ->
		decl asp (edge_asp ~instance "root" (ls_asp ai))) asp pre_goals
	in
	let asp = decl asp (edge_asp ~instance "goal" (ls_asp gl))
	in
	let asp = decls asp unordua_asp
	in
	let asp = decl asp "#show edge/3"
	in
	sat asp


