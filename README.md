#### Download

Binary packages for Ubuntu/Debian or Mac OS X, as well as Pint source code can be downloaded
from [github.com/pauleve/pint/releases](https://github.com/pauleve/pint/releases/).
The latest version of Pint is {{ site.pint_version }}.


#### Runtime requirements

Some of the tools may require [python](http://python.org).

- [clingo](http://sourceforge.net/projects/potassco/files/clingo/) is required by the tool
  `ph2thomas`.



#### Installation from sources

##### Compilation requirements

- [OCaml](http://caml.inria.fr) >= 3.12
- [CamlIDL](http://caml.inria.fr/pub/old_caml_site/camlidl/)
- [Facile](http://www.recherche.enac.fr/opti/facile/distrib)
- [Python](http://python.org)
- [libRmath](http://www.r-project.org) from R - debian/ubuntu: `r-mathlib`


##### Notes on libRmath requirement

Pint requires the libRmath standalone library for the stochastic simulation and parameters
inference from time interval specifications.
You can disable this functionnality by applying the patch
`patches/disable-R-bindings.patch`:

	$ patch -p0 patches/disable-R-bindings.patch

Most distributions provide a libRmath package (or include the libRmath.so library in the R package).

If you compile R from sources, after the configure step:

	(from R source directory)
	$ cd src/nmath/standalone
	$ make shared
	$ sudo make install


##### Compilation

In the root directory of sources:

	$ python setup.py
	$ make

If you installed libRmath in a custom location, use `CFLAGS` and `LDFLAGS` environment variables to indicate it:

	LDFLAGS=-L/usr/local/lib CFLAGS=-I/usr/local/include make

##### Installation

Add `<Pint source directory>/bin` to your `$PATH` environment variable.


