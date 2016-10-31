require "runaround/version"
require "runaround/manager"

module Runaround
  def run_before(method, fifo: true, &block)
    runaround_manager.prepare_callback(
      method: method, type: :before, fifo: fifo, &block)
  end

  def run_after(method, fifo: true, &block)
    runaround_manager.prepare_callback(
      method: method, type: :after, fifo: fifo, &block)
  end

  def run_around(method, fifo: false, &block)
    runaround_manager.prepare_callback(
      method: method, type: :around, fifo: fifo, &block)
  end

  private

  def runaround_manager
    @runaround_manager ||= Manager.new(self)
  end
end
