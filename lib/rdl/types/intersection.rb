require_relative 'type'

module RDL::Type
  class IntersectionType < Type
    attr_reader :types

    @@cache = {}

    class << self
      alias :__new__ :new
    end

    def self.new(*types)
      ts = []
      types.each { |t|
        if t.instance_of? NilType
          next
        elsif t.instance_of? IntersectionType
          ts.concat t.types
        else
          ts << t
        end
      }
      ts.sort! { |a,b| a.object_id <=> b.object_id }
      ts.uniq!

      return NilType.new if ts.size == 0
      return ts[0] if ts.size == 1

      t = @@cache[ts]
      return t if t
      t = IntersectionType.__new__(ts)
      return (@@cache[ts] = t) # assignment evaluates to t
    end

    def initialize(types)
      @types = types
      super()
    end

    def to_s  # :nodoc:
      "(#{@types.map { |t| t.to_s }.join(' and ')})"
    end
    
    def eql?(other)
      self == other
    end

    def ==(other)  # :nodoc:
      return (other.instance_of? IntersectionType) && (other.types == @types)
    end

    def member?(obj, *args)
      @types.all? { |t| t.member?(obj, *args) }
    end
    
    def instantiate(inst)
      return IntersectionType.new(*(@types.map { |t| t.instantiate(inst) }))
    end
    
    def hash  # :nodoc:
      47 + @types.hash
    end
  end
end
