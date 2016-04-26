#!/usr/bin/env julia

using ArgParse

arg_settings = ArgParseSettings()

@add_arg_table arg_settings begin
  "-o", "--output"
    help = "name of the dot output file"
    arg_type = AbstractString
  "-l", "--label-length"
    help = "maximum label length"
    arg_type = Int
    default = 20
  "DICTFILE"
    help = "file containing the dependency dictionary"
    arg_type = AbstractString
    required = true
end

parsed_args = parse_args(arg_settings)

if parsed_args["output"] == nothing
  output_filename = "depgraph.dot"
else
  output_filename = parsed_args["output"]
end

label_len = parsed_args["label-length"]
if label_len==nothing
  label_len = typemax(Int)
end

dict_filename = parsed_args["DICTFILE"]

# script starts here

using JLD       # for persistency
using LightGraphs

include("labelledgraph.jl")


info("loading dictionary...")
@load(dict_filename, depgraph)

info("converting to LightGraphs.DiGraph...")
graph = convert(LabelledDiGraph, depgraph)

info("generating subgraph...")
generator_indices = find(l -> contains(l, "geomROOT"), graph.labels)
subgraph = egonet(graph, generator_indices, typemax(Int))
info("subgraph has $(nv(subgraph)) vertices")

info("computing strongly connected components...")
scc, cond_labels = strongly_connected_components(subgraph)
nontrivial_scc = length(find(s -> length(s)>1, scc))
largest_scc = maximum(map(length, scc))
info("subgraph has $(length(scc)) scc ($nontrivial_scc non-trivial, ",
     "largest=$largest_scc)")

info("condensing...")
cond_depgraph = condensation(subgraph)

info("reducing...")
red_depgraph = transitive_reduce(cond_depgraph)
info("reduced subgraph has $(nv(red_depgraph)) vertices")

info("saving...")
to_dotfile(red_depgraph, "red_depgraph"; root=1, label_len=label_len)
