import LightGraphs: DiGraph, induced_subgraph, neighborhood, egonet,
                    strongly_connected_components, condensation, nv, ne,
                    is_cyclic, δin, δout, Δin, Δout, density, radius, diameter,
                    eccentricity, period, is_strongly_connected,
                    examine_neighbor!
import Base: convert, copy

include("types.jl")

type LabelledDiGraph
  graph :: DiGraph
  labels :: Vector{AbstractString}
end

convert(::Type{DiGraph}, g::LabelledDiGraph) = g.graph

function convert(::Type{LabelledDiGraph}, gd :: GraphDict)
  kset = Set{File}()
  for (k, vs) = gd
    push!(kset, k)
    union!(kset, keys(vs))
  end
  labels = collect(kset)
  sort!(labels)

  nv = length(labels)

  label_to_index = Dict{File, Int}()
  for ifrom = 1:nv
    label_to_index[labels[ifrom]] = ifrom
  end

  g = DiGraph(nv)
  for ifrom = 1:nv
    from = labels[ifrom]
    tos = haskey(gd, from) ? keys(gd[from]) : []
    itos = map(k -> label_to_index[k], tos)
    for ito = itos
      add_edge!(g, ifrom, ito)
    end
  end
  LabelledDiGraph(g, labels) 
end

copy(graph::LabelledDiGraph) = LabelledDiGraph(copy(graph.graph), copy(graph.labels))

nv(g :: LabelledDiGraph) = nv(g.graph)

ne(g :: LabelledDiGraph) = ne(g.graph)

function induced_subgraph(g :: LabelledDiGraph, iter)
  graph′ = induced_subgraph(g.graph, iter)
  g′ = LabelledDiGraph(graph′, g.labels[iter])
end

function to_dot_as_string(graph::LabelledDiGraph, name::AbstractString;
                          root=nothing, label_len=nothing, highlight=nothing,
                          libraries=nothing, cli="")
  g = graph.graph
  labels = graph.labels

  # determine label length
  if label_len==nothing
    label_len = typemax(Int)
  end

  # determine root
  if root==nothing
    from = find_root(g)
  else
    from = root
  end

  tr_labels = [truncate_string(l, label_len) for l in labels]
  lines = ["// command line used to produce this graph:"]
  push!(lines, "// $cli")
  push!(lines, "digraph \"$name\" {")
  from_label = tr_labels[from]
  push!(lines, "root=\"$from_label\";")
  push!(lines, "rankdir=LR;")
  push!(lines, "node [shape=box, style=filled];")
  push!(lines, "edge [arrowhead=onormal];")

  for from in g.vertices
    full_label = labels[from]
    from_label = tr_labels[from]
    if startswith(from_label, "...")
      push!(lines, "\"$from_label\" [style=invis]")
    elseif highlight!=nothing && ismatch(highlight, full_label)
      push!(lines, "\"$from_label\" [fillcolor=firebrick]")
    else
      n = count(c->c==':', full_label) + 1
      if n>1
        from_label = tr_labels[from]
        push!(lines, "\"$from_label\" [fillcolor=dodgerblue]")
      end
    end
  end

  for from = g.vertices
    from_label = tr_labels[from]
    tos = in_neighbors(g, from)
    for to = tos
      to_label = tr_labels[to]
      if startswith(from_label, "...")
        push!(lines, "\"$to_label\" -> \"$from_label\" [style=dotted]")
      else
        push!(lines, "\"$to_label\" -> \"$from_label\"")
      end
    end
  end

  # add library clusters
  if libraries!=nothing
    for (lib, objs) in libraries
      push!(lines, "subgraph \"cluster-$lib\" {")
      push!(lines, "label=\"$lib\";")
      for obj in objs
        if startswith(from_label, "...")
          push!(lines, "\"$obj\" [style=invis]")
        elseif highlight!=nothing && ismatch(highlight, obj)
          push!(lines, "\"$obj\" [fillcolor=firebrick]")
        else
          push!(lines, "\"$obj\"")
        end
      end
      push!(lines, "}")
    end
  end

  push!(lines, "}\n")
  join(lines, '\n')
end

function to_dotfile(graph::LabelledDiGraph, name::AbstractString; kwargs...)
  open("$name", "w") do outfile
    graphname = first(split(name, '.', limit=2))
    write(outfile, to_dot_as_string(graph, graphname; kwargs...))
  end
end

function find_root(graph::DiGraph)
  node = first(graph.vertices)
  el = out_neighbors(graph, node)
  visited = Set{typeof(node)}()
  while !isempty(el)
    push!(visited, node)
    node = first(el)
    el = setdiff(out_neighbors(graph, node), visited)
  end
  node
end

function neighborhood(graph::DiGraph, vertices::Vector{Int}, dist::Int; kwargs...)
  neighs = [ neighborhood(graph, v, dist; kwargs...) for v in vertices ]
  keep = []
  for v = graph.vertices
    if any(n -> in(v, n), neighs)
      push!(keep, v)
    end
  end
  keep
