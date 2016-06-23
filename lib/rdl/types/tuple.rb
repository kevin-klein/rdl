module RDL::Type
  # A specialized GenericType for tuples, i.e., fixed-sized arrays
  class TupleType < Type
    attr_reader :params
    attr_reader :array   # either nil or array type if self has been promoted to array
    attr_reader :ubounds # upper bounds this tuple has been compared with using <=
    attr_reader :lbounds # lower bounds...

    # no caching because array might be mutated
    def initialize(*params)
      raise RuntimeError, "Attempt to create tuple type with non-type param" unless params.all? { |p| p.is_a? Type }
      @params = params
      @array = nil # emphasize initially this is a tuple, not an array
      @ubounds = []
      @lbounds = []
      super()
    end

    def canonical
      return @array if @array
      return self
    end

    def to_s
      return @array.to_s if @array
      return "[#{@params.map { |t| t.to_s }.join(', ')}]"
    end

    def ==(other) # :nodoc:
      return false if other.nil?
      return (@array == other) if @array
      other = other.canonical
      return (other.instance_of? TupleType) && (other.params == @params)
    end

    alias eql? ==

    def match(other)
      return @array.match(other) if @array
      other = other.canonical
      other = other.type if other.instance_of? AnnotatedArgType
      return true if other.instance_of? WildQuery
      return @params.length == other.params.length && @params.zip(other.params).all? { |t,o| t.match(o) }
    end

    def promote!
      @array = GenericType.new($__rdl_array_type, UnionType.new(*@params))
      # note since we promoted this, lbounds and ubounds will be ignored in future constraints, which
      # is good because otherwise we'd get infinite loops
      return (@lbounds.all? { |lbound| lbound <= self }) && (@ubounds.all? { |ubound| self <= ubound })
    end

    def <=(other)
      return @array <= other if @array
      other = other.canonical
      return true if other.instance_of? TopType
      other = other.array if other.instance_of?(TupleType) && other.array
      if other.instance_of? TupleType
        # Tuples are immutable, so covariant subtyping allowed
        return false unless @params.length == other.params.length
        return false unless @params.zip(other.params).all? { |left, right| left <= right }
        # subyping check passed
        ubounds << other
        other.lbounds << self
        return true
      elsif (other.instance_of? GenericType) && (other.base == $__rdl_array_type)
        r = promote!
        return (self <= other) && r
      end
      return false
    end

    def member?(obj, *args)
      return @array.member?(obj, *args) if @array
      t = RDL::Util.rdl_type obj
      return t <= self if t
      return false unless obj.instance_of?(Array) && obj.size == @params.size
      return @params.zip(obj).all? { |formal, actual| formal.member?(actual, *args) }
    end

    def instantiate(inst)
      return @array.instantiate(inst) if @array
      return TupleType.new(*@params.map { |t| t.instantiate(inst) })
    end

    def hash
      # note don't change hash value if @array becomes non-nil
      73 * @params.hash
    end

  end
end
