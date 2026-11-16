# frozen_string_literal: true

module ToMods
  # Maps forms from cocina to MODS XML
  class Form # rubocop:disable Metrics/ClassLength
    PHYSICAL_DESCRIPTION_TAG = {
      'carrier' => :form,
      'digital origin' => :digitalOrigin,
      'extent' => :extent,
      'form' => :form,
      'material' => :form,
      'media' => :form,
      'media type' => :internetMediaType,
      'reformatting quality' => :reformattingQuality,
      'technique' => :form
    }.freeze

    # @params [Nokogiri::XML::Builder] xml
    # @params [Array<Hash>] forms
    # @params [IdGenerator] id_generator
    def self.write(xml:, forms:, id_generator:)
      new(xml: xml, forms: forms, id_generator: id_generator).write
    end

    def initialize(xml:, forms:, id_generator:)
      @xml = xml
      @forms = forms
      @id_generator = id_generator
    end

    def write
      other_forms = Array(forms).reject do |form|
        physical_description?(form) || manuscript?(form) || collection?(form)
      end
      is_manuscript = Array(forms).any? { |form| manuscript?(form) }
      is_collection = Array(forms).any? { |form| collection?(form) }

      if other_forms.present?
        write_other_forms(other_forms, is_manuscript, is_collection)
      else
        write_attributes_only(is_manuscript, is_collection)
      end

      write_physical_descriptions
    end

    private

    attr_reader :xml, :forms, :id_generator

    def physical_description?(form, type: nil)
      (Query.notes(form).present? && Query.type(form) != 'genre') ||
        PHYSICAL_DESCRIPTION_TAG.key?(type) ||
        PHYSICAL_DESCRIPTION_TAG.key?(Query.type(form)) ||
        PHYSICAL_DESCRIPTION_TAG.key?(Query.type(Query.grouped_values(form).first)) ||
        (Query.parallel?(form) && physical_description?(Query.parallel_values(form).first))
    end

    def manuscript?(form)
      Query.value(form) == 'manuscript' && resource_type(form).mods?
    end

    def collection?(form)
      Query.value(form) == 'collection' && resource_type(form).mods?
    end

    # CocinaDisplay's ResourceType knows the MODS and self-deposit resource type vocabularies.
    # It is built directly (rather than via Forms::Form.from_cocina) because the vocabulary
    # determines how a form is mapped, even when the form's type isn't "resource type".
    def resource_type(form)
      CocinaDisplay::Forms::ResourceType.new(form)
    end

    def write_other_forms(forms, is_manuscript, is_collection)
      forms.each do |form|
        if Query.parallel?(form)
          write_parallel_forms(form, is_manuscript, is_collection)
        else
          write_form(form, is_manuscript, is_collection)
        end
      end
    end

    def write_parallel_forms(form, is_manuscript, is_collection)
      alt_rep_group = id_generator.next_altrepgroup
      Query.parallel_values(form).each do |form_value|
        write_form(form_value, is_manuscript, is_collection, alt_rep_group: alt_rep_group)
      end
    end

    def write_form(form, is_manuscript, is_collection, alt_rep_group: nil)
      if Query.structured?(form)
        write_structured(form)
      elsif Query.value(form)
        write_basic(form, is_manuscript: is_manuscript, is_collection: is_collection,
                          alt_rep_group: alt_rep_group)
      end
    end

    def write_physical_descriptions
      parallel_physical_descr_forms, other_physical_descr_forms = Array(forms).select do |form|
                                                                    physical_description?(form)
                                                                  end.partition { |form| Query.parallel?(form) }
      write_physical_description(other_physical_descr_forms)

      parallel_physical_descr_forms.each do |parallel_physical_descr_form|
        alt_rep_group = id_generator.next_altrepgroup
        write_physical_description(Query.parallel_values(parallel_physical_descr_form), alt_rep_group: alt_rep_group,
                                                                                        display_label: Query.display_label(parallel_physical_descr_form),
                                                                                        form: parallel_physical_descr_form)
      end
    end

    def write_physical_description(physical_descr_forms, alt_rep_group: nil, display_label: nil, form: nil)
      grouped_forms = []
      # Each of these are its own physicalDescription
      simple_forms = []
      # These all get grouped together to form a single physicalDescription.
      other_forms = []
      other_notes = []
      Array(physical_descr_forms).select do |physical_descr_form|
        physical_description?(physical_descr_form, type: Query.type(form))
      end.each do |physical_descr_form|
        if Query.grouped?(physical_descr_form)
          grouped_forms << physical_descr_form
        elsif merge_form?(physical_descr_form, display_label) || alt_rep_group
          simple_forms << physical_descr_form
        else
          other_notes << physical_descr_form if Query.notes(physical_descr_form).present?
          other_forms << physical_descr_form if Query.value(physical_descr_form)
        end
      end

      if other_forms.present?
        write_basic_physical_description(other_forms, other_notes, alt_rep_group: alt_rep_group, form: form)
      else
        other_notes.each do |other_note|
          write_basic_physical_description([], [other_note], alt_rep_group: alt_rep_group, form: form)
        end
      end
      simple_forms.each do |simple_form|
        write_basic_physical_description([simple_form], [simple_form], alt_rep_group: alt_rep_group,
                                                                       form: form)
      end
      grouped_forms.each do |grouped_form|
        write_grouped_physical_description(grouped_form, alt_rep_group: alt_rep_group, form: form)
      end
    end

    def merge_form?(form, display_label)
      Query.value(form) && (Query.notes(form).any? do |note|
        Query.type(note) != 'unit'
      end || Query.display_label(form) || display_label)
    end

    def write_basic_physical_description(forms, note_forms, alt_rep_group: nil, form: nil)
      physical_description_attrs = {
        displayLabel: Query.display_label(forms.first) || Query.display_label(form),
        altRepGroup: alt_rep_group
      }.compact

      xml.physicalDescription physical_description_attrs do
        write_physical_description_form_values(forms, form: form)
        note_forms.each { |note_form| write_notes(note_form) if note_form.present? }
      end
    end

    def write_grouped_physical_description(grouped_form, alt_rep_group: nil, form: nil)
      physical_description_attrs = {
        displayLabel: Query.display_label(grouped_form) || Query.display_label(form),
        altRepGroup: alt_rep_group
      }.compact

      xml.physicalDescription physical_description_attrs do
        write_physical_description_form_values(Query.grouped_values(grouped_form), form: form)
        write_notes(grouped_form)
      end
    end

    def write_physical_description_form_values(form_values, form: nil)
      form_values.each do |form_value|
        form_type = Query.type(form_value) || Query.type(form)
        attributes = {
          unit: unit_for(form_value)
        }.tap do |attrs|
          attrs[:type] = form_type if PHYSICAL_DESCRIPTION_TAG.fetch(form_type) == :form && form_type != 'form'
        end.compact

        xml.public_send PHYSICAL_DESCRIPTION_TAG.fetch(form_type), Query.value(form_value),
                        attributes.merge(uri_attrs(form_value)).merge(uri_attrs(form))
      end
    end

    def write_notes(form)
      Query.notes(form).reject { |note| Query.type(note) == 'unit' }.each do |note|
        attributes = {
          displayLabel: Query.display_label(note),
          type: Query.type(note)
        }.compact
        xml.note Query.value(note), attributes
      end
    end

    def write_basic(form, is_manuscript: false, is_collection: false, alt_rep_group: nil)
      return write_datacite(form) if Query.source_value(form) == 'DataCite resource types'

      attributes = form_attributes(form, alt_rep_group)

      case Query.type(form)
      when 'resource type'
        attributes[:manuscript] = 'yes' if is_manuscript
        attributes[:collection] = 'yes' if is_collection
        xml.typeOfResource Query.value(form), attributes
      when 'map scale', 'map projection'
        # do nothing, these end up in subject/cartographics
      else # genre
        xml.genre Query.value(form), attributes.merge({ type: genre_type_for(form) }.compact)
      end
    end

    def write_datacite(form)
      xml.extension displayLabel: 'datacite' do
        xml.resourceType(datacite_resource_type, resourceTypeGeneral: Query.value(form))
      end
    end

    def datacite_resource_type
      self_deposit_types = forms.find do |candidate|
        # Why do we need to verify that the candidate's source is non-nil
        # here? Before this change, our datacite resource-type handling
        # could safely assume that the descriptive form metadata was
        # constrained to the H2/H3 shape. As of August 2025, we're minting
        # DOIs for ETDs which have their own descriptive form metadata
        # (now including datacite resource types), and this assumption no
        # longer holds. One of the ETD form values includes no source.
        resource_type(candidate).stanford_self_deposit?
      end
      return unless self_deposit_types

      parts = Query.structured_values(self_deposit_types).select do |val|
        Query.type(val) == 'subtype'
      end.presence || Query.structured_values(self_deposit_types)
      parts.pluck('value').join('; ')
    end

    def unit_for(form)
      Query.note_value_of_type(form, 'unit')
    end

    def genre_type_for(form)
      Query.note_value_of_type(form, 'genre type')
    end

    def form_attributes(form, alt_rep_group)
      {
        altRepGroup: alt_rep_group,
        displayLabel: Query.display_label(form),
        usage: Query.status(form),
        lang: Query.lang(form),
        script: Query.script(form)
      }.merge(uri_attrs(form)).compact
    end

    def write_attributes_only(is_manuscript, is_collection)
      return unless is_manuscript || is_collection

      attributes = {}
      attributes[:manuscript] = 'yes' if is_manuscript
      attributes[:collection] = 'yes' if is_collection
      xml.typeOfResource(nil, attributes)
    end

    def write_structured(form)
      # The only use case we're supporting for structured forms at the
      # moment is for H2. Short-circuit if that's not what we get.
      return unless resource_type(form).stanford_self_deposit?

      Query.structured_values(form).each do |genre|
        xml.genre Query.value(genre), type: "H2 #{Query.type(genre)}"
      end
    end

    def uri_attrs(form)
      return {} if form.nil?

      {
        valueURI: Query.uri(form),
        authorityURI: Query.authority_uri(form),
        authority: Query.authority(form)
      }.compact
    end
  end
end
