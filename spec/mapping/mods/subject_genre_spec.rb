# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'MODS subject topic <--> cocina mappings' do
  describe 'Subject with only genre subelement' do
    it_behaves_like 'MODS cocina mapping' do
      let(:mods) do
        <<~XML
          <subject>
            <genre>Melodrama</genre>
          </subject>
        XML
      end

      let(:cocina) do
        {
          subject: [
            {
              value: 'Melodrama',
              type: 'genre'
            }
          ]
        }
      end
    end
  end

  describe 'Genre subject with display label on subelement' do
    it_behaves_like 'MODS cocina mapping' do
      let(:mods) do
        <<~XML
          <subject>
            <genre displayLabel="Drama type">Melodrama</genre>
          </subject>
        XML
      end

      let(:cocina) do
        {
          subject: [
            {
              value: 'Melodrama',
              type: 'genre',
              displayLabel: 'Drama type'
            }
          ]
        }
      end
    end
  end

  describe 'Genre subject with type' do
    xit 'not implemented: genre subject with type' do
      let(:mods) do
        <<~XML
          <subject>
            <genre type="style">Art Deco</genre>
          </subject>
        XML
      end

      let(:cocina) do
        {
          subject: [
            {
              value: 'Art Deco',
              type: 'genre',
              note: [
                {
                  value: 'style',
                  type: 'genre type'
                }
              ]
            }
          ]
        }
      end
    end
  end
end
