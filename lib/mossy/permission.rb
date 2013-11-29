module Mossy
  class Permission

    attr_accessor :grant_or_deny, :permission_name, :grantee
    attr_accessor :major_name, :minor_name

    def initialize(spec = {})
      spec.each do |k,v|
        instance_variable_set("@#{k}", v)
      end
    end

    def script
      parts = []
      parts << "#{@grant_or_deny} #{@permission_name} ON [#{@major_name}]"
      if !@minor_name.nil?
        parts << "(#{@minor_name})"
      end
      parts << (@grant_or_deny == "REVOKE" ? "FROM" : "TO")
      parts << "[#{@grantee}]"
      "#{parts.join(' ')};"
    end
  end
end
