#!/usr/bin/env julia

typealias DotGraph AbstractString
typealias Graph Dict{AbstractString, Set{AbstractString}}

function convert(DotGraph, graph::Graph)
  lines = ["digraph depgraph {"]
  for (from, tos) in graph
    for to in tos
      push!(lines, "$from -> $to")
    end
  end
  push!(lines, "}\n")
  join(lines, '\n')
end

function to_dotfile(graph::Graph, filename)
  outfile = open(filename, "w")
  write(outfile, convert(DotGraph, graph))
  close(outfile)
end

function remove_redundant_edges(graph::Graph)
  local new_graph = Graph()
  local stack = Vector{AbstractString}(collect(keys(graph)))
  while !isempty(stack)
    from = pop!(stack)
    if !haskey(new_graph, from)
      new_graph[from] = Set{AbstractString}()
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

file_to_deps = Dict{AbstractString, Set{AbstractString}}()
syms_to_files = Dict{AbstractString, AbstractString}()

print("collecting symbols...\n")

for file in ARGS
  file_syms = Set{AbstractString}()
  file_deps = Set{AbstractString}()
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

print("constructing depgraph...\n")
depgraph = Dict{AbstractString, Set{AbstractString}}()

for (file::AbstractString, deps) in file_to_deps
  for dep::AbstractString in deps
    if haskey(syms_to_files, dep)
      if !haskey(depgraph, file)
        depgraph[file] = Set{AbstractString}()
      end
      push!(depgraph[file], syms_to_files[dep])
    end
  end
end

to_dotfile(depgraph, "depgraph.dot")

print("removing redundant edges...\n")
new_depgraph = remove_redundant_edges(depgraph)
to_dotfile(new_depgraph, "new_depgraph.dot")

