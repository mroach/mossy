module Mossy
  class Column

    attr_accessor :name, :type, :column_id, :is_computed, :is_identity, :is_nullable
    attr_accessor :default_definition, :computed_definition
    attr_accessor :seed_value, :increment_value, :precision, :scale

    def initialize(spec = {})
      spec.each do |k,v|
        instance_variable_set("@#{k}", v)
      end
    end

    # generate the column definition that would be used in a create table statement
    # col_indent pads column names so the specs line up
    def definition(col_indent = 1)
      parts = []
      # add two to col_indent to compensate for []
      parts << sprintf("%-#{col_indent + 2}s", @name.quotename)

      if @is_computed
        parts.push("AS #{@computed_definition}")
      else
        parts.push(type_spec)
        if @is_identity
          parts.push("IDENTITY(#{@seed_value},#{@increment_value})")
        end
        parts.push(@is_nullable ? "NULL" : "NOT NULL")
        if !@default_definition.nil?
          parts.push("DEFAULT #{@default_definition}")
        end
      end

      parts.join(" ")
    end

    # generate the type spec. for character types this will include a length
    # decimal and numeric types include the precision and scale
    def type_spec
      if %w(varchar nvarchar char nchar).include?(@type)
        if @max_length == -1
          len = "max"
        elsif @type[0] == "n"
          len = (@max_length / 2).to_s
        else
          len = @max_length.to_s
        end
        return "#{@type}(#{len})"
      end

      if %w(decimal numeric).include?(@type)
        return "#{@type}(#{@precision},#{@scale})"
      end

      @type
    end
  end
end
