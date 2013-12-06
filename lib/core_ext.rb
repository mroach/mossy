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

  def sql_bin
    "0x" + self.unpack('H*').first
  end

  def titleize
    split(/(\W)/).map(&:capitalize).join
  end
end

class Array
  def to_sql_list
    self.map { |e| e.sql_quote }.join(', ')
  end
end
