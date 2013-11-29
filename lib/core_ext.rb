class String
  def quotename
    ::Mossy::Helpers::quotename(self)
  end

  def sql_escape
    ::Mossy::Helpers::escape(self)
  end

  def sql_quote
    ::Mossy::Helpers::quote(self)
  end
end

class Array
  def to_sql_list
    self.map { |e| e.sql_quote }.join(', ')
  end
end
