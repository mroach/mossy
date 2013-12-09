module Mossy
  class Connection

    attr_reader :connection
    attr_reader :query_count, :query_time

    DEFAULTS = {
      :appname => "Mossy",
      :timeout => 20,
      :login_timeout => 10,
      :logger => Logger.new(nil)
    }.freeze

    def initialize(args = {})
      args = args ? DEFAULTS.merge(args) : DEFAULTS
      args.each do |k,v|
        instance_variable_set("@#{k}", v)
      end

      @query_count = 0
      @query_time = 0

      @connection = ::TinyTds::Client.new(args)

      # configure the same set options as you'd get in Management Studio
      set_options = {
        "ROWCOUNT" => "0",
        "TEXTSIZE" => "2147483647",
        "NOCOUNT" => "OFF",
        "CONCAT_NULL_YIELDS_NULL" => "ON",
        "ARITHABORT" => "ON",
        "ANSI_NULLS" => "ON",
        "ANSI_PADDING" => "ON",
        "ANSI_WARNINGS" => "ON",
        "CURSOR_CLOSE_ON_COMMIT" => "OFF",
        "IMPLICIT_TRANSACTIONS" => "OFF",
        "QUOTED_IDENTIFIER" => "ON",
        "TRANSACTION ISOLATION LEVEL" => "READ COMMITTED"
      }
      exec_non_query(set_options.map { |name,value| "SET #{name} #{value};" }.join(' '))

      @database = exec_scalar("SELECT DB_NAME();")
    end

    def use(database)
      @database = database
      exec_non_query("USE #{database.quotename};")
    end

    def exec_rows(sql)
      result = exec(sql) { |r| r.each(:symbolize_keys => true) }
      a = []
      result.each{ |r| a.push(r) }
      a
    end

    # executes a query and returns a column as a simple array
    # eg) select name from sys.database_principals => ["user1", "user2"]
    def exec_array(sql, col = 0)
      exec(sql) { |r| r.each(:as => :array).map { |r| r[col] } }
    end

    # executes a query and returns the first field of the first record
    # eg) select @@version => "Microsoft SQL Server 2008 R2 (SP2)..."
    def exec_scalar(sql)
      exec(sql) { |r| r.each(:as => :array).first.first }
    end

    # execute a query that does not return a recordset
    def exec_non_query(sql)
      exec(sql) { |r| r.do }
    end

    protected

    def exec(sql)
      @logger.debug("#{@username}@#{@host}:#{@database}") { sql }
      result = nil
      @query_count += 1
      @query_time += ::Benchmark.realtime do
        q = @connection.execute(sql)
        result = yield q
      end
      result
    end
  end
end
