`depgraph.jl`
=============

A set of simple tools to generate and analyse dependency graphs between object
files. It is written in Julia.

Julia package dependencies:

* [JLD](JLD)
* [ArgParse](ArgParse)
* [LightGraphs](LightGraphs) (>0.5.2)

From your Julia prompt, running the following commands will install all the
dependencies:

```julia
julia> Pkg.add("JLD")
julia> Pkg.add("ArgParse")
julia> Pkg.add("LightGraphs")
julia> Pkg.checkout("LightGraphs")
```


Usage
-----

Start by running `extract-depgraph.jl` on a bunch of object files. The script
will use the `nm` command to extract the symbols. It will then construct a
dependency graph between the object files and serialize it to a `.jld` file.

You can then analyse the resulting dependency graph using the
`analyse-depgraph.jl` tool. This will read in the graph and convert it to
`.dot` format, suitable for plotting with [GraphViz][GraphViz]. Furthermore,
you can optionally [condense][SCC] the graph (`-c` switch) and apply
[transitive reduction][TR] (`-t` switch). Finally, you can use the `-f` switch
to limit the graph to the neighbourhood of one or more nodes; the `-n` switch
controls the size of the neighbourhood.

[JLD]: https://github.com/JuliaLang/JLD.jl
[ArgParse]: https://github.com/carlobaldassi/ArgParse.jl
[LightGraphs]: https://github.com/JuliaGraphs/LightGraphs.jl
[GraphViz]: http://www.graphviz.org
[SCC]: https://en.wikipedia.org/wiki/Strongly_connected_component
[TR]: https://en.wikipedia.org/wiki/Transitive_reduction


Examples
--------

Construct a dependency graph from some object files:
```bash
$ ./extract-depgraph.jl -o depgraph.jld foo.o bar.o baz.o quux.o
```

Inspect the neighbourhood of node `bar`. This is the set of nodes that can be
directly or indirectly reached from `bar`, i.e. the set of object files on
which `bar.o` depends:
```bash
$ ./analyse-depgraph.jl -f bar -o bar.dot depgraph.jld
```

Likewise, for the joint neighbourhood of nodes `bar` and `baz`:
```bash
$ ./analyse-depgraph.jl -f bar -f baz -o bar-baz.dot depgraph.jld
```

Limit the neighbourhood to distance 2:
```bash
$ ./analyse-depgraph.jl -f bar -n 2 -o bar.dot depgraph.jld
```

Inspect the *ascending* neighbourhood of node `bar`, i.e. the set of object
files which (directly or indirectly) depend on `bar.o`:
```bash
$ ./analyse-depgraph.jl -f bar -n 2 -d in -o bar.dot depgraph.jld
```

Likewise, but do not add dangling arrows for dependencies that have been cut by
the `-n` option:
```bash
$ ./analyse-depgraph.jl -f bar -n 2 -d in --hide-ellipsis-edges -o bar.dot depgraph.jld
```

Convert the resulting `.dot` file to PDF:
```bash
$ dot -Tpdf bar.dot >bar.pdf
```
