module Mossy
  class Scripter

    attr_accessor :include_use, :include_drop
    attr_accessor :include_permissions, :include_constraints, :include_indexes
    attr_accessor :include_foreign_keys, :include_extended_properties
    attr_accessor :comment_scripts

    DEFAULTS = {
      :appname => "Mossy::Scripter",
      :include_use => true,
      :include_drop => true,
      :include_permissions => true,
      :include_constraints => true,
      :include_indexes => true,
      :include_foreign_keys => true,
      :include_extended_properties => true,
      :comment_scripts => true
    }.freeze

    # map object type abbreviations to names used in create/drop statements
    OBJECT_TYPE_NAMES = {
      'V'  => 'VIEW',
      'P'  => 'PROCEDURE',
      'U'  => 'TABLE',
      'FN' => 'FUNCTION',
      'TF' => 'FUNCTION',
      'IF' => 'FUNCTiON',
      'TR' => 'TRIGGER'
    }.freeze

    # connection: Mossy::Connection
    def initialize(connection, args = {})
      args = args ? DEFAULTS.merge(args) : DEFAULTS
      args.each do |k,v|
        instance_variable_set("@#{k}", v)
      end

      @connection = connection
      @connection.use(@database)
    end

    def query_count
      @connection.query_count
    end

    def query_time
      @connection.query_time
    end

    def script_schema(types = {})
      default_types = {
        :tables => false,
        :views => false,
        :triggers => false,
        :procedures => false,
        :functions => false,
        :foreign_keys => false
      }
      types = types ? default_types.merge(types) : default_types

      @permissions = get_permissions.group_by { |p| p.major_name.downcase }
      @extended_properties = get_extended_properties.group_by { |x| x.level_0_name.downcase }
      @constraints = get_constraints.group_by { |c| c.table.downcase }
      @indexes = get_indexes.group_by { |i| i.table.downcase }

      if types[:tables]
        get_tables.each do |table|
          script = build_script(table, :permissions => true, :constraints => true, :indexes => true, :extended_properties => true, :foreign_keys => false)
          yield :table, table.name, script if block_given?
        end
      end

      if types[:functions]
        get_modules(:type => %w(FN TF IF)).each do |fn|
          script = build_script(fn, :permissions => true, :extended_properties => true)
          yield :function, fn.name, script if block_given?
        end
      end

      if types[:views]
        get_modules(:type => 'V').each do |view|
          script = build_script(view, :permissions => true, :indexes => true, :extended_properties => true)
          yield :view, view.name, script if block_given?
        end
      end

      if types[:triggers]
        get_modules(:type => 'TR').each do |tr|
          script = build_script(tr, :extended_properties => true)
          yield :trigger, tr.name, script if block_given?
        end
      end

      if types[:procedures]
        get_modules(:type => 'P').each do |p|
          script = build_script(p, :permissions => true, :extended_properties => true)
          yield :procedure, p.name, script if block_given?
        end
      end

      if types[:foreign_keys]
        get_foreign_keys.each do |key|
          yield :foreign_key, key.name, key.script if block_given?
        end
      end
    end

    def script_table(name)
      build_script(get_tables(name).first)
    end

    def script_view(name)
      build_script(get_modules(name, 'V'))
    end

    def script_trigger(name)
      build_script(get_modules(name, 'TR'))
    end

    def script_procedure(name)
      build_script(get_modules(name, 'P'))
    end

    def script_function(name)
      build_script(get_modules(name, %w(FN TF IF)))
    end

    def script_logins(where)
      get_logins_where(where).map { |l| l.script_create }.join("\n")
    end

    protected

    def build_script(obj, includes = {})

      default_includes = {
        :use => @include_use,
        :drop => @include_drop,
        :permissions => @include_permissions,
        :constraints => @include_constraints,
        :indexes => @include_indexes,
        :foreign_keys => @include_foreign_keys,
        :extended_properties => @include_extended_properties
      }
      includes = includes ? default_includes.merge(includes) : default_includes

      if includes[:permissions] && defined?(obj.permissions)
        if defined?(@permissions) && !@permissions.nil?
          obj.permissions = @permissions[obj.name.downcase]
        else
          obj.permissions = get_permissions(obj.name)
        end
      end

      if includes[:indexes] && defined?(obj.indexes)
        if defined?(@indexes) && !@indexes.nil?
          obj.indexes = @indexes[obj.name.downcase]
        else
          obj.indexes = get_indexes(obj.name)
        end
      end

      if includes[:constraints] && defined?(obj.constraints)
        if defined?(@constraints) && !@constraints.nil?
          obj.constraints = @constraints[obj.name.downcase]
        else
          obj.constraints = get_constraints(obj.name)
        end
      end

      if includes[:foreign_keys] && defined?(obj.foreign_keys)
        if defined?(@foreign_keys) && !@foreign_keys.nil?
          obj.foreign_keys = @foreign_keys[obj.name.downcase]
        else
          obj.foreign_keys = get_foreign_keys(obj.name)
        end
      end

      if includes[:extended_properties]
        if defined?(@extended_properties) && !@extended_properties.nil?
          obj.extended_properties = @extended_properties[obj.name.downcase]
        else
          obj.extended_properties = get_extended_properties(obj.name)
        end
      end

      script = []

      if includes[:use]
        script << "USE #{@database.quotename};\nGO"
        script << ""
      end

      # TODO: This is insufficnet for many object types
      if includes[:drop]
        script << obj.drop_script
        script << "GO\n"
      end

      script << obj.script
      script << "GO\n"

      append(script, obj.foreign_keys, "FOREIGN KEYS") if defined?(obj.foreign_keys)
      append(script, obj.constraints, "CONSTRAINTS") if defined?(obj.constraints)
      append(script, obj.indexes, "INDEXES") if defined?(obj.indexes)
      append(script, obj.permissions, "PERMISSIONS") if defined?(obj.permissions)
      append(script, obj.extended_properties, "EXTENDED PROPERTIES") if defined?(obj.extended_properties)

      script.join("\n")
    end

    def get_modules(filters = {})
      puts "Loading modules with filters #{filters.inspect}"
      sql = <<-SQL
        select
          [schema] = schema_name(o.schema_id),
          name = o.name,
          script = m.definition,
          type = rtrim(o.type)
        from
          sys.sql_modules m
          inner join sys.objects o on o.object_id = m.object_id
        where
          o.is_ms_shipped = 0
      SQL
      if filters[:name]
        sql += "and m.object_id = object_id(#{filters[:name].sql_quote})\n"
      end
      if filters[:type]
        tf = filters[:type].kind_of?(Array) ? filters[:type].to_sql_list : filters[:type].sql_quote
        sql += "and o.type in (#{tf})"
      end
      @connection.exec_rows("#{sql};").map do |spec|
        class_name = OBJECT_TYPE_NAMES[spec[:type]].titleize
        model = Object.const_get("Mossy::#{class_name}")
        model.new(spec)
      end
    end

    def get_tables(table = nil)
      sql = <<-SQL
        select
          -- TABLE
          [schema] = schema_name(t.schema_id),
          [table] = t.name,
          data_space = (
            select top 1 filegroup_name(data_space_id)
            from   sys.indexes
            where  object_id = t.object_id
            order by index_id
          ),
          lob_space = filegroup_name(t.lob_data_space_id),

          -- COLUMNS
          c.name,
          c.column_id,
          type = type_name(c.user_type_id),
          c.max_length,
          c.precision,
          c.scale,
          c.is_nullable,
          c.is_identity,
          c.is_computed,

          seed_value = convert(bigint, ic.seed_value),
          increment_value = convert(bigint, ic.increment_value),

          computed_definition = cc.definition,
          default_definition = dc.definition

        from
          sys.columns c
          inner join sys.tables t on t.object_id = c.object_id
          left join sys.computed_columns cc on cc.object_id = c.object_id
            and cc.column_id = c.column_id
          left join sys.identity_columns ic on ic.object_id = c.object_id
            and ic.column_id = c.column_id
          left join sys.default_constraints dc on dc.object_id = c.default_object_id
        where
          t.is_ms_shipped = 0
      SQL
      if !table.nil?
        sql += "and c.object_id = object_id(#{table.sql_quote}, 'U')"
      end
      rows = @connection.exec_rows("#{sql};")

      tables = []
      rows.group_by {|r| r[:table]}.each do |name,props|
        # list of fields that are part of the table header and not column info
        table_fields = [:schema, :table, :data_space, :lob_space]

        # table header info
        table_props = props.first.dup.select { |k,v| table_fields.include?(k) }

        # add a :columns element that has the column list
        columns_hash = props.map{ |p| p.reject { |k,v| table_fields.include?(k)} }
        table_props[:columns] = columns_hash.map { |p| Column.new(p) }
        tables << table_props
      end
      tables.map do |t|
        Table.new(
          :name => t[:table],
          :schema => t[:schema],
          :data_space => t[:data_space],
          :lob_space => t[:lob_space],
          :columns => t[:columns]
        )
      end.sort_by { |t| t.name }
    end

    def get_permissions(object = nil, type = nil)
      puts "Getting permissions for #{object}"
      sql = <<-SQL
        select
          grant_or_deny = state_desc,
          permission_name,
          major_name = object_name(major_id),
          minor_name = col_name(major_id, minor_id),
          grantee = user_name(grantee_principal_id)
        from
          sys.database_permissions p
        where
          p.class_desc = 'OBJECT_OR_COLUMN'
      SQL
      if !object.nil?
        sql = <<-SQL
        declare @type varchar(2) = '#{type}';
        if nullif(@type, '') is null
          select @type = type from sys.objects where name = '#{object}';

          #{sql}
          and p.major_id = object_id(#{object.sql_quote}, @type)
        SQL
      end
      @connection.exec_rows("#{sql};").map { |p| Permission.new(p) }.sort_by { |p| p.major_name }
    end

    def get_constraints(table = nil)
      puts "Getting constraints for #{table}"
      sql = <<-SQL
        -- fetching constraints for #{table}
        select
          name,
          [table] = object_name(parent_object_id),
          [column] = col_name(parent_object_id, parent_column_id),
          definition
        from
          sys.check_constraints
        where
          is_ms_shipped = 0
      SQL
      if !table.nil?
        sql += "and parent_object_id = object_id(#{table.sql_quote}, 'U')"
      end
      @connection.exec_rows("#{sql};").map { |c| Constraint.new(c) }.sort_by { |c| c.name }
    end

    def get_foreign_keys(table = nil)
      sql = <<-SQL
        select
          fk.name,
          [schema] = object_schema_name(fk.parent_object_id),
          [table] = object_name(fk.parent_object_id),
          referencing_column = col_name(fkc.parent_object_id, fkc.parent_column_id),
          referenced_table = object_name(fk.referenced_object_id),
          referenced_table_schema = object_schema_name(fk.referenced_object_id),
          referenced_column = col_name(fkc.referenced_object_id, fkc.referenced_column_id),
          delete_action = fk.delete_referential_action_desc,
          update_action = fk.update_referential_action_desc
        from
          sys.foreign_keys fk
          inner join sys.foreign_key_columns fkc on fkc.constraint_object_id = fk.object_id
          inner join sys.tables t on t.object_id = fk.parent_object_id
        where
          t.type = 'U'
      SQL
      if !table.nil?
        sql += "and t.name = #{table.sql_quote}"
      end
      @connection.exec_rows("#{sql};").map { |k| ForeignKey.new(k) }.sort_by { |k| k.name }
    end

    def get_indexes(object = nil)
      puts "Getting indexes for #{object}"
      sql = <<-SQL
        select
          -- index properties
          [table] = object_name(i.object_id),
          i.name,
          type = i.type_desc,
          i.is_primary_key,
          i.ignore_dup_key,
          i.fill_factor,
          i.is_padded,
          i.is_unique,
          i.is_unique_constraint,
          i.has_filter,
          i.filter_definition,
          data_space = filegroup_name(i.data_space_id),

          -- index columns
          column_name = col_name(ic.object_id, ic.column_id),
          ic.is_descending_key,
          ic.is_included_column,
          ic.index_column_id
        from
          sys.indexes i
          inner join sys.index_columns ic on ic.object_id = i.object_id
            and ic.index_id = i.index_id
          inner join sys.objects o on o.object_id = i.object_id
        where
          o.is_ms_shipped = 0
      SQL

      if !object.nil?
        sql += "and i.object_id = object_id(#{object.sql_quote})"
      end

      rows = @connection.exec_rows("#{sql};")

      # it's likely that this isn't the best way to do this.
      # the index contains one or more columns but we don't want to run a separate query
      # to get the columns. so we need to do some grouping here
      indexes = []
      rows.group_by {|r| "#{r[:table]}:#{r[:name]}" }.each do |name,props|
        # list of fields that are column properties and not part of the index intself
        col_fields = [:column_name, :is_descending_key, :is_included_column, :index_column_id]

        ix = props.first.dup
        # remove column fields from the index "header"
        col_fields.each { |c| ix.delete(c) }
        # add a :columns element that has a list of the columns
        ix[:columns] = props.map{|p| p.reject {|k,v| !col_fields.include?(k)}}
        indexes << ix
      end
      indexes.map { |i| Index.new(i) }.sort_by { |i| i.priority }
    end

    def get_extended_properties(object = nil)
      puts "Getting extended properties for #{object}"
      @connection.exec_rows(<<-SQL
        select
          name = x.name,
          value = convert(nvarchar(max), x.value),

          level_0_type = 'schema',
          level_0_name = object_schema_name(x.major_id),

          level_1_type = case o.type
                  when 'V' then 'view'
                  when 'P' then 'procedure'
                  when 'U' then 'table'
                  when 'FN' then 'function'
                  when 'TF' then 'function'
                  when 'IF' then 'function'
                  when 'SN' then 'synonym'
                  when 'TR' then 'trigger'
                end,

          level_1_name = o.name,

          level_2_type = case
                  when minor_id = 0 then null
                  when o.type = 'V' then 'column'
                  when o.type = 'P' then 'parameter'
                  when o.type = 'U' then 'column'
                end,
          level_2_name = case class
                  when 1 then col_name(major_id, minor_id)
                  when 2 then (select name from sys.parameters where object_id = x.major_id and parameter_id = x.minor_id)
                  when 7 then (select name from sys.indexes where object_id = x.major_id and index_id = x.minor_id)
                end
        from
          sys.extended_properties x
          inner join sys.objects o on o.object_id = x.major_id
        where
          x.major_id = object_id('#{object}');
      SQL
      ).map { |e| ExtendedProperty.new(e) }
    end

    def get_logins_where(where)
      logins = @connection.exec_rows(<<-SQL
        select
          name, sid, password_hash, default_database_name, is_policy_checked, is_disabled,
          has_server_roles = convert(bit, (
            select count(*)
            from   sys.server_role_members
            where  member_principal_id = login.principal_id))
        from
          sys.sql_logins login
        where
          principal_id > 1
          and name NOT LIKE '##MS_%'
          and (#{where})
        order by name;
      SQL
      ).map { |l| Login.new(l) }

      # if the login has server roles we need to fetch those
      logins.select { |login| login.has_server_roles }.each do |login|
        login.server_roles = @connection.exec_array(<<-SQL
          select suser_name(role_principal_id)
          from   sys.server_role_members
          where  member_principal_id = suser_id('#{login.name}');
        SQL
        )
      end

      logins
    end

    def append(script, items, title)
      return if items.nil? || !items.any?
      if @comment_scripts
        script << '-' * 80
        script << "-- #{title}\n--"
      end
      script.concat(items.map { |i| i.script })
      script << "GO\n"
    end
  end
end
