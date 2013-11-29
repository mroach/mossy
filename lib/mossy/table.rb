module Mossy
  class Table

    attr_accessor :schema, :name, :columns
    attr_accessor :data_space, :lob_space

    def initialize(spec = {})
      spec.each do |k,v|
        instance_variable_set("@#{k}", v)
      end
    end

    def script
      col_indent = @columns.max_by { |c| c.name.length }.name.length
      parts = []
      parts << "CREATE TABLE [#{@schema}].[#{@name}] ("
      parts << @columns.map {|c| "    #{c.definition(col_indent)}" }.join(",\n")
      parts << ")"
      parts << "ON [#{@data_space}]"
      if @lob_space != @data_space
        parts << "TEXTIMAGE_ON [#{@data_space}]"
      end
      "#{parts.join("\n")};"
    end
  end
end
