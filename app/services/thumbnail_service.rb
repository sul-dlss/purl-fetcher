# frozen_string_literal: true

# Responsible for finding a path to a thumbnail based on the contentMetadata of an object
class ThumbnailService
  # allow the mimetype attribute to be lower or camelcase when searching to make it more robust
  MIME_TYPE = 'image/jp2'

  # @param [Cocina::Models::DRO, Hash] object
  def initialize(object)
    data_hash = object.is_a?(Hash) ? object : object.to_h.deep_stringify_keys
    @record = CocinaDisplay::CocinaRecord.new(data_hash)
  end

  attr_reader :record

  # @return [String] the computed thumb filename, with the druid prefix and a slash in front of it, e.g. oo000oo0001/filenamewith space.jp2
  def thumb
    record.filesets.each do |file_set|
      file_set.files.each do |file|
        next unless file.mime_type == MIME_TYPE

        return "#{record.bare_druid}/#{file.filename}"
      end
    end

    first_member = record.cocina_doc.dig('structural', 'hasMemberOrders', 0, 'members', 0)
    return if first_member.blank?

    self.class.new(CocinaObjectStore.find(first_member)).thumb
  end
end
