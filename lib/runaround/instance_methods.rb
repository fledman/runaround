module Runaround
  module InstanceMethods

    def self.included(into)
      raise RuntimeError,
        "Runaround::InstanceMethods expects to be extended, not included"
    end

    def self.extended(into)
      into.extend Runaround
      into.include Runaround
      into.runaround.after(:new) do |mc|
        mc.return_value.runaround.import(into.runaround_instance_methods)
      end
    end

    def runaround_instance_methods
      @runaround_instance_methods ||= Manager.new(self, apply: false)
    end

  end
end
