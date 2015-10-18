---
layout: default
title: Usage
category_title: Documentation
---

Tools are compiled into the <code>bin</code> directory, except for model importation tools
residing within the <code>converters</code> directory.

Most commands display their usage when using the <code>--help</code> option.

#### Commands index

<table>
<tr><th>Command</th><th>Short description</th></tr>
<tr><td style="font-style:italic;" colspan="2">Simulation tools</td></tr>
<tr><td><code>ph-exec</code></td><td>Stochastic simulation (Process Hitting
models)</td></tr>
<tr><td style="font-style:italic;" colspan="2">Analysis tools</td></tr>
<tr><td><code>pint-stable</code></td><td>Stable states listing</td></tr>
<tr><td><code>pint-reach</code></td><td>Static analysis of reachability</td></tr>
<tr><td><code>ph-reach</code></td><td>Static analysis of reachability (Process
Hitting)</td></tr>
<tr><td><code>pint-sg</code></td><td>State graph analysis</td></tr>
<tr><td><code>pint-lcg</code></td><td>Local Causality Graph computation</td></tr>
<tr><td><code>pint-its</code></td><td>Model-checking with <em>ITS</em></td></tr>
<tr><td><code>pint-mole</code></td><td>Model-checking with <em>mole</em></td></tr>
<tr><td style="font-style:italic;" colspan="2">Model exportation tools</td></tr>
<tr><td><code>pint-export</code></td><td>Automata Network exportation</td></tr>
<tr><td><code>phc</code></td><td>Process Hitting exportation</td></tr>
<tr><td><code>ph2thomas</code></td><td>Process Hitting to Thomas network</td></tr>
<tr><td style="font-style:italic;" colspan="2">Model importation tools</td></tr>
<tr><td><code>CNA2an</code></td><td><em>CellNetAnalyser</em> to AN</td></tr>
<tr><td><code>ginml2an</code></td><td><em>GINsim</em> to AN</td></tr>
<tr><td style="font-style:italic;" colspan="2">Pint library interface</td></tr>
<tr><td><code>pint</code></td><td>Pint+OCaml interactive toplevel</td></tr>
<tr><td><code>pintc</code></td><td>Pint+OCaml native-code compiler</td></tr>
<tr><td><code>pint-config</code></td><td>Pint installation information</td></tr>
</table>

#### Input formats

Commands starting with <code>pint</code> accept <a href="syntax-an.html">Automata Network (AN) format</a>
(<code>.an</code>).

Commands starting with <code>ph</code> accept <a href="syntax-ph.html">Process Hitting (PH) format</a>
(<code>.ph</code>).

Process Hitting models can be converted to AN format with the following command:

	$ phc -l an -i model.ph -o model.an --coop-priority


#### Common options

The majority of commands dealing with Process Hitting models take use of the following options.

<dl>

<dt><code>--debug</code> / <code>--no-debug</code></dt>
<dd>Enable / disable debug messages (debug messages are usually written to the standard error
output).</dd>

<dt><code>-i &lt;filename&gt;</code></dt>
<dd>Use <code>filename</code> as source for the Process Hitting model. If omitted, the source is
read from the standard input.</dd>

<dt><a name="opt_initial_state"></a><code>--initial-state &lt;process_list&gt;</code></dt>
<dd>Override the initial state of the model with the provided processes.<br />
<em>Example:</em><br />
<code>ph-reach -i model.ph --initial-state "a 0, b 1" a 2</code><br />
run the analysis on the Process Hitting having the initial processes of sorts <code>a</code> and
<code>b</code> set to <code>a 0</code> and <code>b 1</code>, respectively.
</dd>

</dl>

