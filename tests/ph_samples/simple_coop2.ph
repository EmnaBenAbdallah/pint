
process a 1
process b 1
process c 1

GRN([
	a 1 -> + c;
	b 1 -> + c
])

COOPERATIVITY([a;b] -> c 0 1, [[1;1]])



