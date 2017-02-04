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

file_to_deps = Dict{File, Set{SymName}}()
syms_to_files = Dict{SymName, Files}()

info("collecting symbols...")

for file in parsed_args["OBJFILE"]
  file_syms = Set{Sym}()
  file_deps = Set{SymName}()
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

    ismatch(r"^[0-9a-f]{16}| {16}", line) || continue

    #add = line[1:16]
    symtype = line[18]
    symname = line[20:end]

    contains(symname, "virtual thunk to ") && continue
    contains(symname, "typeinfo for ") && continue

    if symtype=='T' || symtype=='W' || symtype=='B'
      # this file provides this symbol
      push!(file_syms, Sym(symname, symtype))
    elseif symtype=='U'
      # undefined symbol: it represents a dependency
      push!(file_deps, symname)
    end
  end

  # populate the symbol-to-file dictionary
  for sym in file_syms
    name = sym.symname
    if haskey(syms_to_files, name)
      if is_strong(sym) && !isempty(syms_to_files[name].strong)
        other = join(',', syms_to_files[name].strong)
        warn("strong sym $sym found in $key but already present in $other")
      end
    else
      syms_to_files[name] = Files()
    end
    if is_strong(sym)
      push!(syms_to_files[name].strong, key)
    else
      push!(syms_to_files[name].weak, key)
    end
  end

  # fill the file-to-dependencies dictionary
  file_to_deps[key] = file_deps

end

info("constructing depgraph...")
depgraph = GraphDict()

for (file::File, deps::Set{SymName}) in file_to_deps
  for dep::SymName in deps
    # if we don't know about this symbol, do not include it in the graph
    haskey(syms_to_files, dep) || continue
    if !haskey(depgraph, file)
      dependencies = DependenciesWithFile()
      depgraph[file] = dependencies
    else
      dependencies = depgraph[file]
    end

    dependees_ws = syms_to_files[dep]
    dependees = isempty(dependees_ws.strong) ? dependees_ws.weak : dependees_ws.strong
    for dependee in dependees
      if haskey(dependencies, dependee)
        syms = dependencies[dependee]
      else
        syms = SymNames()
        dependencies[dependee] = syms
      end
      push!(syms, dep)
    end
  end
end

info("saving to $output_filename...")
@save(output_filename, depgraph)