end

function egonet(graph::LabelledDiGraph, vertices::Vector{Int}, dist::Int; kwargs...)
  local new_vertices::Vector{Int}
  new_kwargs = Dict(kwargs)
  if haskey(new_kwargs, :dir) && new_kwargs[:dir]==:both
    new_kwargs[:dir] = :in
    new_vertices_in::Vector{Int} = neighborhood(graph.graph, vertices, dist; new_kwargs...)
    new_kwargs[:dir] = :out
    new_vertices_out::Vector{Int} = neighborhood(graph.graph, vertices, dist; new_kwargs...)
    new_vertices_set = IntSet([new_vertices_in; new_vertices_out])
    new_vertices = collect(new_vertices_set)
  else
    new_vertices = neighborhood(graph.graph, vertices, dist; kwargs...)
  end
  graph′ = induced_subgraph(graph.graph, new_vertices)
  new_vertices, LabelledDiGraph(graph′, graph.labels[new_vertices])
end

function truncate_string(s::AbstractString, len::Int)
  startswith(s, "...") && return s

  n = count(c->c==':', s)
  if len>length(s)
    tr = s[1:end]
  else
    tr = string(s[1:len], "...")
  end

  if n>0
    tr = string(tr, "($(n+1))")
  end
  tr
end

condense_labels(graph::LabelledDiGraph, vertices::Vector{Int}) =
        join(graph.labels[vertices], ':')

condense_labels(graph::LabelledDiGraph, vec_vertices::Vector{Vector{Int}}) =
        map(vs -> condense_labels(graph, vs), vec_vertices)

function strongly_connected_components(graph::LabelledDiGraph)
  scc = strongly_connected_components(graph.graph)
  scc_labels = condense_labels(graph, scc)
  scc, scc_labels
end

function condensation(graph::LabelledDiGraph)
  cond_graph = condensation(graph.graph)
  scc, scc_labels = strongly_connected_components(graph)
  LabelledDiGraph(cond_graph, scc_labels)
end

# machinery for transitive reduction

type TransitiveReductionVisitor <: SimpleGraphVisitor
  graph :: DiGraph
  root :: Int
  remove :: Set{Edge}

  TransitiveReductionVisitor(g::DiGraph, v::Int) = new(g, v, Set{Edge}())
end

function examine_neighbor!(visitor::TransitiveReductionVisitor, u::Int, v::Int, ucolor::Int, vcolor::Int, ecolor::Int)
  if has_edge(visitor.graph, visitor.root, v)
    push!(visitor.remove, Edge(visitor.root, v))
  end
  true
end

function transitive_reduction(graph::DiGraph)
  graph′ = copy(graph)
  for i = graph.vertices
    visitor = TransitiveReductionVisitor(graph′, i)
    i_neighs = out_neighbors(graph′, i)
    for j in i_neighs
      traverse_graph!(graph′, DepthFirst(), j, visitor)
    end
    for edge in visitor.remove
      rem_edge!(graph′, edge)
    end
  end
  graph′
end

function transitive_reduction(graph::LabelledDiGraph)
  g = transitive_reduction(graph.graph)
  LabelledDiGraph(g, graph.labels)
end



function add_ellipsis_edges(complete::LabelledDiGraph,
                            truncated::LabelledDiGraph,
                            vertices::Vector{Int})
  vset = Set{Int}(vertices)
  needs_ellipsis_edge = []
  for (i, v) in enumerate(vertices)
    neighbors = neighborhood(complete.graph, v, 1)
    if any(v′ -> v′ ∉ vset, neighbors)
      push!(needs_ellipsis_edge, i)
    end
  end

  n_ell = length(needs_ellipsis_edge)
  decorated = copy(truncated.graph)
  n_orig = nv(decorated)
  add_vertices!(decorated, n_ell)
  labels = copy(truncated.labels)
  append!(labels, map(i -> string("...", i), 1:n_ell))
  for (i, iv) in enumerate(needs_ellipsis_edge)
    add_edge!(decorated, iv, n_orig + i)
  end
  LabelledDiGraph(decorated, labels)
end

is_cyclic(graph::LabelledDiGraph) = is_cyclic(graph.graph)
δin(graph::LabelledDiGraph) = δin(graph.graph)
δout(graph::LabelledDiGraph) = δout(graph.graph)
Δin(graph::LabelledDiGraph) = Δin(graph.graph)
Δout(graph::LabelledDiGraph) = Δout(graph.graph)
density(graph::LabelledDiGraph) = density(graph.graph)
radius(graph::LabelledDiGraph) = radius(graph.graph)
diameter(graph::LabelledDiGraph) = diameter(graph.graph)
eccentricity(graph::LabelledDiGraph) = eccentricity(graph.graph)
period(graph::LabelledDiGraph) = period(graph.graph)
is_strongly_connected(graph::LabelledDiGraph) = is_strongly_connected(graph.graph)
