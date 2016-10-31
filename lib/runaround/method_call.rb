module Runaround

  MethodCall = Struct.new(:method, :args, :opts, :block, :return_value) do
    def run_method
      Fiber.yield
    end

    def argsopts
      argsopts = args ? args.dup : []
      argsopts << opts if opts && !opts.empty?
      argsopts
    end
  end

end
