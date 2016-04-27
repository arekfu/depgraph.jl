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

typealias GraphDict Dict{ASCIIString, Set{ASCIIString}}

file_to_deps = Dict{ASCIIString, Set{ASCIIString}}()
syms_to_files = Dict{ASCIIString, ASCIIString}()

info("collecting symbols...")

for file in parsed_args["OBJFILE"]
  file_syms = Set{ASCIIString}()
  file_deps = Set{ASCIIString}()
  bfile = last(rsplit(file, '/', limit=2))
  bfile_arr = rsplit(bfile, '.')
  key = bfile_arr[1]
  if !isempty(suppress)
    key = replace(key, suppress, "")
  end

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

info("constructing depgraph...")
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

info("saving to $output_filename...")
@save(output_filename, depgraph)
