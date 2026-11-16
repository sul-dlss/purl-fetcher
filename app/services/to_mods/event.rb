# frozen_string_literal: true

module ToMods
  # Maps events from cocina to MODS XML
  class Event
    # cocina date type => MODS originInfo date element
    DATE_ELEMENT_FOR_TYPE = {
      'copyright' => 'copyrightDate',
      'capture' => 'dateCaptured',
      'creation' => 'dateCreated',
      'publication' => 'dateIssued',
      'modification' => 'dateModified',
      '' => 'dateOther', # cocina type is set differently for dateOther
      'validity' => 'dateValid'
    }.freeze

    # @params [Nokogiri::XML::Builder] xml
    # @params [Array<Hash>] events
    # @params [IdGenerator] id_generator
    def self.write(xml:, events:, id_generator:)
      new(xml: xml, events: events, id_generator: id_generator).write
    end

    def initialize(xml:, events:, id_generator:)
      @xml = xml
      @events = events
      @id_generator = id_generator
    end

    def write
      Array(events).each do |event|
        write_basic(event, event['type'])
      end
    end

    private

    attr_reader :xml, :events, :id_generator

    def write_basic(event, event_type)
      names = Array(event['contributor']).map { |contributor| Array(contributor['name']).first }
      attributes = {
        displayLabel: event['displayLabel'],
        eventType: event_type,
        script: event.dig('valueLanguage', 'valueScript', 'code'),
        lang: event.dig('valueLanguage', 'code')
      }.compact

      write_event(event['type'], event['date'], event['location'], names, event['note'], attributes)
    end

    # rubocop:disable Metrics/ParameterLists
    def write_event(cocina_event_type, dates, locations, names, notes, attributes)
      return if dates.blank? && locations.blank? && names.blank? && notes.blank?

      xml.originInfo attributes do
        Array(dates).each do |date|
          write_basic_date(date, cocina_event_type)
        end
        Array(locations).each do |loc|
          write_location(loc)
        end
        Array(names).each do |name|
          xml.publisher name['value'], name_attributes(name) if name
        end
        Array(notes).each do |note|
          write_note(note)
        end
      end
    end
    # rubocop:enable Metrics/ParameterLists

    def write_note(note)
      if note['parallelValue'].present?
        note['parallelValue'].each do |parallel_note|
          write_note(parallel_note)
        end
      else
        attributes = {}
        attributes[:authority] = note.dig('source', 'code') if note.dig('source', 'code')
        xml.send(note_tag_for(note), note['value'], attributes)
      end
    end

    def note_tag_for(note)
      return 'copyrightDate' if note['type'] == 'copyright statement'
      return note['type'] if note['type']

      'edition'
    end

    def write_location(location)
      place_attrs = {}.tap do |attrs|
        attrs[:supplied] = 'yes' if location['type'] == 'supplied'
      end
      xml.place place_attrs do
        placeterm_attrs = {}
        placeterm_attrs[:authority] = location.dig('source', 'code') if location.dig('source', 'code')
        placeterm_attrs[:authorityURI] = location.dig('source', 'uri') if location.dig('source', 'uri')
        placeterm_attrs[:valueURI] = location['uri'] if location['uri']

        placeterm_text_attrs = placeterm_attrs.merge({ type: 'text' })
        xml.placeTerm location['value'], placeterm_text_attrs if location['value']

        placeterm_code_attrs = placeterm_attrs.merge({ type: 'code' })
        xml.placeTerm location['code'], placeterm_code_attrs if location['code']
      end
    end

    def write_basic_date(date, cocina_event_type)
      if date['structuredValue'].present?
        structured_val_attribs = {
          encoding: date['encoding'],
          qualifier: date['qualifier'],
          type: date['type']
        }
        date_type = cocina_event_type
        date_type = date['type'] if date['type'].present?
        date_range(date['structuredValue'], date_type, structured_val_attribs)
      else
        write_date_element(date, cocina_event_type)
      end
    end

    # @param [Hash] structured_val_attribs - populated when structuredValue parent has attributes for individual date elements
    def write_date_element(date, cocina_event_type, structured_val_attribs = {})
      value = date['value']
      element_name = date_element_name(date, cocina_event_type, structured_val_attribs[:type])
      attributes = {}.tap do |attrs|
        attrs[:encoding] = date.dig('encoding', 'code') || structured_val_attribs[:encoding]&.dig('code')
        attrs[:qualifier] = date['qualifier'] || structured_val_attribs[:qualifier]
        attrs[:keyDate] = 'yes' if date['status'] == 'primary'
        attrs[:type] = date_type_attr(date, element_name)
        attrs[:calendar] = calendar_attr(date)
        attrs[:point] = date['type'] if %w[start end].include?(date['type'])
      end.compact
      xml.public_send(element_name, value, attributes)
    end

    def date_element_name(date, cocina_event_type, structured_val_type)
      el_name = DATE_ELEMENT_FOR_TYPE.fetch(structured_val_type, nil)
      return el_name if el_name.present?

      el_name = DATE_ELEMENT_FOR_TYPE.fetch(date['type'], nil)
      return el_name if el_name.present?

      # the date type overrides the eventType for choosing date flavor, even if it ends up with dateOther
      return 'dateOther' if date['type'].present?

      if cocina_event_type.present?
        el_name = DATE_ELEMENT_FOR_TYPE.fetch(cocina_event_type, nil)
        return el_name if el_name.present?
      end

      'dateOther'
    end

    # MODS only allows a type attr on dateOther; no other date flavors
    def date_type_attr(cocina_date, date_element_name)
      return unless date_element_name == 'dateOther'

      cocina_date['type'] if cocina_date['type'].present? && %w[start end].exclude?(cocina_date['type'])
    end

    def calendar_attr(cocina_date)
      return if cocina_date['note'].blank?

      cocina_date['note'].each do |note|
        return note['value'] if note['type'] == 'calendar'
      end
    end

    def date_range(dates, cocina_event_type, structured_val_attribs)
      dates.each do |date|
        write_date_element(date, cocina_event_type, structured_val_attribs)
      end
    end

    def name_attributes(cocina_name)
      {
        lang: cocina_name&.dig('valueLanguage', 'code'),
        script: cocina_name&.dig('valueLanguage', 'valueScript', 'code'),
        transliteration: cocina_name&.dig('standard', 'value')
      }.compact
    end
  end
end
