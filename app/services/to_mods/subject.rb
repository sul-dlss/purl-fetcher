# frozen_string_literal: true

module ToMods
  # Maps subjects from cocina to MODS XML
  # rubocop:disable Metrics/ClassLength
  class Subject
    TAG_NAME = {
      'time' => :temporal,
      'genre' => :genre,
      'occupation' => :occupation
    }.freeze
    DEORDINAL_REGEX = /(?<=[0-9])(?:st|nd|rd|th)/

    # @params [Nokogiri::XML::Builder] xml
    # @params [Array<Hash>] subjects
    # @params [Array<Hash>] forms
    # @params [IdGenerator] id_generator
    def self.write(xml:, subjects:, id_generator:, forms: [])
      new(xml: xml, subjects: subjects, forms: forms, id_generator: id_generator).write
    end

    def initialize(xml:, subjects:, forms:, id_generator:)
      @xml = xml
      @subjects = Array(subjects)
      @forms = forms || []
      @id_generator = id_generator
    end

    def write
      subjects.each do |subject|
        next if Query.type(subject) == 'map coordinates'

        parallel_subject_values = Query.parallel_values(subject)
        subject_value = subject
        type = nil

        # Make adjustments for a parallel person.
        if parallel_subject_values.present? && NameWriter::NAME_TYPE.key?(Query.type(subject))
          display_values, parallel_subject_values = partition_display_values(subject)
          if parallel_subject_values.size == 1
            subject_value = parallel_subject_values.first
            parallel_subject_values = []
            type = Query.type(subject)
          end
        end

        if parallel_subject_values.size > 1
          write_parallel(subject, parallel_subject_values, alt_rep_group: id_generator.next_altrepgroup,
                                                           display_values: display_values)
        else
          write_subject(subject, subject_value, display_values: display_values, type: type)
        end
      end
      write_cartographic
    end

    private

    attr_reader :xml, :subjects, :forms, :id_generator

    def write_subject(subject, subject_value, alt_rep_group: nil, type: nil, display_values: nil)
      if Query.structured?(subject_value) || Query.grouped?(subject_value)
        write_structured_or_grouped(subject, subject_value, alt_rep_group: alt_rep_group, type: type,
                                                            display_values: display_values)
      else
        write_basic(subject, subject_value, alt_rep_group: alt_rep_group, type: type,
                                            display_values: display_values)
      end
    end

    def write_parallel(subject, subject_values, alt_rep_group:, display_values: nil)
      # A geographic and geographicCode get written as a single subject.
      if geographic_and_geographic_code?(subject, subject_values)
        xml.subject do
          subject_values.each do |geo|
            geographic(subject, geo, is_parallel: true)
          end
        end
      else
        subject_values.each do |subject_value|
          write_subject(subject, subject_value, alt_rep_group: alt_rep_group, type: Query.type(subject),
                                                display_values: display_values)
        end
      end
    end

    def geographic_and_geographic_code?(subject, subject_values)
      Query.type(subject) == 'place' &&
        subject_values.one? { |value| Query.value(value) } &&
        subject_values.one? { |value| Query.code(value) }
    end

    # rubocop:disable Metrics/CyclomaticComplexity
    def write_structured_or_grouped(subject, subject_value, alt_rep_group: nil, type: nil, display_values: nil)
      type ||= Query.type(subject_value) || Query.type(subject)
      xml.subject(structured_attributes_for(subject_value, type, alt_rep_group: alt_rep_group)) do
        if type == 'place' && Query.structured?(subject_value)
          hierarchical_geographic(subject_value)
        elsif type == 'time'
          time_range(subject_value)
        elsif type == 'title'
          write_title(subject_value)
        elsif NameWriter::NAME_TYPE.key?(type)
          write_structured_person(subject, subject_value, type: type, display_values: display_values)
        else
          values = Query.structured_values(subject_value).presence || Query.grouped_values(subject_value)
          Array(values).each do |value|
            if NameWriter::NAME_TYPE.key?(Query.type(value))
              if Query.structured?(value)
                write_structured_person(subject, value, display_values: display_values)
              elsif Query.parallel?(value)
                write_parallel_structured_person(value)
              else
                write_person(subject, value, display_values: display_values)
              end
            else
              write_topic(subject, value, is_parallel: alt_rep_group.present?, type: type,
                                          subject_values_have_same_authority: all_values_have_same_authority?(values))
            end
          end
        end
      end
    end
    # rubocop:enable Metrics/CyclomaticComplexity

    def write_title(subject_value)
      title = subject_value.except('type', 'source', 'valueLanguage')
      Title.write(xml: xml, titles: [title], id_generator: id_generator)
    end

    def structured_attributes_for(subject_value, type, alt_rep_group: nil)
      values = Query.structured_values(subject_value).presence || Query.grouped_values(subject_value)
      {
        altRepGroup: alt_rep_group,
        displayLabel: Query.display_label(subject_value),
        lang: Query.lang(subject_value),
        script: Query.script(subject_value)
      }.tap do |attrs|
        if type == 'person'
          attrs[:authority] = authority_for(subject_value) # unless Query.authority(subject) == 'naf' && Query.authority(subject_value) == 'naf'
        else
          attrs[:valueURI] = Query.uri(subject_value)
          if Query.source(subject_value)
            # If all values in structuredValue have uri, then authority only.
            attrs[:authority] = authority_for(subject_value)
            if !all_values_have_uri?(values) || Query.uri(subject_value)
              attrs[:authorityURI] =
                Query.authority_uri(subject_value)
            end
          elsif all_values_have_lcsh_authority?(values)
            # No source, but all values in structuredValue are lcsh or naf then add authority
            attrs[:authority] = 'lcsh'
          elsif Query.type(subject_value) == 'place' && all_values_have_same_authority?(values)
            attrs[:authority] = authority_for(values.first)
          end
        end
      end.compact
    end

    def all_values_have_uri?(values)
      values.present? && Array(values).all? { |value| Query.uri(value) }
    end

    def all_values_have_lcsh_authority?(values)
      values.present? && Array(values).all? { |value| authority_for(value) == 'lcsh' }
    end

    def all_values_have_same_authority?(values)
      return false if values.blank?

      check_authority = authority_for(values.first)
      return false if check_authority.nil?

      values.all? { |value| authority_for(value) == check_authority }
    end

    def write_basic(subject, subject_value, alt_rep_group: nil, type: nil, display_values: nil)
      subject_attributes = subject_attributes_for(subject_value, alt_rep_group)
      type ||= Query.type(subject_value)

      if type == 'classification'
        write_classification(Query.value(subject_value), subject_attributes)
      elsif NameWriter::NAME_TYPE.key?(type) || type == 'name'
        xml.subject(subject_attributes) do
          write_person(subject, subject_value, display_values: display_values)
        end
      elsif !type && !Query.value(subject_value)
        # For subject only (no children).
        xml.subject subject_attributes.merge(topic_attributes_for(subject, subject_value, type))
      else
        xml.subject(subject_attributes) do
          write_topic(subject, subject_value, type: type)
        end
      end
    end

    def subject_attributes_for(subject, alt_rep_group)
      {
        altRepGroup: alt_rep_group,
        authority: authority_for(subject),
        lang: Query.lang(subject),
        script: Query.script(subject),
        usage: Query.status(subject)
      }.tap do |attrs|
        attrs[:displayLabel] = Query.display_label(subject) unless Query.type(subject) == 'genre'
        attrs[:edition] = edition(Query.source_version(subject)) if Query.source_version(subject)
        attrs['xlink:href'] = Query.value_at(subject)
      end.compact
    end

    def authority_for(subject)
      # Both lcsh and naf map to lcsh for the subject.
      return 'lcsh' if %w[lcsh naf].include?(Query.authority(subject))

      Query.authority(subject)
    end

    def write_classification(value, attrs)
      xml.classification value, attrs
    end

    # Write nodes within MODS subject
    def write_topic(subject, subject_value, is_parallel: false, type: nil, subject_values_have_same_authority: true)
      type ||= Query.type(subject_value)
      topic_attributes = topic_attributes_for(subject,
                                              subject_value,
                                              type,
                                              is_parallel: is_parallel,
                                              subject_values_have_same_authority: subject_values_have_same_authority)
      case type
      when 'person'
        xml.name topic_attributes.merge(type: 'personal') do
          xml.namePart(Query.value(subject_value)) if Query.value(subject_value)
        end
      when 'name'
        xml.name topic_attributes do
          xml.namePart(Query.value(subject_value)) if Query.value(subject_value)
        end
      when 'title'
        title = subject_value.except('type', 'valueLanguage')
        title['source'] = Query.source(title).except('code') if Query.authority(subject_value) && !topic_attributes[:authority]
        Title.write(xml: xml, titles: [title],
                    id_generator: id_generator, additional_attrs: topic_attributes)
      when 'place'
        geographic(subject, subject_value, is_parallel: is_parallel)
      else
        xml.public_send(TAG_NAME.fetch(Query.type(subject_value), :topic), Query.value(subject_value), topic_attributes)
      end
    end

    def topic_attributes_for(subject, subject_value, type, is_parallel: false, subject_values_have_same_authority: true)
      {
        authority: authority_for_topic(subject, subject_value, type, is_parallel,
                                       subject_values_have_same_authority),
        authorityURI: Query.authority_uri(subject_value),
        encoding: Query.encoding_code(subject_value),
        valueURI: Query.uri(subject_value)
      }.tap do |topic_attributes|
        if Query.type(subject_value) == 'genre'
          topic_attributes[:displayLabel] = Query.display_label(subject_value)
          topic_attributes[:usage] = Query.status(subject_value)
        end
      end.compact
    end

    # rubocop:disable Metrics/CyclomaticComplexity
    def authority_for_topic(subject, subject_value, type, is_parallel, subject_values_have_same_authority)
      return nil unless Query.authority_uri(subject_value) ||
                        Query.uri(subject_value) ||
                        (type == 'place' && is_parallel) ||
                        (Query.authority(subject_value) && Query.authority(subject) && Query.authority(subject) != Query.authority(subject_value)) ||
                        (Query.authority(subject) == 'naf' && Query.authority(subject_value) == 'naf' && type == 'person') ||
                        (Query.authority(subject_value) && !subject_values_have_same_authority)

      Query.authority(subject_value)
    end

    # rubocop:enable Metrics/CyclomaticComplexity
    def geographic(subject, subject_value, is_parallel: false)
      if Query.code(subject_value)
        xml.geographicCode Query.code(subject_value),
                           topic_attributes_for(subject, subject_value, 'place', is_parallel: is_parallel)
      else
        xml.geographic Query.value(subject_value),
                       topic_attributes_for(subject, subject_value, 'place', is_parallel: is_parallel)
      end
    end

    def time_range(subject)
      Query.structured_values(subject).each do |point|
        xml.temporal Query.value(point), point: Query.type(point), encoding: Query.encoding_code(subject)
      end
    end

    def write_cartographic
      parallel_forms, other_forms = forms.partition { |form| Query.parallel?(form) }

      parallel_forms.each do |parallel_form|
        alt_rep_group = id_generator.next_altrepgroup
        Query.parallel_values(parallel_form).each do |form|
          write_parallel_cartographic_without_authority([form], alt_rep_group: alt_rep_group)
          write_cartographic_with_authority([form], alt_rep_group: alt_rep_group)
        end
      end

      write_cartographic_without_authority(other_forms)
      write_cartographic_with_authority(other_forms)
    end

    # rubocop:disable Metrics/CyclomaticComplexity
    def write_cartographic_without_authority(forms)
      # With all subject/forms without authorities.
      scale_forms = forms.select do |form|
                      Query.type(form) == 'map scale'
                    end.flat_map { |form| Query.grouped_values(form).presence || form }
      projection_forms = forms.select { |form| Query.type(form) == 'map projection' && Query.source(form).nil? }
      carto_subjects = subjects.select { |subject| Query.type(subject) == 'map coordinates' }
      return unless scale_forms.present? || projection_forms.present? || carto_subjects.present?

      xml.subject do
        xml.cartographics do
          scale_forms.each { |scale_form| xml.scale Query.value(scale_form) }
          projection_forms.each { |projection_form| xml.projection Query.value(projection_form) }
          carto_subjects.each { |carto_subject| xml.coordinates Query.value(carto_subject) }
        end
      end
    end
    # rubocop:enable Metrics/CyclomaticComplexity

    def write_parallel_cartographic_without_authority(forms, alt_rep_group:)
      # With all subject/forms without authorities.
      scale_forms = forms.select do |form|
                      Query.type(form) == 'map scale'
                    end.flat_map { |form| Query.grouped_values(form).presence || form }
      projection_forms = forms.select { |form| Query.type(form) == 'map projection' && Query.source(form).nil? }
      return unless scale_forms.present? || projection_forms.present?

      subject_attrs = { altRepGroup: alt_rep_group }
      xml.subject subject_attrs do
        xml.cartographics do
          scale_forms.each { |scale_form| xml.scale Query.value(scale_form) }
          projection_forms.each { |projection_form| xml.projection Query.value(projection_form) }
        end
      end
    end

    def write_cartographic_with_authority(forms, alt_rep_group: nil)
      # Each for form with authority.
      projection_forms_with_authority = forms.select do |form|
        Query.type(form) == 'map projection' && Query.source(form).present?
      end
      projection_forms_with_authority.each do |projection_form|
        xml.subject carto_subject_attributes_for(projection_form, alt_rep_group: alt_rep_group) do
          xml.cartographics do
            xml.projection Query.value(projection_form)
          end
        end
      end
    end

    def carto_subject_attributes_for(form, alt_rep_group: nil)
      {
        displayLabel: Query.display_label(form),
        authority: Query.authority(form),
        authorityURI: Query.authority_uri(form),
        valueURI: Query.uri(form),
        altRepGroup: alt_rep_group
      }.compact
    end

    def hierarchical_geographic(subject)
      xml.hierarchicalGeographic do
        Query.structured_values(subject).each do |structured_value|
          xml.send(camelize(Query.type(structured_value)), Query.value(structured_value))
        end
      end
    end

    def camelize(str)
      str.tr(' ', '_').camelize(:lower)
    end

    def write_person(subject, subject_value, display_values: nil)
      name_attrs = topic_attributes_for(subject, subject_value, 'person').tap do |attrs|
        attrs[:type] = name_type_for(Query.type(subject) || Query.type(subject_value))
      end.compact
      xml.name name_attrs do
        write_name_part(subject_value)
        write_display_form(display_values)
        write_roles(Query.notes(subject_value))
        write_identifier(Query.identifiers(subject))
        write_other_notes(Query.notes(subject), 'description')
        write_other_notes(Query.notes(subject), 'affiliation')
      end
    end

    def write_structured_person(subject, subject_value, type: nil, display_values: nil)
      type ||= Query.type(subject_value)
      name_attrs = topic_attributes_for(subject, subject_value, type).tap do |attrs|
        attrs[:type] = name_type_for(type)
      end.compact
      xml.name name_attrs do
        write_name_parts(subject_value)
        write_display_form(display_values)
        write_roles(Query.notes(subject))
        write_other_notes(Query.notes(subject), 'description')
        write_other_notes(Query.notes(subject_value), 'affiliation')
      end
      write_genres(subject_value)
    end

    def write_display_form(display_values)
      Array(display_values).each do |display_value|
        xml.displayForm Query.value(display_value)
      end
    end

    def write_roles(notes)
      Array(notes).filter do |note|
        Query.type(note) == 'role'
      end.each { |role| RoleWriter.write(xml: xml, role: role) }
    end

    def write_identifier(identifiers)
      Array(identifiers).each do |identifier|
        xml.nameIdentifier Query.value(identifier), type: Query.authority(identifier)
      end
    end

    def write_other_notes(notes, type)
      Array(notes).filter { |note| Query.type(note) == type }.each { |note| xml.public_send(type, Query.value(note)) }
    end

    def write_name_parts(descriptive_value)
      Query.structured_values(descriptive_value)
           .reject { |value| Query.type(value) == 'genre' }
           .each { |value| write_name_part(value) }
    end

    def write_genres(descriptive_value)
      Query.structured_values(descriptive_value)
           .select { |value| Query.type(value) == 'genre' }
           .each { |genre| xml.genre Query.value(genre) }
    end

    def write_name_part(name_part)
      return unless Query.value(name_part)

      attributes = {}.tap do |attrs|
        attrs[:type] = NameWriter::NAME_PART[Query.type(name_part)]
      end.compact
      xml.namePart Query.value(name_part), attributes
      write_other_notes(Query.notes(name_part), 'affiliation')
    end

    def name_type_for(type)
      NameWriter::NAME_TYPE[type]
    end

    def edition(version)
      version.split.first.gsub(DEORDINAL_REGEX, '')
    end

    # CocinaDisplay identifies which parallel values have the "display" role.
    # @return [Array(Array<Hash>, Array<Hash>)] the display values and the other parallel values
    def partition_display_values(subject)
      CocinaDisplay::Subjects::Subject.new(subject).parallel_values
                                      .partition(&:display?)
                                      .map { |values| values.map(&:cocina) }
    end

    def write_parallel_structured_person(value)
      display_values, parallel_subject_values = partition_display_values(value)

      # there will not be more than one parallelValue within a structuredValue
      parallel_subject_value = parallel_subject_values.first
      if Query.structured?(parallel_subject_value)
        write_structured_person(value, parallel_subject_value, type: Query.type(value),
                                                               display_values: display_values)
      else
        write_person(value, parallel_subject_value, display_values: display_values)
      end
    end
  end
  # rubocop:enable Metrics/ClassLength
end
