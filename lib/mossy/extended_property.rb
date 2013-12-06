module Mossy
  class ExtendedProperty

    attr_accessor :name, :value
    attr_accessor :level_0_type, :level_0_name
    attr_accessor :level_1_type, :level_1_name
    attr_accessor :level_2_type, :level_2_name

    def initialize(spec = {})
      spec.each do |k,v|
        instance_variable_set("@#{k}", v)
      end
    end

    def script
      params = [@name, @value, @level_0_type, @level_0_name]
      if !@level_1_type.nil?
        params << @level_1_type << @level_1_name
      end
      if !@level_2_type.nil?
        params << @level_2_type << @level_2_name
      end
      "EXEC sp_addextendedproperty #{params.to_sql_list};"
    end

    def drop_script
      params = [@name, @level_0_type, @level_0_name]
      if !@level_1_type.nil?
        params << @level_1_type << @level_1_name
      end
      if !@level_2_type.nil?
        params << @level_2_type << @level_2_name
      end
      "EXEC sp_dropextendedproperty #{params.to_sql_list}"
    end
  end
end
