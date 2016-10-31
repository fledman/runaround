require "runaround/version"
require "runaround/manager"
require "runaround/instance_methods"

module Runaround

  def runaround
    @runaround ||= Manager.new(self)
  end

end
