#!/usr/bin/env julia

using LightGraphs
#using TikzGraphs
#import TikzPictures
using GraphPlot
using Compose

typealias GraphDict Dict{ASCIIString, Set{ASCIIString}}

#function convert(DotGraph, graph::GraphDict)
#  lines = ["digraph depgraph {"]
#  for (from, tos) in graph
#    for to in tos
#      push!(lines, "$from -> $to")
#    end
#  end
#  push!(lines, "}\n")
#  join(lines, '\n')
#end

function truncate_string(s, len)
  n = count(c->c==':', s) + 1
  if len>length(s)
    tr = s[1:end]
  else
    tr = string(s[1:len], "...")
  end
  return string(tr, "($n)")
end

function to_dot_as_string(g::DiGraph, labels; name="depgraph", root=nothing)
  tr_labels = [truncate_string(replace(l, "t4", ""), 16) for l in labels]
  lines = ["digraph $name {"]
  if root==nothing
    from = find_root(g)
  else
    from = root
  end
  from_label = tr_labels[from]
  push!(lines, "root=\"$from_label\";")
  push!(lines, "rankdir=LR;")
  push!(lines, "node [shape=box, style=filled];")

  for from = g.vertices
    full_label = labels[from]
    n = count(c->c==':', full_label) + 1
    if n>1
      from_label = tr_labels[from]
      push!(lines, "\"$from_label\" [fillcolor=red]")
    end
  end

  for from = g.vertices
    from_label = tr_labels[from]
    tos = in_neighbors(g, from)
    for to = tos
      to_label = tr_labels[to]
      push!(lines, "\"$to_label\" -> \"$from_label\"")
    end
  end
  push!(lines, "}\n")
  join(lines, '\n')
end

#function convert{V,E,VList,EList}(DotGraph, g::Graphs.GenericEdgeList{V,E,VList,EList})
#  lines = ["digraph depgraph {"]
#  from = find_root(g)
#  push!(lines, "root=$from;")
#  nodelist = [ from ]
#  el = g.edges
#
#  while !isempty(nodelist)
#    from = shift!(nodelist)
#    iedges = find(e -> Graphs.source(e)==from, el)
#    edges  = el[iedges]
#    tos = map(Graphs.target, edges)
#    for to = tos
#      push!(lines, "$from -> $to")
#      push!(nodelist, to)
#    end
#  end
#  push!(lines, "}\n")
#  join(lines, '\n')
#end

function to_lightdigraph(graph::GraphDict)
  kset = Set{ASCIIString}()
  for (k, vs) = graph
    push!(kset, k)
    union!(kset, vs)
  end
  ks = collect(kset)
  sort!(ks)

  nv = length(ks)

  key_to_index = Dict{ASCIIString, Int}()
  for ifrom = 1:nv
    key_to_index[ks[ifrom]] = ifrom
  end

  dg = LightGraphs.DiGraph(nv)
  for ifrom = 1:nv
    from = ks[ifrom]
    tos = get(graph, from, [])
    itos = map(k -> key_to_index[k], tos)
    for ito = itos
      add_edge!(dg, ifrom, ito)
    end
  end
  dg, ks
end

#function to_incidencelist(graph::GraphDict; vfilter=(x->true))
#  kset = Set{ASCIIString}()
#  for (k, vs) = graph
#    push!(kset, k)
#    union!(kset, vs)
#  end
#
#  inc_list = Graphs.inclist(ASCIIString)
#
#  for k = kset
#    vfilter(k) || continue
#    Graphs.add_vertex!(inc_list, k)
#  end
#
#  for (from, tos) = graph
#    vfilter(from) || continue
#    for to = tos
#      vfilter(to) || continue
#      Graphs.add_edge!(inc_list, from, to)
#    end
#  end
#  inc_list
#end

function to_dotfile(graph, labels, name; root=nothing)
  outfile = open("$name.dot", "w")
  write(outfile, to_dot_as_string(graph, labels, name=name, root=root))
  close(outfile)
end

#function lightdigraph_to_dotfile(graph, filename)
#  outfile = open(filename, "w")
#  save(outfile, graph, :dot)
#  close(outfile)
#end

function remove_redundant_edges(graph::GraphDict)
  local new_graph = GraphDict()
  local stack = Vector{ASCIIString}(collect(keys(graph)))
  while !isempty(stack)
    from = pop!(stack)
    if !haskey(new_graph, from)
      new_graph[from] = Set{ASCIIString}()
      for to = get(graph, from, [])
        if !haskey(new_graph, to)
          push!(new_graph[from], to)
          push!(stack, to)
        end
      end
    end
  end
  new_graph
