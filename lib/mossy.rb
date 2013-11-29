$:.unshift File.dirname(__FILE__)
%w(column connection constraint foreign_key index permission scripter table).each do |file|
  require "mossy/#{file}"
end
