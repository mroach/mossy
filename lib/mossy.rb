require 'tiny_tds'
require 'benchmark'
require 'logger'

$:.unshift File.dirname(__FILE__)

require 'core_ext.rb'

Dir[File.dirname(__FILE__) + "/mossy/*.rb"].each{ |file| require(file) }
