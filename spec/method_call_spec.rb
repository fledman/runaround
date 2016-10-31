require 'spec_helper'

describe Runaround::MethodCall do

  context 'struct members' do
    subject { described_class.new }

    it { is_expected.to respond_to :method }
    it { is_expected.to respond_to :args }
    it { is_expected.to respond_to :opts }
    it { is_expected.to respond_to :block }
    it { is_expected.to respond_to :return_value }

    it 'are in the correct order' do
      expect(subject.members).to eql [
        :method, :args, :opts, :block, :return_value]
    end
  end

  describe '.argsopts' do
    let(:mc) { described_class.new }

    it 'appends the opts to the args when both exist' do
      mc.args = [1,2,3]
      mc.opts = { a: 'a', b: 'b' }
      expect(mc.argsopts).to eql [1,2,3,{a: 'a', b: 'b'}]
    end

    it 'creates a new array when the args are nil' do
      mc.opts = { a: 'a', b: 'b' }
      expect(mc.argsopts).to eql [{a: 'a', b: 'b'}]
    end

    it 'does not add the opts when nil' do
      mc.args = [:foo]
      expect(mc.argsopts).to eql [:foo]
    end

    it 'does not add the opts when empty' do
      mc.args = [:foo]
      mc.opts = {}
      expect(mc.argsopts).to eql [:foo]
    end

    it 'does not share the same array as the input args' do
      mc.args = ['a']
      result = mc.argsopts
      mc.args << 'b'
      expect(mc.args).to eql ['a', 'b']
      expect(result).to eql ['a']
    end

    it 'does share the same opts hash' do
      mc.opts = { a: 1 }
      result = mc.argsopts
      mc.opts[:b] = 2
      expect(mc.opts).to eql({ a: 1, b: 2 })
      expect(result).to eql([{ a: 1, b: 2 }])
    end
  end

  describe '.run_method' do
    let(:mc) { described_class.new }

    it 'calls out to Fiber.yield' do
      expect(Fiber).to receive(:yield)
      mc.run_method
    end
  end

end
