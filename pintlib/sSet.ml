
module type SSetCfg =
sig
	type t
	val compare: t -> t -> int
	val max_h: int
	val string_of_elt: t -> string
end

module Make (Cfg: SSetCfg) =
struct

	module NodeMap = Map.Make (struct type t = Cfg.t let compare a b = - Cfg.compare a b end)

	type elt = NodeMap.key
	type t = Nodes of (t NodeMap.t * int) | One | Zero

	let string_of_elt = Cfg.string_of_elt

	let to_dot a =
		let rec string_of_tree i = function
		  One -> 
			[i], "n" ^ string_of_int i ^ "[shape=box,label=1];\n", i+1
		| Zero -> 
			[i], "n" ^ string_of_int i ^ "[shape=box,label=0];\n", i+1
		| Nodes (nm, _) ->
			let fold n a (is, buf, i) =
				let nis, nbuf, i = string_of_tree i a
				in
				let nbuf = nbuf ^ "n"^string_of_int i^"[label=\""^string_of_elt n^"\"];\n"
					^ String.concat "\n" 
						(List.map (fun j -> "n"^string_of_int i^" -> n"^string_of_int j^";") nis)
				in
				i::is, buf^nbuf, i+1
			in
			NodeMap.fold fold nm ([], "", i)
		in
		let _, buf, _ = string_of_tree 0 a
		in
		"digraph{\n" ^ buf ^ "}\n"

	let empty = Zero
	let singleton e = Nodes (NodeMap.singleton e One, 1)

	(* cleanup a: remove paths leading to Zero *)
	let rec cleanup = function Zero -> Zero | One -> One
		| Nodes (nm, h) ->
			let nm = NodeMap.map cleanup nm
			in
			let nm = NodeMap.filter (fun n a -> match a with Zero -> false | _ -> true) nm
			in
			if NodeMap.is_empty nm then Zero else Nodes (nm, h)

	let rec level_up = function Zero -> Zero | One -> One
		| Nodes (nm, h) -> if h >= Cfg.max_h then Zero else Nodes (NodeMap.map level_up nm, h+1)

	(* cleanup a: remove paths leading to Zero *)
	let rec clean_level_up = function Zero -> Zero | One -> One
		| Nodes (nm, h) ->
			if h >= Cfg.max_h then Zero else
			let nm = NodeMap.map clean_level_up nm
			in
			let nm = NodeMap.filter (fun n a -> match a with Zero -> false | _ -> true) nm
			in
			if NodeMap.is_empty nm then Zero else Nodes (nm, h+1)

	let rec union a b =
		match (a,b) with
		  (One, _) | (_, One) -> One
		| (Zero, a) | (a, Zero) -> a
		| (Nodes (nma, ha), Nodes (nmb, hb)) ->
			assert (ha = hb);
			let fold n a nm =
				let a = try union a (NodeMap.find n nm) with Not_found -> a
				in
				NodeMap.add n a nm
			in
			let nm = NodeMap.fold fold nma nmb
			in
			Nodes (nm, ha)

	let rec product a b =
		match (a,b) with
		  (Zero, _) | (_, Zero) -> Zero
		| (One, a) | (a, One) -> a
		| (Nodes (nma, ha), Nodes (nmb, hb)) ->
			assert (ha = hb);
			let fold n a c =
				let nm2, a', nm = NodeMap.split n nmb
				in
				let nm = if NodeMap.is_empty nm then nm else
							let a = clean_level_up (Nodes (NodeMap.singleton n a, ha))
							in
							NodeMap.map (product a) nm
				and a' = match a' with None -> Zero | Some a' -> product a a'
				and b = if NodeMap.is_empty nm2 then Zero else
							product a (clean_level_up (Nodes (nm2, ha)))
				in
				let a = union a' b
				in
				let nm = match a with Zero -> nm | a -> NodeMap.add n a nm
				in
				union c (Nodes (nm, ha))
			in
			NodeMap.fold fold nma Zero
	
	let rec rm_sursets a p =
		match (a,p) with
		  (_, One) -> Zero
		| (_, Zero) | (One, _) | (Zero, _) -> a
		| (Nodes (nma, ha), Nodes (nmp, hp)) ->
			failwith "TODO"

	let simplify a = failwith "TODO"

	let equal a b = failwith "TODO"

	let compare a b = failwith "TODO"

end

