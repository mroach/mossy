require "tiny_tds"

module Mossy
  class Connection
    attr_reader :connection

    DEFAULTS = {
      :appname => File.basename($PROGRAM_NAME),
      :timeout => 20,
      :login_timeout => 10
    }.freeze

    def initialize(args = {})
      args = args ? DEFAULTS.merge(args) : DEFAULTS
      @connection = ::TinyTds::Client.new(args)
    end

    def use(database)
      exec_non_query("USE #{database.quotename};")
    end

    def exec_rows(sql)
      result = exec(sql)
      result.each(:symbolize_keys => true)
      a = []
      result.each{|r| a.push(r)}
      a
    end

    # executes a query and returns a column as a simple array
    # eg) select name from sys.database_principals => ["user1", "user2"]
    def exec_array(sql, col = 0)
      exec(sql).each(:as => :array).map { |r| r[col] }
    end

    # executes a query and returns the first field of the first record
    # eg) select @@version => "Microsoft SQL Server 2008 R2 (SP2)..."
    def exec_scalar(sql)
      result = exec(sql)
      result.each(:as => :array).first.first
    end

    # execute a query that does not return a recordset
    def exec_non_query(sql)
      exec(sql).do
    end

    def exec(sql)
      #puts sql
      @connection.execute(sql)
    end
  end
end
