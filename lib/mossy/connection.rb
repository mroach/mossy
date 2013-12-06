require "tiny_tds"
require "benchmark"

module Mossy
  class Connection
    attr_reader :connection

    DEFAULTS = {
      :appname => "Mossy",
      :timeout => 20,
      :login_timeout => 10
    }.freeze

    attr_reader :query_count, :query_time

    def initialize(args = {})
      args = args ? DEFAULTS.merge(args) : DEFAULTS

      @query_count = 0
      @query_time = 0

      @connection = ::TinyTds::Client.new(args)

      # by default freetds will be using a text size of 64k
      # which translates to 32k of nvarchar which isn't enough
      exec_non_query("SET TEXTSIZE 2147483647;")

      # ensure our reading of metadata isn't hung up on transaction locks
      exec_non_query("SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;")
    end

    def use(database)
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
