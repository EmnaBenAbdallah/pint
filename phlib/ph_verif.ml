
open Big_int;;

open Ph_types;;
open Ph_op;;
open Ph_util;;

module EMap = Map.Make (struct type t = process * string
	let compare = compare end);;

let stable_states (ps,hits) =
	(*DEBUG*) print_endline ". hitless graph";
	let v, e = hitless_graph (ps,hits)
	and sigma = fst (List.split ps)
	in
	(*DEBUG*) print_endline " OK";
	(* Fill E *)
	let register_couple ((a,i),(b,j)) _E =
		let register_couple _E ((a,i),(b,j)) =
			let key = ((a,i),b)
			in
			let prev = try EMap.find key _E with Not_found -> []
			in
			EMap.add key ((b,j)::prev) _E
		in
		let _E = register_couple _E ((a,i),(b,j))
		in
		register_couple _E ((b,j),(a,i))
	in
	(*DEBUG*) print_endline ". fill E";
	let _E = PCSet.fold register_couple e (EMap.empty);
	in
	(*DEBUG*) print_endline " OK";
	(* Prune E *)
	let _E_remove _E ai =
		(* remove E_ai *)
		let folder _E b =
			EMap.remove (ai,b) _E
		in
		let _E = List.fold_left folder _E sigma
		in
		(* remove (a,i) from all others *)
		EMap.map (fun eb -> Util.list_remove ai eb) _E
	in
	let rec prune v _E =
		(*DEBUG*) print_endline ". prune";
		let has_empty (a,i) =
			let check b =
				if b <> a then
					let v = EMap.find ((a,i),b) _E
					in
					if v = [] then raise Not_found
			in
			try List.iter check sigma; false
			with Not_found -> true
		in
		let to_rm, v = List.partition has_empty v
		in 
		match to_rm with [] -> v,_E | _ -> (
			let _E = List.fold_left _E_remove _E to_rm
			in
			(*DEBUG*) print_endline " OK (recur)";
			prune v _E
		)
	in
	let v,_E = prune v _E
	in
	(*DEBUG*) print_endline " DONE";

	(* Choose the smallest E_a *)
	let count ((a,i),b) eb cE =
		let prev = try SMap.find a cE with Not_found -> 0
		in
		SMap.add a (prev + List.length eb) cE
	in
	let cE = EMap.fold count _E SMap.empty
	in
	let smaller a' c' (a,c) =
		if c' < c || c < 0 then (a',c') else (a,c)
	in
	let a = fst (SMap.fold smaller cE ("",-1))
	in
	(*DEBUG*) print_endline (". using "^a); 

	(* Cross product E_a and test for cliques *)
	let folder stable_states ai =
		let get_Eaib b = if b = a then [ai]
			else EMap.find (ai,b) _E
		in
		let to_test = List.rev (List.map get_Eaib sigma)
		in
		(*DEBUG*) print_endline (". testing "^string_of_big_int 
				(List.fold_left (fun c l -> mult_int_big_int (List.length l) c)
					unit_big_int to_test)^" states");

		let test_surclique clique bj =
			List.for_all (fun ai -> PCSet.mem (ai,bj) e) clique
		in
		let rec build_cliques clique = function
			  [] -> [clique]
			| bjs::parts ->
				let mapper bj =
					if test_surclique clique bj then
						build_cliques (bj::clique) parts
					else []
				in
				List.flatten (List.map mapper bjs)
		in
		stable_states @ build_cliques [] to_test
	in
	let ais = List.filter (fun (b,j) -> a = b) v
	in
	List.fold_left folder [] ais
;;

