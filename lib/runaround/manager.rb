require "fiber"
require "runaround/callback_hook"
require "runaround/errors"

module Runaround
  class Manager
    attr_reader :receiver

    def initialize(receiver)
      @receiver = receiver
    end

    def before(method, fifo: true, &block)
      prepare_callback(
        method: method, type: :before, fifo: fifo, &block)
    end

    def after(method, fifo: true, &block)
      prepare_callback(
        method: method, type: :after, fifo: fifo, &block)
    end

    def around(method, fifo: false, &block)
      prepare_callback(
        method: method, type: :around, fifo: fifo, &block)
    end

    def callbacks(method)
      all = all_callbacks(method)
      blocks = all.dup.tap{ |h| h.delete(:around) }
      fibers = all[:around].map{ |b| Fiber.new(&b) }
      return blocks, fibers
    end

    def to_h
      callback_hooks.keys.reduce({}) do |h, method|
        h[method] = copy_callback_map(method); h
      end
    end

    private

    def prepare_callback(method:, type:, fifo:, &block)
      validate_opts!(method, type, fifo, block)
      setup_callback_hook(method)
      list = all_callbacks(method)[type]
      fifo ? list << block : list.unshift(block)
      list.size
    end

    def setup_callback_hook(method)
      return true if callback_hooks[method]
      callback_hooks[method] = CallbackHook.build_for(method, self)
      receiver.singleton_class.prepend callback_hooks[method]
    end

    def validate_opts!(method, type, fifo, block)
      validate_method!(method)
      validate_type!(type)
      validate_fifo!(fifo)
      validate_block!(block)
    end

    def validate_method!(method)
      return if receiver.respond_to?(method)
      msg = "the receiver does not respond to #{method.inspect}"
      raise CallbackSetupError, "#{msg} ==> receiver.inspect"
    end

    def validate_type!(type)
      return if [:before, :after, :around].include?(type)
      msg = "#{type.inspect} is not a valid callback type"
      msg += "; must be one of [:before, :after, :around]"
      raise CallbackSetupError, msg
    end

    def validate_fifo!(fifo)
      return if [true, false, nil].include?(fifo)
      msg = "fifo must be true, false, or nil; got #{fifo.inspect}"
      raise CallbackSetupError, msg
    end

    def validate_block!(block)
      return if block.is_a?(Proc)
      raise CallbackSetupError, "you must pass a block for the callback!"
    end

    def copy_callback_map(method)
      all_callbacks(method).reduce({}) do |map,(type,arr)|
        map[type] = arr.dup; map
      end
    end

    def callback_hooks
      @callback_hooks ||= {}
    end

    def all_callbacks(method)
      @all_callbacks ||= {}
      @all_callbacks[method] ||= { before: [], after: [], around: [] }
    end

  end
end
