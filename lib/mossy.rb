$:.unshift File.dirname(__FILE__)

require 'core_ext.rb'

%w(column connection constraint foreign_key helpers index permission scripter table).each do |file|
  require "mossy/#{file}"
end