let string_of_sortdomain (z,lz') =
		z^"_{"^(String.concat "," (List.map string_of_int lz'))^"}"
;;
module BM = Bool.Manipulator (struct
	type t = (sort * sortidx list)
	let to_string x = "harmful("^string_of_sortdomain x^")"
	let tautology _ _ = false
end);;

let __harmless_prepare (ps,hits) (z,lz') harmless =
	(********************)
	(* I. local key actions for reaching lz' *)

	(* index actions on z by their bounce *)
	(* zhits : (bounce idx, (hitter, target idx)) Hashtbl *)
	let zhits = Hashtbl.create (List.assoc z ps + 1)
	in
	let reindex (b,j) ((ai,p),j') =
		if b = z then Hashtbl.add zhits j' (ai,j)
	in
	Hashtbl.iter reindex hits;

	(* compute local key actions *)
	(* keyactions: (hitter, target idx, bounce idx) list list *)
	let rec build_keyactions omap lz' cur_order =
		(* set lz' order to cur_order *)
		let omap = List.fold_left (fun omap i -> set_order omap (z,i) cur_order)
					omap lz'
		in
		(* get actions making z bounce to a process in lz' *)
		let actions = List.flatten (List.map (fun j' -> 
				List.map (fun (ai,j) -> (ai,j,j'))
					(Hashtbl.find_all zhits j')
			) lz')
		in 
		(* keep actions having target with bottom order (key actions) *)
		let actions = List.filter (function (_,j,_) -> order omap (z,j) = Bot) actions
		in
		(* extract concerned targets *)
		let lz' = Util.list_uniq (List.map (function (_,j,_) -> j) actions)
		in
		match actions with [] -> omap, []
			| _ -> let omap, keyactions = build_keyactions omap lz' (cur_order+1)
				in omap, actions::keyactions
	in
	let omap, keyactions = build_keyactions omap_empty lz' 0
	in
	
	(* DEBUG *
	print_endline "- keyactions";
	let string_of_action (ai,j,j') = string_of_process ai^"->"^
			string_of_process (z,j)^" "^string_of_int j'
	in
	let rec debug_keyactions n = function [] -> ()
		| actions::keyactions -> (
			print_endline ("K^"^string_of_int n^" : ["^
				(String.concat "; " (List.map string_of_action actions))^"]");
			debug_keyactions (n+1) keyactions )
	in
	debug_keyactions 0 keyactions;
	* END DEBUG *)

	(********************)
	(* II. compute p-harmless for each z_i \in L_z *)

	(* p_harmless : (idx, (sort,idx list) Bool.expr) Hashtbl *)
	let p_harmless = Hashtbl.create (List.assoc z ps+1)
	in

	(* sort z_is along their order *)
	let lz = List.sort (fun i i' -> compare (order omap (z,i)) (order omap (z,i')))
				(Util.range 0 (List.assoc z ps))
	in
	let compute_p_harmless i = 
		let expr = match order omap (z,i) with
			  Bot -> Bool.T
			| Order 0 -> Bool.F
			| Order n ->  
				(* group hitters by sort*bounce *)
				let group sg ((a,k),j,j') = if i <> j then sg else
					let la' = try PMap.find (a,j') sg with Not_found -> []
					in
					PMap.add (a,j') (k::la') sg
				in
				let sg = List.fold_left group PMap.empty (List.nth keyactions (n-1))
				in
				let folder (a,j') la' expr =
					let expr' = BM.expr_of_dnf (Hashtbl.find p_harmless j')
					in
					Bool.And (expr, Bool.Or (Bool.Not (Bool.L (a,la')), expr'))
				in
				PMap.fold folder sg Bool.T
		in
		(* DEBUG * print_endline "## computing dnfs..."; **)
		let dnf = BM.dnf expr
		in
		(* DEBUG * print_endline "## computing dnfs...OK"; **)
		Hashtbl.add p_harmless i dnf
	in
	List.iter compute_p_harmless lz;
	(* DEBUG *
	let iterator i =
		let dnf = Hashtbl.find p_harmless_dnf i
		in
		print_endline ("p-harmless("^z^string_of_int i^") = " ^ BM.string_of_dnf dnf)
	in
	List.iter iterator lz;
	* END DEBUG *)
	lz, p_harmless
;;

module BS = Bool.Manipulator (struct
	type t = process
	let to_string = string_of_process
	let tautology (harm, (a,i)) (harm', (a',i')) =
		a = a' && (harm = harm' && i<>i' || harm<> harm' && i=i')
end);;
let harmless (ps,hits) (z,lz') = 
	let register = Hashtbl.create (List.length ps)
	and computing = Hashtbl.create (List.length ps)
	in
	let rec harmless arg = (* caching harmless results *)
		try Hashtbl.find register arg with Not_found -> (
			Hashtbl.add computing arg true;
			(* DEBUG *) print_endline ("# computing harmless("^
							string_of_sortdomain arg^")");(**)
			let value = _harmless arg
			in
			Hashtbl.add register arg value;
			(* DEBUG *) print_endline ("# harmless("^
							string_of_sortdomain arg^") = "^
							BS.string_of_dnf value);(**)
			Hashtbl.remove computing arg;
			value
		)

	and _harmless (z,lz') =
		let lz, p_harmless_dnf = __harmless_prepare (ps,hits) (z,lz') harmless
		in
		(* DEBUG * print_endline "## resolving harmless..."; **)
		(* resolve harmless *)
		let p_harmless = Hashtbl.create (List.assoc z ps+1)
		in
		let iterator key dnf =
			let dnf = match dnf with None -> None | Some [] -> Some [] | Some lsets -> (
				let resolve lset = 
					let folder (harm,arg) dnf =
						let dnf' = match harm with
							  true -> failwith "harmful not implemented!"
							| false ->
								if Hashtbl.mem computing arg then (
									(* already computing, prevent infinite recursion!!
										assume True ???? XXX TODO *)
									(*DEBUG*) print_endline ("#! assume harmless("^string_of_sortdomain arg^")=True"); (**)
									Some []
								) else harmless arg
						in
						BS.dnf_conj dnf dnf'
					in
					BM.LSet.fold folder lset (Some [])
				in
				let folder dnf lset =
					BS.dnf_disj dnf (resolve lset)
				in
				List.fold_left folder None lsets
			)
			in
			Hashtbl.add p_harmless key dnf
		in
		Hashtbl.iter iterator p_harmless_dnf;
		(* DEBUG ) print_endline "## resolving harmless...OK"; **)
		(* DEBUG )
		let iterator i =
			let dnf = Hashtbl.find p_harmless i
			in
			print_endline ("p-harmless("^z^string_of_int i^") = " ^ BS.string_of_dnf dnf)
		in
		List.iter iterator lz;
		* END DEBUG *)

		(********************)
		(* III. compute harmless *)
		
		let harmless_i dnf i =
			BS.dnf_disj dnf (BS.dnf_conj (Some [BS.LSet.singleton (true,(z,i))])
								(Hashtbl.find p_harmless i))
		in
		List.fold_left harmless_i None lz
	in

	harmless (z,lz')
;;

type bsm_t = Proc of BS.Lit.t | Harmful of BM.Lit.t

module BSM = Bool.Manipulator (struct
	type t = bsm_t
	let to_string = function Proc x -> BS.Lit.to_string x 
		| Harmful x -> BM.Lit.to_string x
	let tautology x1 x2 = match x1, x2 with
		  (_,Proc _),(_,Harmful _) | (_,Harmful _),(_,Proc _) -> false
		| (h1,Proc x1),(h2,Proc x2) -> BS.Lit.tautology (h1,x1) (h2,x2)
		| (h1,Harmful x1), (h2,Harmful x2) -> BM.Lit.tautology (h1,x1) (h2,x2)
end);;
let harmless_noresolv (ps,hits) (z,lz') = 
	let register = Hashtbl.create (List.length ps)
	and computing = Hashtbl.create (List.length ps)
	in
	let rec harmless arg = (* caching harmless results *)
		try Hashtbl.find register arg with Not_found -> (
			Hashtbl.add computing arg true;
			(* DEBUG * print_endline ("# computing harmless("^
							string_of_sortdomain arg^")");**)
			let value = _harmless arg
			in
			Hashtbl.add register arg value;
			(* DEBUG *) print_endline ("# harmless("^
							string_of_sortdomain arg^") = "^
							BSM.string_of_dnf value);(**)
			Hashtbl.remove computing arg;
			value
		)

	and _harmless (z,lz') =
		let lz, p_harmless_dnf = __harmless_prepare (ps,hits) (z,lz') harmless
		in

		(* non-Resolving *)
		let p_harmless = Hashtbl.create (List.assoc z ps+1)
		in
		let iterator key dnf = 
			let dnf = match dnf with None -> None | Some lsets -> Some (
				let convert_lset lset =
					let folder (h,arg) lset' =
						match h with 
							  true -> failwith "harmful not implemented!"
							| false -> if not(Hashtbl.mem computing arg) then (
								ignore(harmless arg)
						);
						BSM.LSet.add (h,Harmful arg) lset'
					in
					BM.LSet.fold folder lset BSM.LSet.empty
				in
				List.map convert_lset lsets)
			in
			Hashtbl.add p_harmless key dnf
		in
		Hashtbl.iter iterator p_harmless_dnf;

		(********************)
		(* III. compute harmless *)
		
		let harmless_i dnf i =
			BSM.dnf_disj dnf (BSM.dnf_conj (Some [BSM.LSet.singleton (true,Proc (z,i))])
								(Hashtbl.find p_harmless i))
		in
		List.fold_left harmless_i None lz
	in

	ignore(harmless (z,lz'));
	((z,lz'),register)
;;

let solve_harmless (arg,harmless) state_contains = (* returns true if state is harmless for arg *)
	let register = Hashtbl.create 10
	and solving = Hashtbl.create 10
	in
	let rec solve_harmless arg =
		try Hashtbl.find register arg with Not_found -> (
			if Hashtbl.mem solving arg then (
				(* TODO check that!!! *)
				(*DEBUG*) print_endline ("#! assume solve("^string_of_sortdomain arg^")=True"); (**)
				true
			) else (
				Hashtbl.add solving arg true;
				let value = satisfy_dnf (Hashtbl.find harmless arg)
				in
				Hashtbl.add register arg value;
				value
			)
		)
	and satisfy_lit = function
		  (pos, Proc ai) -> pos == state_contains ai
		| (pos, Harmful arg) -> pos != solve_harmless arg
	and satisfy_dnf = function 
		  None -> false
		| Some [] -> true
		| Some lsets -> List.exists (BSM.LSet.for_all satisfy_lit) lsets
	in
	solve_harmless arg
;;


