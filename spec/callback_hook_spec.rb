require 'spec_helper'

describe Runaround::CallbackHook do
  describe '.build_for' do
    let(:manager) { instance_double(Runaround::Manager) }

    let(:method) { :foobar }

    let(:result) { described_class.build_for(method, manager) }

    it 'creates an anonymous module' do
      expect(result).to be_a Module
    end

    it 'has the expected instance method' do
      expect(result.instance_methods).to eql [method]
    end

    class FooBar
      def foo; "FOO"; end
      def bar; "BAR"; end
      def foobar; foo + bar; end
      def barfoo(a,b,z:,**rest)
        rest.merge(a:a,b:b,z:z)
      end
    end

    context 'after prepending the module' do
      let(:obj) { FooBar.new }

      before { obj.singleton_class.prepend result }

      def expect_calls(before: [], after: [], around: [])
        calls = [{before: before, after: after}, around]
        expect(manager).to receive(:callbacks).with(method).and_return(calls)
      end

      context 'the hook' do
        it 'does not attempt callbacks for :foo' do
          expect(manager).not_to receive(:callbacks)
          expect(obj.foo).to eql "FOO"
        end

        it 'does not attempt callbacks for :bar' do
          expect(manager).not_to receive(:callbacks)
          expect(obj.bar).to eql "BAR"
        end

        it 'does attempt callbacks for :foobar' do
          expect_calls
          expect(obj.foobar).to eql "FOOBAR"
        end
      end

      let(:marker) { Hash.new }

      def runner(val)
        lambda do |mc|
          marker[mc.method] ?
            marker[mc.method] += val :
              marker[mc.method] = val
        end
      end

      context 'callbacks' do
        it 'can run before the method' do
          expect_calls before: [runner('B')]
          expect(obj.foobar).to eql "FOOBAR"
          expect(marker).to eql({ foobar: 'B' })
        end

        it 'can run after the method' do
          expect_calls after: [runner('A')]
          expect(obj.foobar).to eql "FOOBAR"
          expect(marker).to eql({ foobar: 'A' })
        end

        it 'can run before and after the method' do
          expect_calls before: [runner('B1'),runner('B2')], after: [runner('A')]
          expect(obj.foobar).to eql "FOOBAR"
          expect(marker).to eql({ foobar: 'B1B2A' })
        end

        it 'can run around the method' do
          fnA1, fnB1, fnA2, fnB2 = %w{ A1 B1 A2 B2 }.map{ |x| runner(x) }
          fiber1 = Fiber.new { |mc| fnB1[mc]; mc.run_method; fnA1[mc] }
          fiber2 = Fiber.new { |mc| fnB2[mc]; mc.run_method; fnA2[mc] }
          expect_calls around: [fiber1, fiber2]
          expect(obj.foobar).to eql "FOOBAR"
          expect(marker).to eql({ foobar: "B1B2A2A1" })
        end

        it 'can run before, around, and after the method' do
          fnA1, fnB1, fnA2, fnB2 = %w{ A1 B1 A2 B2 }.map{ |x| runner(x) }
          fiber1 = Fiber.new { |mc| fnB1[mc]; mc.run_method; fnA1[mc] }
          fiber2 = Fiber.new { |mc| fnB2[mc]; mc.run_method; fnA2[mc] }
          expect_calls  before: [runner('C')],
                        after: [runner('D')],
                        around: [fiber1, fiber2]
          expect(obj.foobar).to eql "FOOBAR"
          expect(marker).to eql({ foobar: "CB1B2A2A1D" })
        end

        context 'results' do
          it 'can alter the return value with after' do
            expect_calls after: [->(mc){ mc.return_value = "W00t" }]
            expect(obj.foobar).to eql "W00t"
          end

          it 'can alter the return value with around' do
            fiber = Fiber.new do |mc|
              retval = mc.run_method
              mc.return_value += retval
            end
            expect_calls around: [fiber]
            expect(obj.foobar).to eql "FOOBARFOOBAR"
          end
        end

        context 'with method arguments' do
          let(:method) { :barfoo }

          it 'pass the arguments through' do
            counter = runner(1)
            check_args = lambda do |mc|
              expect(mc.args).to eql [1,2]
              expect(mc.opts).to eql({z: 'zz', y: '?', x: :+})
              counter[mc]
            end
            fiber = Fiber.new do |mc|
              check_args[mc]; mc.run_method; check_args[mc]
            end
            expect_calls( before: [check_args],
                          after:  [check_args],
                          around: [fiber])
            expect(obj.barfoo(1, 2, z: 'zz', y: '?', x: :+)).to eql({
                              a: 1, b: 2, x: :+, y: '?', z: 'zz' })
            expect(marker[method]).to eql 4
          end
        end
      end
    end

  end
end
