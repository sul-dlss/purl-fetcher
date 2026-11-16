# frozen_string_literal: true

module ToMods
  # Maps events from cocina to MODS XML
  #
  # NOTE: CocinaDisplay::Events::Event#dates is not used: it drops dates it cannot parse and
  # flattens structured values into ranges, whereas MODS must reproduce every date as recorded.
  # LocationValue#to_s is not used either, because it decodes MARC country codes into names.
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
      @events = Array(events).map { |event| CocinaDisplay::Events::Event.new(event) }
      @id_generator = id_generator
    end

    def write
      events.each do |event|
        write_event(event)
      end
    end

    private

    attr_reader :xml, :events, :id_generator

    # @param [CocinaDisplay::Events::Event] event
    def write_event(event)
      dates = Query.search(event.cocina, '$.date[*]')
      names = event.contributors.map { |contributor| contributor.names.first&.cocina }
      return if dates.blank? && event.locations.blank? && names.blank? && event.notes.blank?

      attributes = {
        displayLabel: Query.display_label(event.cocina),
        eventType: event.type,
        script: Query.script(event.cocina),
        lang: Query.lang(event.cocina)
      }.compact

      xml.originInfo attributes do
        dates.each { |date| write_basic_date(date, event.type) }
        event.locations.each { |location| write_location(location.cocina) }
        names.each { |name| xml.publisher Query.value(name), name_attributes(name) if name }
        event.notes.each { |note| write_note(note.cocina) }
      end
    end

    def write_note(note)
      if Query.parallel?(note)
        Query.parallel_values(note).each do |parallel_note|
          write_note(parallel_note)
        end
      else
        attributes = { authority: Query.authority(note) }.compact
        xml.send(note_tag_for(note), Query.value(note), attributes)
      end
    end

    def note_tag_for(note)
      type = Query.type(note)
      return 'copyrightDate' if type == 'copyright statement'
      return type if type

      'edition'
    end

    def write_location(location)
      place_attrs = {}.tap do |attrs|
        attrs[:supplied] = 'yes' if Query.type(location) == 'supplied'
      end
      xml.place place_attrs do
        placeterm_attrs = {
          authority: Query.authority(location),
          authorityURI: Query.authority_uri(location),
          valueURI: Query.uri(location)
        }.compact

        value = Query.value(location)
        xml.placeTerm value, placeterm_attrs.merge({ type: 'text' }) if value

        code = Query.code(location)
        xml.placeTerm code, placeterm_attrs.merge({ type: 'code' }) if code
      end
    end

    def write_basic_date(date, cocina_event_type)
      if Query.structured?(date)
        date_type = Query.type(date)
        structured_val_attribs = {
          encoding: Query.encoding(date),
          qualifier: Query.qualifier(date),
          type: date_type
        }
        date_type = cocina_event_type if date_type.blank?
        Query.structured_values(date).each do |structured_date|
          write_date_element(structured_date, date_type, structured_val_attribs)
        end
      else
        write_date_element(date, cocina_event_type)
      end
    end

    # @param [Hash] structured_val_attribs - populated when structuredValue parent has attributes for individual date elements
    def write_date_element(date, cocina_event_type, structured_val_attribs = {})
      date_type = Query.type(date)
      element_name = date_element_name(date_type, cocina_event_type, structured_val_attribs[:type])
      attributes = {}.tap do |attrs|
        attrs[:encoding] = Query.encoding_code(date) || Query.code(structured_val_attribs[:encoding])
        attrs[:qualifier] = Query.qualifier(date) || structured_val_attribs[:qualifier]
        attrs[:keyDate] = 'yes' if Query.status(date) == 'primary'
        attrs[:type] = date_type_attr(date_type, element_name)
        attrs[:calendar] = Query.note_value_of_type(date, 'calendar')
        attrs[:point] = date_type if %w[start end].include?(date_type)
      end.compact
      xml.public_send(element_name, Query.value(date), attributes)
    end

    def date_element_name(date_type, cocina_event_type, structured_val_type)
      el_name = DATE_ELEMENT_FOR_TYPE.fetch(structured_val_type, nil)
      return el_name if el_name.present?

      el_name = DATE_ELEMENT_FOR_TYPE.fetch(date_type, nil)
      return el_name if el_name.present?

      # the date type overrides the eventType for choosing date flavor, even if it ends up with dateOther
      return 'dateOther' if date_type.present?

      if cocina_event_type.present?
        el_name = DATE_ELEMENT_FOR_TYPE.fetch(cocina_event_type, nil)
        return el_name if el_name.present?
      end

      'dateOther'
    end

    # MODS only allows a type attr on dateOther; no other date flavors
    def date_type_attr(date_type, date_element_name)
      return unless date_element_name == 'dateOther'

      date_type if date_type.present? && %w[start end].exclude?(date_type)
    end

    def name_attributes(cocina_name)
      {
        lang: Query.lang(cocina_name),
        script: Query.script(cocina_name),
        transliteration: Query.standard_value(cocina_name)
      }.compact
    end
  end
end
