import Base: convert

# some useful type aliases
typealias File AbstractString
type Files
  weak   :: Vector{File}
  strong :: Vector{File}
  Files() = new(Vector{File}(), Vector{File}())
end
type SymType
  symtype :: Char
  function SymType(t::Char)
    if t!='W' && t!='T'
      throw("Symbol type must be one of 'W', 'T'")
    end
    new(t)
  end
end
convert(::Type{SymType}, c::Char) = SymType(c)
typealias SymName AbstractString
type Sym
  symname :: SymName
  symtype :: SymType
end
typealias SymNames Vector{SymName}
# the following represents a dependendency on a file due to the given list of
# symbols
typealias DependenciesWithFile Dict{File, SymNames}

# the full dependency graph
typealias GraphDict Dict{File, DependenciesWithFile}
