$:.unshift File.dirname(__FILE__)

require 'core_ext.rb'

# this is a dependency of a bunch of files
# this may benefit from a file structure re-org
require 'mossy/sql_object'

Dir[File.dirname(__FILE__) + "/mossy/*.rb"].each{ |file| require(file) }
