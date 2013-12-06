module Mossy
  class Constraint

    attr_accessor :table, :name, :definition

    def initialize(spec = {})
      spec.each do |k,v|
        instance_variable_set("@#{k}", v)
      end
    end

    def script
      "ALTER TABLE #{@table.quotename} ADD CONSTRAINT " +
      "#{@name.quotename} CHECK #{@definition};"
    end

    def drop_script
      "IF OBJECT_ID(#{name.sql_quote}) IS NOT NULL\n" +
      "  ALTER TABLE #{@table.quotename} DROP CONSTRAINT #{name.quotename};"
    end
  end
end
