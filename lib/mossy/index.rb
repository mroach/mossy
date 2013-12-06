module Mossy
  class Index

    attr_accessor :name, :type, :table
    attr_accessor :is_primary_key, :is_unique, :is_unique_constraint
    attr_accessor :ignore_dup_key, :fill_factor, :is_padded
    attr_accessor :has_filter, :filter_definition
    attr_accessor :data_space
    attr_accessor :columns

    def initialize(spec = {})
      spec.each do |k,v|
        instance_variable_set("@#{k}", v)
      end
    end

    def script
      if @is_primary_key
        parts = ["ALTER TABLE"]
        parts << "#{@table.quotename} ADD CONSTRAINT #{@name.quotename}"
        parts << "PRIMARY KEY #{@type}"
        parts << "(#{script_column_list(index_columns)})"
        return "#{parts.join(' ')};"
      end

      opts = {}
      opts["PAD_INDEX"] = 'ON' if @is_padded
      opts["IGNORE_DUP_KEY"] = 'ON' if @ignore_dup_key
      opts["FILLFACTOR"] = @fill_factor if @fill_factor > 0

      parts = ["CREATE"]
      if @is_unique_constraint || @is_unique
        parts << "UNIQUE"
      end
      if @type != "NONCLUSTERED"
        parts << @type
      end
      parts << "INDEX #{@name.quotename}"
      parts << "ON #{@table.quotename}"
      parts << "(#{script_column_list(index_columns)})"
      if !included_columns.empty?
        parts << "INCLUDE (#{script_column_list(included_columns)})"
      end
      if opts.any?
        parts << "WITH (#{option_list(opts)})"
      end
      parts << "ON #{@data_space.quotename}"
      "#{parts.join(' ')};"
    end

    def option_list(opts)
      opts.map { |k,v| "#{k} = #{v}" }.join(', ')
    end

    def script_column_list(cols)
      cols.map { |c| "#{c[:column_name]}#{c[:is_descending_key] ? ' DESC' : ''}" }.join(', ')
    end

    def index_columns
      @columns.reject { |c| c[:is_included_column] }
    end

    def included_columns
      @columns.select { |c| c[:is_included_column] }
    end

  end
end
