require 'spec_helper'
require 'bigdecimal'

describe Runaround::Manager do
  let(:receiver) { BigDecimal.new(3.5, 2) }

  describe '.initialize' do
    it 'sets the receiver' do
      inst = described_class.new(receiver)
      expect(inst.receiver).to equal receiver
    end

    { apply: true,
      for_instances: false
    }.each do |attr, default|
      context attr.to_s do
        it "defaults to #{default}" do
          inst = described_class.new(receiver)
          expect(inst.public_send(attr)).to eql default
        end

        it "can be set to #{!default}" do
          inst = described_class.new(receiver, attr => (!default))
          expect(inst.public_send(attr)).to eql (!default)
        end

        it "converts a truthy input to true" do
          inst = described_class.new(receiver, attr => "0")
          expect(inst.public_send(attr)).to eql true
        end

        it "converts a falsey input to false" do
          inst = described_class.new(receiver, attr => nil)
          expect(inst.public_send(attr)).to eql false
        end
      end
    end
  end

  subject { described_class.new(receiver) }

  describe '.before' do
    it 'delegates to prepare_callback' do
      method, fifo, block = double(), double(), Proc.new{}
      expect(subject).to receive(:prepare_callback).with(
        type: :before, method: method, fifo: fifo, &block)
      subject.before(method, fifo: fifo, &block)
    end
  end

  describe '.after' do
    it 'delegates to prepare_callback' do
      method, fifo, block = double(), double(), Proc.new{}
      expect(subject).to receive(:prepare_callback).with(
        type: :after, method: method, fifo: fifo, &block)
      subject.after(method, fifo: fifo, &block)
    end
  end

  describe '.around' do
    it 'delegates to prepare_callback' do
      method, fifo, block = double(), double(), Proc.new{}
      expect(subject).to receive(:prepare_callback).with(
        type: :around, method: method, fifo: fifo, &block)
      subject.around(method, fifo: fifo, &block)
    end
  end

  let(:fn_count) do
    ->(h){ h.reduce(0){ |n,(_,v)| v.values.map(&:size).reduce(n,:+) } }
  end

  describe '.prepare_callback' do
    let(:fake_mod) { Module.new }

    it 'only builds the callback_hook once per method' do
      expect(Runaround::CallbackHook).to(receive(
        :build_for).with(:to_s, subject).and_return(fake_mod)).once
      expect(Runaround::CallbackHook).to(receive(
        :build_for).with(:to_i, subject).and_return(fake_mod)).once
      5.times{ subject.after(:to_s){}; subject.before(:to_i){} }
    end

    it 'stores the new callback' do
      expect(fn_count[subject.to_h]).to eql(0)

      expect(subject.after(:to_s){}).to eql(1)
      expect(fn_count[subject.to_h]).to eql(1)

      expect(subject.before(:to_i){}).to eql 1
      expect(fn_count[subject.to_h]).to eql(2)

      expect(subject.before(:to_s){}).to eql 1
      expect(fn_count[subject.to_h]).to eql(3)
    end

    context 'validation' do
      it 'raises for invalid methods' do
        expect { subject.before(:do_stuff){} }.to raise_error(
          Runaround::CallbackSetupError, /does not respond to :do_stuff/)
      end

      it 'raises for invalid ordering' do
        expect { subject.after(:to_i, fifo: 7){} }.to raise_error(
          Runaround::CallbackSetupError, /fifo must be true, false, or nil/)
      end

      it 'raises when not passed a block' do
        expect { subject.around(:to_i) }.to raise_error(
          Runaround::CallbackSetupError, /you must pass a block/)
      end

      it 'raises for an invalid callback type' do
        expect {
          subject.send(:prepare_callback, method: :to_i, type: :t, fifo: true)
        }.to raise_error(Runaround::CallbackSetupError, /not a valid callback type/)
      end
    end

    context 'when apply is true' do
      it 'prepends the callback_hook to the receiver' do
        expect(Runaround::CallbackHook).to(receive(
          :build_for).with(:to_s, subject).and_return(fake_mod))
        expect(receiver.singleton_class).to receive(:prepend).with(fake_mod)
        subject.after(:to_s){}
      end
    end

    context 'when apply is false' do
      subject { described_class.new(receiver, apply: false) }

      it 'does not prepend the callback_hook to the receiver' do
        expect(Runaround::CallbackHook).to(receive(
          :build_for).with(:to_s, subject).and_return(fake_mod))
        expect(receiver.singleton_class).not_to receive(:prepend)
        subject.after(:to_s){}
      end
    end

    context 'when fifo is true' do
      it 'runs before and after callbacks first-in-first-out' do
        tracker = []
        subject.before(:to_s, fifo: true){ tracker << 1 }
        subject.before(:to_s, fifo: true){ tracker << 2 }
        subject.before(:to_s, fifo: true){ tracker << 3 }
        subject.after(:to_s, fifo: true){ tracker << 4 }
        subject.after(:to_s, fifo: true){ tracker << 5 }
        subject.after(:to_s, fifo: true){ tracker << 6 }
        receiver.to_s
        expect(tracker).to eql [1,2,3,4,5,6]
      end

      it 'runs around callbacks first-in-first-out with nesting' do
        tracker = []
        subject.around(:to_s, fifo: true){
          |mc| tracker << 1; mc.run_method; tracker << 2}
        subject.around(:to_s, fifo: true){
          |mc| tracker << 3; mc.run_method; tracker << 4}
        subject.around(:to_s, fifo: true){
          |mc| tracker << 5; mc.run_method; tracker << 6}
        receiver.to_s
        expect(tracker).to eql [1,3,5,6,4,2]
      end
    end

    context 'when fifo is false' do
      it 'runs before and after callbacks first-in-last-out' do
        tracker = []
        subject.before(:to_s, fifo: false){ tracker << 1 }
        subject.before(:to_s, fifo: false){ tracker << 2 }
        subject.before(:to_s, fifo: false){ tracker << 3 }
        subject.after(:to_s, fifo: false){ tracker << 4 }
        subject.after(:to_s, fifo: false){ tracker << 5 }
        subject.after(:to_s, fifo: false){ tracker << 6 }
        receiver.to_s
        expect(tracker).to eql [3,2,1,6,5,4]
      end

      it 'runs around callbacks first-in-last-out with nesting' do
        tracker = []
        subject.around(:to_s, fifo: false){
          |mc| tracker << 1; mc.run_method; tracker << 2}
        subject.around(:to_s, fifo: false){
          |mc| tracker << 3; mc.run_method; tracker << 4}
        subject.around(:to_s, fifo: false){
          |mc| tracker << 5; mc.run_method; tracker << 6}
        receiver.to_s
        expect(tracker).to eql [5,3,1,2,4,6]
      end
    end

    context 'when fifo is mixed' do
      it 'runs before and after callbacks in the correct order' do
        tracker = []
        subject.before(:to_s, fifo: false){ tracker << 1 }
        subject.before(:to_s, fifo: true){ tracker << 2 }
        subject.before(:to_s, fifo: false){ tracker << 3 }
        subject.after(:to_s, fifo: true){ tracker << 4 }
        subject.after(:to_s, fifo: false){ tracker << 5 }
        subject.after(:to_s, fifo: true){ tracker << 6 }
        receiver.to_s
        expect(tracker).to eql [3,1,2,5,4,6]
      end

      it 'runs around callbacks in the correct nested order' do
        tracker = []
        subject.around(:to_s, fifo: true){
          |mc| tracker << 1; mc.run_method; tracker << 2}
        subject.around(:to_s, fifo: false){
          |mc| tracker << 3; mc.run_method; tracker << 4}
        subject.around(:to_s, fifo: true){
          |mc| tracker << 5; mc.run_method; tracker << 6}
        receiver.to_s
        expect(tracker).to eql [3,1,5,6,2,4]
      end
    end
  end

  context 'with example callbacks' do
    def proc(n)
      (@procs ||= {})[n] ||= Proc.new{n}
    end

    before do
      subject.before(:to_f, &proc(1))
      subject.after(:to_f, &proc(2))
      subject.around(:to_f, &proc(3))

      subject.before(:to_i, &proc(4))
      subject.after(:to_s, &proc(5))
      subject.around(:inspect, &proc(6))
    end

    describe '.callbacks' do
      it 'before, after, and around' do
        blocks, fibers = subject.callbacks(:to_f)
        expect(blocks.keys).to eql [:before, :after]
        expect(blocks[:before]).to eql [proc(1)]
        expect(blocks[:after]).to eql [proc(2)]
        expect(fibers.map(&:class)).to eql [Fiber]
        expect(fibers.map(&:resume)).to eql [3]
      end

      it 'just before' do
        blocks, fibers = subject.callbacks(:to_i)
        expect(blocks.keys).to eql [:before, :after]
        expect(blocks[:before]).to eql [proc(4)]
        expect(blocks[:after]).to eql []
        expect(fibers).to eql []
      end

      it 'just after' do
        blocks, fibers = subject.callbacks(:to_s)
        expect(blocks.keys).to eql [:before, :after]
        expect(blocks[:before]).to eql []
        expect(blocks[:after]).to eql [proc(5)]
        expect(fibers).to eql []
      end

      it 'just around' do
        blocks, fibers = subject.callbacks(:inspect)
        expect(blocks.keys).to eql [:before, :after]
        expect(blocks[:before]).to eql []
        expect(blocks[:after]).to eql []
        expect(fibers.map(&:class)).to eql [Fiber]
        expect(fibers.map(&:resume)).to eql [6]
      end
    end

    describe '.to_h' do
      it 'returns a hash containing the callback blocks' do
        expect(subject.to_h).to eql({
          to_i: { before: [proc(4)], after: [], around: [] },
          to_s: { before: [], after: [proc(5)], around: [] },
          to_f: { before: [proc(1)], after: [proc(2)], around: [proc(3)] },
          inspect: { before: [], after: [], around: [proc(6)] }
        })
      end

      it 'does not propagate mutations to the backing store' do
        hash = subject.to_h
        hash[:to_s][:before] << proc(7)
        hash[:to_s][:after] << proc(2)
        blocks, _ = subject.callbacks(:to_s)
        expect(blocks[:before]).to eql []
        expect(blocks[:after]).to eql [proc(5)]
        expect(subject.to_h[:to_s]).not_to eql(hash[:to_s])
      end
    end
  end

  describe '.import' do
    it 'raises if not passed a Runaround::Manager' do
      expect { subject.import("thing") }.to raise_error(
        Runaround::CallbackSetupError, /expected a Runaround::Manager/)
    end

    it "adds the other manager's callbacks to itself" do
      subject.around(:to_f){}
      other = described_class.new(receiver, apply: false)
      other.before(:to_f){}
      other.after(:to_f){}
      other.around(:to_f){}
      expect(fn_count[subject.to_h]).to eql 1
      subject.import(other)
      expect(fn_count[subject.to_h]).to eql 4
    end

    it "both receivers must respond to the imported methods" do
      subject.after(:round){}
      other = described_class.new("3.5")
      expect { other.import(subject) }.to raise_error(
        Runaround::CallbackSetupError, /receiver does not respond to :round/)
    end
  end

end
