{
open Ph_parser;;

let line_incr lexbuf =
	let pos = Lexing.lexeme_end_p lexbuf in
	let pos = {pos with Lexing.pos_lnum = pos.Lexing.pos_lnum+1; Lexing.pos_bol = pos.Lexing.pos_cnum}
	in
	lexbuf.Lexing.lex_curr_p <- pos
;;

}

let digit = ['0'-'9']
let name = ['A'-'z']['A'-'z' '0'-'9']*

rule lexer = parse
  [' ' '\t' '\r']	{ lexer lexbuf }
| '\n' {line_incr lexbuf; lexer lexbuf}
| "process" { New }
| "directive" { Directive }
| "sample" { Sample }
| "stochasticity_absorption" { Stoch_abs }
| "REGULATION(" { MacroREGULATION (regulation lexbuf) }
| "->" { Hit }
| "@" { At }
| "~" { Absorb }
| "," { Comma }
| "initial_state" { Initial }
| digit+ as value { Int (int_of_string value) }
| name as n { Name n }
| digit+ "." digit* as rate	{ Float (float_of_string rate) }
| eof { Eof }
| "(*"	{ comment 1 lexbuf } 

and comment n = parse
 | "(*"  		{ comment (n+1) lexbuf } 
 | '\n' 		{ line_incr lexbuf; comment n lexbuf}
 | "*)" 		{ if (n-1) > 0 then comment (n-1) lexbuf else lexer lexbuf} 
 |  _ 			{ comment n lexbuf } 

and regulation = parse
  [' ' '\t' '\r']	{ regulation lexbuf }
 | '\n'			{line_incr lexbuf; regulation lexbuf}
 | ['+' '-'] as sign	{ RegulationSign sign }
 | name as n	{ RegulationGene n }
 | digit+ as v	{ RegulationThreshold v }
 | "->"			{ regulation lexbuf }
 | ")"			{ lexer lexbuf }

