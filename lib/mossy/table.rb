module Mossy
  class Table < SqlObject

    attr_accessor :columns, :data_space, :lob_space
    attr_accessor :indexes, :permissions, :foreign_keys, :constraints

    def initialize(spec = {})
      spec.each do |k,v|
        instance_variable_set("@#{k}", v)
      end
    end

    def script
      raise "No columns!" if @columns.nil? || @columns.length == 0
      col_indent = @columns.max_by { |c| c.name.length }.name.length
      parts = []
      parts << "CREATE TABLE #{@schema.quotename}.#{@name.quotename} ("
      parts << @columns.sort_by { |c| c.column_id }.map {|c| "    #{c.definition(col_indent)}" }.join(",\n")
      parts << ")"
      parts << "ON #{@data_space.quotename}"
      if !@lob_space.nil? && @lob_space != @data_space
        parts << "TEXTIMAGE_ON #{@lob_space.quotename}"
      end
      "#{parts.join("\n")};"
    end
  end
end
