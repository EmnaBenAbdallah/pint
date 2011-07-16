
open Ph_types;;

let parse channel_in =
	let lexbuf = Lexing.from_channel channel_in
	in
	try 
		let ph, init_state = Ph_parser.main Ph_lexer.lexer lexbuf
		in
		ph, init_state
	with Parsing.Parse_error ->
		let show_position pos =
			  "Line " ^ string_of_int pos.Lexing.pos_lnum ^
			  " char " ^ string_of_int 
					(pos.Lexing.pos_cnum - pos.Lexing.pos_bol) ^ ": "
		in
		failwith (show_position (Lexing.lexeme_start_p lexbuf) ^
						"Syntax error")
;;

let matching (ps,hits) pred =
	let folder bj ((ai,p),j') matches =
		let action = Hit (ai,bj,j')
		in
		if pred action then action::matches else matches
	in
	Hashtbl.fold folder hits []
;;

