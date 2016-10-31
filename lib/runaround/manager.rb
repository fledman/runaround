require "fiber"
require "runaround/callback_hook"

module Runaround
  class Manager
    attr_reader :receiver

    def initialize(receiver)
      @receiver = receiver
    end

    def prepare_callback(method:, type:, fifo:, &block)
      setup_callback_hook(method)
      list = all_callbacks(method)[type]
      fifo ? list << block : list.unshift(block)
      list.size
    end

    def callbacks(method)
      all = all_callbacks(method)
      blocks = all.dup.tap{ |h| h.delete(:around) }
      fibers = all[:around].map{ |b| Fiber.new(&b) }
      return blocks, fibers
    end

    private

    def callback_hooks
      @callback_hooks ||= {}
    end

    def all_callbacks(method)
      @all_callbacks ||= {}
      @all_callbacks[method] ||= { before:[], after:[], around: [] }
    end

    def setup_callback_hook(method)
      return true if callback_hooks[method]
      callback_hooks[method] = CallbackHook.build_for(method, self)
      receiver.singleton_class.prepend callback_hooks[method]
    end

  end
end
