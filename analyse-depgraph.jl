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
  "-d", "--neighborhood-direction"
    help = "direction in which neighborhoods are explored (\"in\", \"out\", \"both\")"
    arg_type = AbstractString
    default = "out"
    range_tester = x -> x=="in" || x=="out" || x=="both"
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

neigh_dir = Symbol(parsed_args["neighborhood-direction"])

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
new_vertices, graph′ = egonet(graph, generator_indices, neigh_size, dir=neigh_dir)
info("subgraph has $(nv(graph′)) vertices")

# print some useful stats about the resulting subgraph
cyclic = is_cyclic(graph′)
verb = cyclic ? "is" : "is not"
info("subgraph $verb cyclic")
info("subgraph indegree:  min=$(δin(graph′)), max=$(Δin(graph′))")
info("subgraph outdegree: min=$(δout(graph′)), max=$(Δout(graph′))")
info("subgraph density: $(density(graph′))")
if !cyclic
  # the LightGraphs implementations of these functions only work for acyclic
  # graphs
  info("subgraph radius: $(radius(graph′))")
  info("subgraph diameter: $(diameter(graph′))")
  info("subgraph eccentricity: $(eccentricity(graph′))")
end

if do_ellipsis_edges
  info("adding ellipsis edges...")
  graph′ = add_ellipsis_edges(graph, graph′, new_vertices)
end
graph = graph′

info("computing strongly connected components...")
scc, cond_labels = strongly_connected_components(graph)
nontrivial_scc = count(s -> length(s)>1, scc)
len_largest_scc, index_largest_scc = findmax(map(length, scc))
#largest_scc = sort(scc[index_largest_scc])
#largest_scc_subgraph = induced_subgraph(graph, largest_scc)
#period_largest_scc = period(largest_scc_subgraph)
#info("subgraph has $(length(scc)) scc ($nontrivial_scc non-trivial, ",
#     "largest=$len_largest_scc with period $period_largest_scc)")
info("subgraph has $(length(scc)) scc ($nontrivial_scc non-trivial, ",
     "largest=$len_largest_scc)")

if do_condensation
  info("condensing...")
  graph = condensation(graph)
end

if do_transitive_reduction
  info("reducing...")
  graph = transitive_reduce(graph)
  info("reduced subgraph has $(nv(graph)) vertices")
end

info("saving to $output_filename...")
to_dotfile(graph, output_filename; highlight=focus_regex, label_len=label_len)
