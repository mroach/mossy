module Mossy
  class View < SqlObject
    attr_accessor :permissions, :indexes
    attr_accessor :script
  end
end
