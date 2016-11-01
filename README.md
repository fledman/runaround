# Runaround

An Easy Callback System for Ruby Objects

## Installation

Add `gem 'runaround'` to your Gemfile

## Usage

`Runaround` can be used to add `before`, `after`, and `around` callbacks to your ruby objects.

#### Callbacks on a specific object instance
```ruby
class Subtractor
  include Runaround
  def subtract(a,b)
    a - b
  end
end

object = Subtractor.new
object.runaround.before(:subtract){ |mc| mc.args.reverse! }
object.subtract(7,4)
 => -3 
Subtractor.new.subtract(7,4)
 => 3
```

#### Callbacks on class methods
```ruby
class Formatter
  extend Runaround
  def self.format(string)
    string.downcase.tr('[w m]', '[m w]')
  end
  runaround.after(:format){ |mc| mc.return_value += '!' }
end

Formatter.format('WALMART')
 => 'malwart!' 
```

#### Callbacks on instance methods
```ruby
require 'json'
class Worker
  extend Runaround::InstanceMethods
  def work(**opts)
    opts.to_json
  end
  irunaround.around(:work) do |mc|
    puts "  BEFORE WORK"
    mc.opts[:foo_id] = 12345
    result = mc.run_method
    puts "  WORK COMPLETE, GOT: #{result.inspect}"
  end
end

worker = Worker.new
worker.work(thing: 'one')
  BEFORE WORK
  WORK COMPLETE, GOT: "{\"thing\":\"one\",\"foo_id\":12345}"
 => "{\"thing\":\"one\",\"foo_id\":12345}"
```

#### More Details
Callbacks are passed a [Runaround::MethodCall](https://github.com/fledman/runaround/blob/master/lib/runaround/method_call.rb) struct. This allows for manipulation of the input arguments/options as well as the return value. Be careful when using this functionality.

`before` and `after` callbacks are implemented using simple blocks, while `around` callbacks are implemented using `Fiber`s.
As such, `MethodCall#run_method` is only used for `around` callbacks. All `around` callbacks must call it.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/fledman/runaround.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
