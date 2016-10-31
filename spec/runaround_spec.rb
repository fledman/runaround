require 'spec_helper'

describe Runaround do
  it 'has a version number' do
    expect(Runaround::VERSION).not_to be nil
  end

  context 'when included' do
    let(:klass) { Class.new(Object).include(described_class) }

    it 'exposes the Runaround::Manager' do
      expect(klass.new.runaround).to be_a Runaround::Manager
    end
  end

  context 'when extended' do
    let(:klass) { Class.new(Object).extend(described_class) }

    it 'exposes the Runaround::Manager' do
      expect(klass.runaround).to be_a Runaround::Manager
    end
  end
end
