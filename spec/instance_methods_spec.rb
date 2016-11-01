require 'spec_helper'

describe Runaround::InstanceMethods do

  let(:klass) do
    Class.new(Object) do
      def work; 'RESULT'; end
    end
  end

  context 'when included' do
    it 'raises an error' do
      expect { klass.include(described_class)
             }.to raise_error(RuntimeError, /extended, not included/)
    end
  end

  context 'when extended' do
    before { klass.extend(described_class) }

    it 'includes Runaround into the class' do
      expect(klass.ancestors).to include(::Runaround)
      expect(klass.method_defined?(:runaround)).to eql true
    end

    it 'extends Runaround into the class' do
      expect(klass.singleton_class.ancestors).to include(::Runaround)
      expect(klass).to respond_to :runaround
    end

    it 'sets up an after(:new) callback' do
      callbacks = klass.runaround.to_h
      expect(callbacks.keys).to eql [:new]
      expect(callbacks[:new][:before]).to eql []
      expect(callbacks[:new][:around]).to eql []
      expect(callbacks[:new][:after].size).to eql 1
    end

    describe '.runaround_instance_methods' do
      subject { klass.runaround_instance_methods }

      it 'exposes the Runaround::Manager' do
        expect(subject).to be_a Runaround::Manager
      end

      it 'creates the Runaround::Manager with apply: false' do
        expect(subject.apply).to eql false
      end
    end

    describe '.irunaround' do
      let(:retval) { instance_double(Runaround::Manager) }

      before do
        expect(klass).to receive(:runaround_instance_methods).and_return(retval)
      end

      it 'is a shortcut for runaround_instance_methods' do
        expect(klass.irunaround).to equal retval
      end

      it 'will yield the Runaround::Manager if passed a block' do
        ran_block = false
        klass.irunaround do |manager|
          expect(manager).to equal retval
          ran_block = true
        end
        expect(ran_block).to eql true
      end
    end

    context 'when an instance is instantiated' do
      let(:instance) { klass.new }

      let(:markers) do
        Hash.new{ |h1,m| h1[m] = Hash.new{ |h2,t| h2[t] = 0 } }
      end

      before do
        klass.irunaround.before(:to_s){ |mc| markers[mc.method][:before] += 1 }
        klass.irunaround.after( :to_s){ |mc| markers[mc.method][:after]  += 1 }
        klass.irunaround.around(:work) do |mc|
          markers[mc.method][:around] += 1
          mc.run_method
          markers[mc.method][:around] += 1
        end
      end

      it 'imports the instance-level callbacks' do
        expect(markers).to eql({})
        instance.to_s
        expect(markers).to eql({ to_s: {before: 1, after: 1} })
        4.times{ instance.to_s }
        expect(markers).to eql({ to_s: {before: 5, after: 5} })
        instance.work
        expect(markers).to eql({ to_s: {before: 5, after: 5},
                                 work: { around: 2 } })
      end
    end
  end

end
