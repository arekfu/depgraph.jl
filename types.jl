# some useful type aliases
typealias File AbstractString
typealias Sym AbstractString
typealias Syms Vector{Sym}
# the following represents a dependendency on a file due to the given list of
# symbols
typealias DependenciesWithFile Dict{File, Vector{Sym}}

# the full dependency graph
typealias GraphDict Dict{File, DependenciesWithFile}
