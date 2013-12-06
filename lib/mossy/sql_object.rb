module Mossy
  class SqlObject
    attr_accessor :schema, :name, :extended_properties

    def initialize(spec = {})
      spec.each do |k,v|
        instance_variable_set("@#{k}", v)
      end
    end

    def drop_script
      "IF OBJECT_ID(#{name.sql_quote}) IS NOT NULL\n" +
      "  DROP #{self.class.name.split('::').last.upcase} #{name.quotename};"
    end
  end
end
