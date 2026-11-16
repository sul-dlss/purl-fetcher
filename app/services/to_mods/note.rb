# frozen_string_literal: true

module ToMods
  # Maps notes from cocina to MODS XML
  #
  # NOTE: CocinaDisplay::Notes::Note#abstract? is not used to choose the MODS element: it matches a
  # different set of display labels (e.g. it doesn't treat "Content advice", "Subject" or "Review"
  # as abstracts). Note#part? is not used either, because it considers the type of the main parallel
  # value rather than only the type of the note itself.
  class Note
    # notes with a displayLabel set to any of these values will produce an `abstract` XML node
    DISPLAY_LABEL_TO_ABSTRACT_TYPE = ['Content advice', 'Subject', 'Abstract', 'Review', 'Summary', 'Scope and content',
                                      'Scope and Content', 'Content Advice'].freeze

    # notes with these types will produce an `abstract` XML node
    NOTE_TYPE_TO_ABSTRACT_TYPE = ['summary', 'abstract', 'scope and content'].freeze

    # @params [Nokogiri::XML::Builder] xml
    # @params [Array<Hash>] notes
    # @params [IdGenerator] id_generator
    def self.write(xml:, notes:, id_generator:)
      new(xml: xml, notes: notes, id_generator: id_generator).write
    end

    def initialize(xml:, notes:, id_generator:)
      @xml = xml
      @notes = Array(notes).map { |note| CocinaDisplay::Notes::Note.new(note) }
      @id_generator = id_generator
    end

    def write
      notes.each do |note|
        if Query.type(note.cocina) == 'part'
          PartWriter.write(xml: xml, part_note: note.cocina)
        elsif Query.parallel?(note.cocina)
          write_parallel(note)
        else
          write_basic(note.cocina)
        end
      end
    end

    # @param [String] data
    # @param [Nokogiri::XML::Builder]
    def self.with_cdata(data, builder)
      tokens = data.split(%r{(</?(?:i|cite)>)})
      tokens.map do |token|
        if /\A<.+>\z/.match? token
          builder.cdata(token)
        else
          builder.text(token)
        end
      end
    end

    private

    attr_reader :xml, :notes, :id_generator

    def tag_name(note)
      type = Query.type(note)&.downcase
      return :abstract if DISPLAY_LABEL_TO_ABSTRACT_TYPE.include? Query.display_label(note)
      return :abstract if NOTE_TYPE_TO_ABSTRACT_TYPE.include? type

      case type
      when 'table of contents'
        :tableOfContents
      when 'target audience'
        :targetAudience
      else
        :note
      end
    end

    def tag(note, tag_name, attributes)
      type = Query.type(note)
      attributes[:type] = type if type && type != 'abstract' && %i[tableOfContents targetAudience].exclude?(tag_name)
      value = if Query.structured?(note)
                Query.structured_values(note).pluck('value').join(' -- ')
              else
                Query.value(note)
              end
      xml.public_send tag_name, attributes do |builder|
        Note.with_cdata(value, builder) if value
      end
    end

    def write_basic(note)
      tag(note, tag_name(note), note_attributes(note))
    end

    # @param [CocinaDisplay::Notes::Note] note
    def write_parallel(note)
      alt_rep_group = id_generator.next_altrepgroup
      note.parallel_values.each do |parallel_note|
        attributes = { altRepGroup: alt_rep_group }.merge(note_attributes(parallel_note.cocina))

        tag(parallel_note.cocina, tag_name(note.cocina), attributes)
      end
    end

    def note_attributes(note)
      {
        lang: Query.lang(note),
        script: Query.script(note),
        displayLabel: Query.display_label(note),
        authority: Query.authority(note),
        'xlink:href' => Query.value_at(note),
        ID: Query.value_of_type(Query.identifiers(note), 'anchor')
      }.compact
    end
  end
end
