require "runaround/version"
require "runaround/manager"

module Runaround

  def runaround
    @runaround ||= Manager.new(self)
  end

end
