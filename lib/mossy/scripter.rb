module Mossy
  class Scripter

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
      'SN' => 'SYNONYM',
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

    def script_table(name)
      build_script(name, 'U', get_table(name).script)
    end

    def script_view(name)
      build_script(name, 'V', get_module(name))
    end

    def script_trigger(name)
      build_script(name, 'TR', get_module(name))
    end

    def script_procedure(name)
      build_script(name, 'P', get_module(name))
    end

    def script_scalar_function(name)
      build_script(name, 'FN', get_module(name))
    end

    def script_table_function(name)
      build_script(name, 'TF', get_module(name))
    end

    def script_inline_function(name)
      build_script(name, 'IF', get_module(name))
    end

    protected

    def build_script(name, type, main)
      permissions = []
      indexes = []
      foreign_keys = []
      constraints = []
      extended_properties = []

      if !['TR'].include?(type)
        permissions = get_permissions(name, type) if @include_permissions
      end

      if ['U', 'V'].include?(type)
        indexes = get_indexes(name, type) if @include_indexes
      end

      if type == 'U'
        foreign_keys = get_foreign_keys(name) if @include_foreign_keys
        constraints = get_constraints(name) if @include_constraints
      end

      extended_properties = get_extended_properties(name) if @include_extended_properties

      script = []

      if @include_use
        script << "USE #{@database.quotename};\nGO"
        script << ""
      end

      if @include_drop
        script << "IF OBJECT_ID('#{name}', '#{type}') IS NOT NULL"
        script << "  DROP #{OBJECT_TYPE_NAMES[type]} #{name.quotename};\nGO"
        script << ""
      end

      script << main
      script << "GO\n"

      append(script, foreign_keys, "FOREIGN KEYS")
      append(script, constraints, "CONSTRAINTS")
      append(script, indexes, "INDEXES")
      append(script, permissions, "PERMISSIONS")
      append(script, extended_properties, "EXTENDED PROPERTIES")

      script.join("\n")
    end

    def get_module(name)
      @connection.exec_scalar(<<-SQL
        select
          definition
        from
          sys.sql_modules
        where
          object_id = object_id('#{name}');
      SQL
      )
    end

    def get_table(name)
      spec = @connection.exec_rows(<<-SQL
        -- fetching table #{name}
        select
          [schema] = schema_name(schema_id),
          name,
          data_space = (
            select top 1 filegroup_name(data_space_id)
            from   sys.indexes
            where  object_id = t.object_id
            order by index_id
          ),
          lob_space = filegroup_name(lob_data_space_id)
        from
          sys.tables t
        where
          object_id = object_id('#{name}', 'U');
      SQL
      ).first

      table = Table.new(spec)
      table.columns = get_columns(name)
      table
    end

    def get_permissions(object, type = nil)
      @connection.exec_rows(<<-SQL
        -- fetching permissions for #{object}
        declare @type varchar(2) = '#{type}';
        if nullif(@type, '') is null
          select @type = type from sys.objects where name = '#{object}';
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
          and p.major_id = object_id('#{object}', @type);
      SQL
      ).map { |p| Permission.new(p) }
    end

    def get_columns(table)
      @connection.exec_rows(<<-SQL
        -- fetching columns for #{table}
        select
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
          left join sys.computed_columns cc on cc.object_id = c.object_id
            and cc.column_id = c.column_id
          left join sys.identity_columns ic on ic.object_id = c.object_id
            and ic.column_id = c.column_id
          left join sys.default_constraints dc on dc.object_id = c.default_object_id
        where
          c.object_id = object_id('#{table}', 'U')
        order by
          c.column_id;
      SQL
      ).map { |c| Column.new(c) }
    end

    def get_constraints(table)
      @connection.exec_rows(<<-SQL
        -- fetching constraints for #{table}
        select
          name,
          [table] = object_name(parent_object_id),
          [column] = col_name(parent_object_id, parent_column_id),
          definition
        from
          sys.check_constraints
        where
          parent_object_id = object_id('#{table}', 'U');
      SQL
      ).map { |c| Constraint.new(c) }
    end

    def get_foreign_keys(table)
      @connection.exec_rows(<<-SQL
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
        where
          fk.parent_object_id = object_id('#{table}');
      SQL
      ).map { |k| ForeignKey.new(k) }
    end

    def get_indexes(object, type = nil)
      rows = @connection.exec_rows(<<-SQL
        -- fetching indexes for #{object}
        declare @type varchar(2) = '#{type}';
        if nullif(@type, '') is null
          select @type = type from sys.objects where name = '#{object}';
        select
          -- index properties
          i.name,
          [table] = object_name(i.object_id),
          type = i.type_desc,
          i.is_primary_key,
          i.ignore_dup_key,
          i.fill_factor,
          i.is_padded,
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
        where
          i.object_id = object_id('#{object}', @type);
      SQL
      )

      # it's likely that this isn't the best way to do this.
      # the index contains one or more columns but we don't want to run a separate query
      # to get the columns. so we need to do some grouping here
      indexes = []
      rows.group_by {|r| r[:name]}.each do |name,props|
        # list of fields that are column properties and not part of the index intself
        col_fields = [:column_name, :is_descending_key, :is_included_column, :index_column_id]

        ix = props.first.dup
        # remove column fields from the index "header"
        col_fields.each { |c| ix.delete(c) }
        # add a :columns element that has a list of the columns
        ix[:columns] = props.map{|p| p.reject {|k,v| !col_fields.include?(k)}}
        indexes << ix
      end
      indexes.map { |i| Index.new(i) }
    end

    def get_extended_properties(object)
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

    def get_tables
      @connection.exec_array("SELECT name FROM sys.tables;")
    end

    def append(script, items, title)
      if items.any?
        if @comment_scripts
          script << '-' * 80
          script << "-- #{title}\n--"
        end
        script.concat(items.map { |i| i.script })
        script << ""
      end
    end
  end
end
