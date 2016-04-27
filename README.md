depgraph.jl
==========

A set of simple tools to generate and analyse dependency graphs between object
files. It is written in Julia.

Julia package dependencies:

* JLD
* ArgParse
* LightGraphs (>0.5.2)

From your Julia prompt, running the following commands will install all the
dependencies:

    julia> Pkg.add("JLD")
    julia> Pkg.add("ArgParse")
    julia> Pkg.add("LightGraphs")
    julia> Pkg.checkout("LightGraphs")


Usage
-----

Start by running `extract-depgraph.jl` on a bunch of object files. The script
will use the `nm` command to extract the symbols. It will then construct a
dependency graph between the object files and serialize it to a `.jld` file.

You can then analyse the resulting dependency graph using the
`analyse-depgraph.jl` tool. This will read in the graph and convert it to
`.dot` format, suitable for plotting with [GraphViz][1]. Furthermore, you can
optionally [condense][2] the graph (`-c` switch) and apply [transitive
reduction][3] (`-t` switch). Finally, you can use the `-f` switch to limit the
graph to the neighbourhood of one or more nodes; the `-n` switch controls the
size of the neighbourhood.

[1]: http://www.graphviz.org
[2]: https://en.wikipedia.org/wiki/Strongly_connected_component
[3]: https://en.wikipedia.org/wiki/Transitive_reduction


Examples
--------

Construct a dependency graph:

    $ ./extract-depgraph.jl -o depgraph.jld foo.o bar.o baz.o quux.o

Inspect the neighborhood of node `bar`; i.e. nodes that can be reached from
`bar`; object files on which `bar.o` depends:

    $ ./analyse-depgraph.jl -f bar -o bar.dot depgraph.jld

Likewise, for the joint neighbourhood of nodes `bar` and `baz`:

    $ ./analyse-depgraph.jl -f bar -f baz -o bar-baz.dot depgraph.jld

Limit the neighborhood to distance 2:

    $ ./analyse-depgraph.jl -f bar -n 2 -o bar.dot depgraph.jld

Convert the resulting `.dot` file to PDF:

    $ dot -Tpdf bar.dot >bar.pdf
