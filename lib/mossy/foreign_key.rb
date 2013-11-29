module Mossy
  class ForeignKey

    attr_accessor :name, :schema, :table, :referencing_column
    attr_accessor :referenced_table_schema, :referenced_table, :referenced_column
    attr_accessor :delete_action, :update_action

    def initialize(spec = {})
      spec.each do |k,v|
        instance_variable_set("@#{k}", v)
      end
    end

    def script
      parts = ["ALTER TABLE [#{@schema}].[#{@table}]"]
      parts << "ADD CONSTRAINT [#{@name}]"
      parts << "FOREIGN KEY (#{@referencing_column})"
      parts << "REFERENCES [#{@referenced_table_schema}].[#{@referenced_table}]"
      parts << "([#{@referenced_column}])"
      if @delete_action != "NO_ACTION"
        parts << "ON DELETE #{@delete_action}"
      end
      if @update_action != "NO_ACTION"
        parts << "ON UPDATE #{@update_action}"
      end
      "#{parts.join(' ')}"
    end
  end
end
