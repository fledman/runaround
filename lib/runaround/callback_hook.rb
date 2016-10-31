require "runaround/method_call"

module Runaround
  module CallbackHook

    def self.build_for(method, manager)
      Module.new do
        define_method(method) do |*args,**opts,&block|
          mc = MethodCall.new(method, args, opts, block)
          blocks, fibers = manager.callbacks(method)
          blocks[:before].each { |b| b.call(mc) }
          fibers.each { |f| f.resume(mc) }
          mc.return_value = super(*mc.argsopts, &mc.block)
          fibers.reverse_each { |f| f.resume(mc.return_value) }
          blocks[:after].each { |b| b.call(mc) }
          mc.return_value
        end
      end
    end

  end
end
