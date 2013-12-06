module Mossy
  class Login

    attr_accessor :name, :sid, :password_hash, :default_database_name
    attr_accessor :is_policy_checked, :is_disabled
    attr_accessor :has_server_roles
    attr_accessor :server_roles

    def initialize(spec = {})
      spec.each do |k,v|
        instance_variable_set("@#{k}", v)
      end
    end

    def script_create(sql_2012 = false)
      parts = []
      parts << "CREATE LOGIN #{@name.quotename} WITH #{login_properties_sql};"

      if @is_disabled
        parts << "ALTER LOGIN #{@name} DISABLE;"
      end

      # add the login to server roles if necessary
      # SQL 2012 and later use ALTER SERVER ROLE rather than sp_addsrvrolemember
      if @has_server_roles
        if sql_2012
          parts << @server_roles.map { |r| "ALTER SERVER ROLE #{r.quotename} ADD MEMBER #{@name.quotename};"}
        else
          parts << @server_roles.map { |r| "EXEC sp_addsrvrolemember #{@name.sql_quote}, #{r.sql_quote};"}
        end
      end

      parts.join("\n    ")
    end

    protected

    # generate SQL to use after the "WITH" part of a CREATE or ALTER LOGIN
    # statement. optionally exclude the check policy option (needed for alter)
    def login_properties_sql
      props = {}

      # if no plain-text password was passed, use the password hash (better)
      if @password.nil?
        props["PASSWORD"] = "#{@password_hash.sql_bin} HASHED"
      else
        props["PASSWORD"] = @password.sql_quote
      end

      if !@sid.nil?
        props["SID"] = @sid.sql_bin
      end

      if !@default_database.nil?
        props["DEFAULT_DATABASE"] = @default_database.quotename
      end

      if @is_policy_checked.nil?
        props["CHECK_POLICY"] = @is_policy_checked ? 'ON' : 'OFF'
      end

      props.map { |k,v| "#{k} = #{v}" }.join(', ')
    end

  end
end