end

function find_root(graph)
  node = first(graph.vertices)
  el = out_neighbors(graph, node)
  while !isempty(el)
    node = first(el)
    el = out_neighbors(graph, node)
  end
  node
end

file_to_deps = Dict{ASCIIString, Set{ASCIIString}}()
syms_to_files = Dict{ASCIIString, ASCIIString}()

println("collecting symbols...")

#if !isempty(ARGS)
#  args = ARGS
#else
  path = "/home/dm232107/src/t4/Debug/Tripoli4/OBJ/linux-intel-64"
  args = split(chomp(readall(`ls $path`)), '\n')
  args = collect(["$path/$arg" for arg in args])
#end

for file in args
  file_syms = Set{ASCIIString}()
  file_deps = Set{ASCIIString}()
  bfile = last(rsplit(file, '/', limit=2))
  bfile_arr = rsplit(bfile, '.')
  key = bfile_arr[1]

  command = `nm -g -C $file`
  deps = readall(command)

  for line in split(deps, '\n')
    isempty(line) && continue

    add = line[1:16]
    typ = line[18]
    sym = line[20:end]

    contains("sym", "virtual thunk") && continue

    if typ=='T'
      push!(file_syms, sym)
    elseif typ=='U'
      push!(file_deps, sym)
    end
  end

  for sym in file_syms
    if haskey(syms_to_files, sym)
      print("sym $sym found in $key but already present in $(syms_to_files[sym])")
      exit(1)
    else
      syms_to_files[sym] = key
    end
  end

  file_to_deps[key] = file_deps

end

println("constructing depgraph...")
depgraph = Dict{ASCIIString, Set{ASCIIString}}()

for (file::ASCIIString, deps) in file_to_deps
  for dep::ASCIIString in deps
    if haskey(syms_to_files, dep)
      if !haskey(depgraph, file)
        depgraph[file] = Set{ASCIIString}()
      end
      push!(depgraph[file], syms_to_files[dep])
    end
  end
end

#println("removing redundant edges...")
#new_depgraph = remove_redundant_edges(depgraph)
#to_dotfile(new_depgraph, "new_depgraph.dot")

function transitive_reduce(g)
  g′ = copy(g)
  remove = Set{Edge}()
  for i = g.vertices
    i_neighs = out_neighbors(g, i)
    for j = i_neighs
      i==j && continue
      for k = out_neighbors(g, j)
        j==k && continue
        if in(k, i_neighs)
          push!(remove, Edge(i, k))
        end
      end
    end
  end

  for edge in remove
    rem_edge!(g′, edge)
  end
  g′
end

function extract_subgraph(graph, vertices)
  neighs = [ neighborhood(graph, v, typemax(v)) for v in vertices ]
  keep = []
  for v = graph.vertices
    if any(n -> in(v, n), neighs)
      push!(keep, v)
    end
  end

  keep, induced_subgraph(graph, keep)
end


println("converting to LightGraphs...")
ldepgraph, nodelabels = to_lightdigraph(depgraph)

println("generating subgraph...")
#generator_indices = 1:nv(ldepgraph)
generator_indices = find(l -> contains(l, "geomROOT"), nodelabels)
subgraph_indices, subgraph = extract_subgraph(ldepgraph, generator_indices)
subgraph_labels = nodelabels[subgraph_indices]
println("subgraph: $subgraph")

println("computing strongly connected components...")
ssc = strongly_connected_components(subgraph)
nontrivial_ssc = length(find(s -> length(s)>1, ssc))
largest_ssc = maximum(map(length, ssc))
println("subgraph has $(length(ssc)) ssc ($nontrivial_ssc non-trivial, largest=$largest_ssc)")

println("condensing...")
#cond_labels = [join(subgraph_labels[s], ':') for s = ssc]
#nodesizes = Float64[ log(length(s)+1) for s = ssc ]
#cond_depgraph = condensation(subgraph)

cond_labels = subgraph_labels
nodesizes = ones(nv(subgraph))
cond_depgraph = subgraph

println("reducing...")
red_depgraph = transitive_reduce(cond_depgraph)
#red_depgraph = cond_depgraph
println("reduced subgraph: $red_depgraph")

println("saving...")
#pdepgraph = plot(ldepgraph)
#TikzPictures.save(TikzPictures.SVG("depgraph.svg"), pdepgraph)
#draw(PDF("depgraph.pdf", 45cm, 45cm),
#     gplot(red_depgraph, nodelabel=cond_labels, nodesize=nodesizes)
#     )
to_dotfile(red_depgraph, cond_labels, "red_depgraph"; root=1)
