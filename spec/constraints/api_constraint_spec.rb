require 'rails_helper'

describe ApiConstraint do
  describe '#matches' do
    context 'when less than version specified' do
      it 'does not match' do
        request = instance_double(ActionDispatch::Request, headers: { 'HTTP_ACCEPT' => 'version=1' })
        expect(described_class.new(version: 2).matches?(request)).to be false
      end
    end

    context 'when not specified' do
      it 'matches to 1' do
        request = instance_double(ActionDispatch::Request, headers: {})
        expect(described_class.new(version: 1).matches?(request)).to be true
      end
    end

    context 'when greater than version specified' do
      it 'matches to 1' do
        request = instance_double(ActionDispatch::Request, headers: { 'HTTP_ACCEPT' => 'version=2' })
        expect(described_class.new(version: 1).matches?(request)).to be true
      end
    end
  end
end
