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
  "-t", "--transitive-reduction"
    help = "apply transitive reduction"
    action = :store_true
  "-c", "--condensation"
    help = "apply condensation"
    action = :store_true
  "-f", "--focus"
    help = "focus on the given nodes"
    arg_type = AbstractString
    action = :append_arg
  "-n", "--neighborhood-size"
    help = "size of the neighborhood to plot"
    arg_type = Int
    default = nothing
  "--hide-ellipsis-edges"
    help = "hide ellipsis edges (they indicate where the graph was cut by the -n option)"
    action = :store_false
    dest_name = "ellipsis-edges"
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

do_transitive_reduction = parsed_args["transitive-reduction"]
do_condensation = parsed_args["condensation"]
do_ellipsis_edges = parsed_args["ellipsis-edges"]

focus_nodes = parsed_args["focus"]

neigh_size = parsed_args["neighborhood-size"]
if neigh_size==nothing
  neigh_size = typemax(Int)
elseif isempty(focus_nodes)
  error("the -n option does not make sense without -f")
end

# script starts here

using JLD       # for persistency
using LightGraphs

include("labelledgraph.jl")


info("loading dictionary...")
@load(dict_filename, depgraph)

info("converting to LightGraphs.DiGraph...")
graph = convert(LabelledDiGraph, depgraph)

info("generating subgraph...")
if !isempty(focus_nodes)
  focus_regex = Regex(join(focus_nodes, '|'))
  generator_indices = find(l -> ismatch(focus_regex, l), graph.labels)
else
  focus_regex = nothing
  generator_indices = collect(1:nv(graph))
end
new_vertices, graph′ = egonet(graph, generator_indices, neigh_size)
info("subgraph has $(nv(graph′)) vertices")

if do_ellipsis_edges
  info("adding ellipsis edges...")
  graph′ = add_ellipsis_edges(graph, graph′, new_vertices)
end
graph = graph′

info("computing strongly connected components...")
scc, cond_labels = strongly_connected_components(graph)
nontrivial_scc = length(find(s -> length(s)>1, scc))
largest_scc = maximum(map(length, scc))
info("subgraph has $(length(scc)) scc ($nontrivial_scc non-trivial, ",
     "largest=$largest_scc)")

if do_condensation
  info("condensing...")
  graph = condensation(graph)
end

if do_transitive_reduction
  info("reducing...")
  graph = transitive_reduce(graph)
  info("reduced subgraph has $(nv(graph)) vertices")
end

info("saving...")
to_dotfile(graph, output_filename; highlight=focus_regex, label_len=label_len)
