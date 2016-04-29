#!/usr/bin/env julia

using ArgParse
using JLD       # for persistency

arg_settings = ArgParseSettings()

@add_arg_table arg_settings begin
  "-o", "--output"
    help = "name of the output file"
    arg_type = AbstractString
  "-s", "--suppress"
    help = "suppress a string from the object file names"
    arg_type = AbstractString
    default = ""
  "OBJFILE"
    help = "object file to analyse"
    arg_type = AbstractString
    nargs = '+'
    required = true
end

parsed_args = parse_args(arg_settings)

if parsed_args["output"] == nothing
  output_filename = "depgraph.jld"
else
  output_filename = parsed_args["output"]
end
suppress = parsed_args["suppress"]

include("types.jl")

file_to_deps = Dict{File, Set{Sym}}()
syms_to_files = Dict{Sym, File}()

info("collecting symbols...")

for file in parsed_args["OBJFILE"]
  file_syms = Set{Sym}()
  file_deps = Set{Sym}()
  bfile = last(rsplit(file, '/', limit=2))
  bfile_arr = rsplit(bfile, '.')
  key = bfile_arr[1]
  if !isempty(suppress)
    key = replace(key, suppress, "")
  end

  command = `nm -g -C $file`
  deps = readall(command)

  # collect all the symbols provided by this file and all the symbol it
  # references (dependencies)
  for line in split(deps, '\n')
    isempty(line) && continue

    add = line[1:16]
    typ = line[18]
    sym = line[20:end]

    contains("sym", "virtual thunk") && continue

    if typ=='T'
      # this file provides this symbol
      push!(file_syms, sym)
    elseif typ=='U'
      # undefined symbol: it represents a dependency
      push!(file_deps, sym)
    end
  end

  # populate the symbol-to-file dictionary
  for sym in file_syms
    if haskey(syms_to_files, sym)
      error("sym $sym found in $key but already present in $(syms_to_files[sym])")
    else
      syms_to_files[sym] = key
    end
  end

  # fill the file-to-dependencies dictionary
  file_to_deps[key] = file_deps

end

info("constructing depgraph...")
depgraph = GraphDict()

for (file::File, deps::Set{Sym}) in file_to_deps
  for dep::Sym in deps
    # if we don't know about this symbol, do not include it in the graph
    haskey(syms_to_files, dep) || continue
    if !haskey(depgraph, file)
      dependencies = DependenciesWithFile()
      depgraph[file] = dependencies
    else
      dependencies = depgraph[file]
    end

    dependee = syms_to_files[dep]
    if in(dependencies, dependee)
      syms = dependencies[dependee]
    else
      syms = Vector{Sym}()
      dependencies[dependee] = syms
    end
    push!(syms, dep)
  end
end

info("saving to $output_filename...")
@save(output_filename, depgraph)
