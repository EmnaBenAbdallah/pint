%{
let merge_decl ((ps,aps),hits) (p,real) =
	let merge_metaproc ps (p,l) =
		try
			let ol = List.assoc p ps
			in
			if ol > l then
				failwith "Cannot decrease metaprocess levels"
			else (p,l)::List.remove_assoc p ps
		with Not_found -> (p,l)::ps
	in
	let ps, aps =
		if real then merge_metaproc ps p, aps
		else ps, merge_metaproc aps p
	in
	((ps,aps),hits)
;;
let merge_instr ((ps,aps),hits) (p1,p2,l,r) = 
	let assert_p_exists (name,level) =
		let errstr = "Invalid reference to process "^name^(string_of_int level)^": "
		in
		try
			let ml = List.assoc name (ps@aps)
			in
			if level < 0 || ml < level then 
				failwith (errstr^"level out of bound (max is "^(string_of_int ml)^")")
		with Not_found -> failwith (errstr^"undefined metaprocess")
	in
	assert_p_exists p1;
	assert_p_exists p2;
	assert_p_exists (fst p2, l);
	Hashtbl.add hits p2 ((p1, r),l);
	((ps,aps),hits)
;;
%}

%token <int> Level
%token <string> Name
%token <float> Float
%token <int> PosInt
%token New Art Hit At Eof
%token Directive Sample StochAbs

%start main
%type <(string * string) list * Ph_types.ph> main

%%
process :
  Name Level	{ ($1, $2) }
;
decl :
  New process	{ ($2, true) }
| Art New process { ($3, false) }
;
instr : 
  process Hit process Level			{ ($1, $3, $4, Ph_types.RateInf) }
| process Hit process Level At Float { ($1, $3, $4, Ph_types.Rate $6) }
;
content :
  content decl { merge_decl $1 $2 }
| content instr { merge_instr $1 $2 }
| decl		 { merge_decl (([],[]),Hashtbl.create 0) $1 }
;

header :
  Sample Float { ("sample",string_of_float $2) }
| StochAbs PosInt { ("stochasticity_absorption",string_of_int $2) }
;

headers :
  header { $1::[] }
| header Directive headers { $1::$3 }
;

main :
  Directive headers main2 { ($2,$3) }
| main2 { ([],$1) }
;
main2 :
  content Eof { $1 }
;
%%
