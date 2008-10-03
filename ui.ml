
let exists spi trace =
	print_endline (">>> exists "^(Inference.string_of_trace Spig.string_of_state trace));
	Inference.exists spi trace
;;

let proportion spi p trace =
	print_endline (">>> proportion "^(string_of_float p)^" "^(Inference.string_of_trace Spig.string_of_state trace));
	Inference.proportion spi p trace
;;

let make_spi spig constraints default_rate init_state =
	let valuation, equations = Valuation.valuation_of_constraints constraints
	in 
	assert (equations = []);
	Spig.spi_of_spig spig valuation default_rate init_state
;;

let print_constraints constraints =
	print_endline (Constraint.string_of_constraints Spig.string_of_rname constraints);
;;

let show_results constraints =
	print_constraints constraints;
	(try
		let valuation, equations = Valuation.valuation_of_constraints constraints
		in
			print_endline (Valuation.string_of_valuation Spig.string_of_rname valuation);
			if equations <> [] then (
				print_endline "TO SOLVE:";
				print_endline (String.concat "\n" (List.map (Valuation.string_of_equation Spig.string_of_rname) equations))
			)
	with Valuation.No_solution -> print_endline "NO SOLUTIONS!");
	print_endline ""
;;

