# frozen_string_literal: true

module Cocina
  module ToXml
    module Rights
      # Builds the rightsMetadata xml from cocina for a file
      class FileLevel
        # @param [Nokogiri::XML::Element] root Element that is the root of the access assertions.
        # @param [Cocina::Models::DROAccess, Cocina::Models::Access] access access/rights metadata in Cocina
        # @param [Cocina::Models::DROStructural] structural structural metadata in Cocina
        # @return [Array<Nokogiri::XML::Element>]
        def self.generate(root:, access:, structural:)
          new(root:, access:, structural:).generate
        end

        # @param [Nokogiri::XML::Element] root Element that is the root of the access assertions.
        # @param [Cocina::Models::DROAccess] access access/rights metadata in Cocina
        # @param [Cocina::Models::DROStructural] structural structural metadata in Cocina
        def initialize(root:, access:, structural:)
          @root = root
          # citation-only (object level) gets mapped to dark (file level)
          @access = access.view == 'citation-only' ? Cocina::Models::DROAccess.new(view: 'dark', download: 'none') : access
          @structural = structural
        end

        # @return [Array<Nokogiri::XML::Element>]
        def generate
          [].tap do |nodes|
            file_sets.each do |file_set|
              file_set.structural.contains.each do |file|
                next unless file_access_different_than_item_access?(file.access)

                read_access_node = Nokogiri::XML::Node.new('access', document).tap do |access_node|
                  access_node.set_attribute('type', 'read')
                  file_node = Nokogiri::XML::Node.new('file', document)
                  file_node.content = file.filename
                  access_node.add_child(file_node)
                end

                read_access_node.add_child(read_machine_node(file.access))

                if (download_node = download_machine_node(file.access))
                  read_access_node.add_child(download_node)
                end

                nodes << read_access_node
              end
            end
          end
        end

        private

        attr_reader :root, :access, :structural

        def file_sets
          Array(structural&.contains)
        end

        def file_access_different_than_item_access?(file_access)
          file_access.view != access.view ||
            file_access.download != access.download ||
            file_access.location != access.location ||
            # Nil should be treated same as false
            (file_access.controlledDigitalLending || false) != (access.controlledDigitalLending || false)
        end

        def file_access_props
          %i[view controlledDigitalLending download location]
        end

        def read_machine_node(file_access)
          Nokogiri::XML::Node.new('machine', document).tap do |machine_node|
            read_access_level_node =
              if cdl_access?(file_access)
                cdl_node = Nokogiri::XML::Node.new('cdl', document)
                group_node = Nokogiri::XML::Node.new('group', document)
                group_node.content = 'stanford'
                group_node.set_attribute('rule', 'no-download')
                cdl_node.add_child(group_node)
                cdl_node
              elsif world_read_access?(file_access)
                world_node = Nokogiri::XML::Node.new('world', document)
                if no_download?(file_access) || location_based_download?(file_access) || stanford_download?(file_access)
                  world_node.set_attribute('rule',
                                           'no-download')
                end
                world_node
              elsif stanford_read_access?(file_access)
                group_node = Nokogiri::XML::Node.new('group', document)
                group_node.content = 'stanford'
                if no_download?(file_access) || location_based_download?(file_access)
                  group_node.set_attribute('rule',
                                           'no-download')
                end
                group_node
              elsif location_based_access?(file_access)
                loc_node = Nokogiri::XML::Node.new('location', document)
                loc_node.content = file_access.location
                loc_node.set_attribute('rule', 'no-download') if no_download?(file_access)
                loc_node
              else # we know it is citation-only or dark at this point
                Nokogiri::XML::Node.new('none', document)
              end
            machine_node.add_child(read_access_level_node)
          end
        end

        def download_machine_node(file_access)
          return unless (location_based_download?(file_access) && (stanford_read_access?(file_access) || world_read_access?(file_access))) ||
                        (stanford_download?(file_access) && world_read_access?(file_access))

          Nokogiri::XML::Node.new('machine', document).tap do |machine_node|
            download_access_level_node =
              if location_based_download?(file_access)
                loc_node = Nokogiri::XML::Node.new('location', document)
                loc_node.content = file_access.location
                loc_node
              elsif stanford_download?(file_access)
                group_node = Nokogiri::XML::Node.new('group', document)
                group_node.content = 'stanford'
                group_node
              end

            machine_node.add_child(download_access_level_node)
          end
        end

        def world_read_access?(file_access)
          file_access.view == 'world'
        end

        def stanford_read_access?(file_access)
          file_access.view == 'stanford'
        end

        def cdl_access?(file_access)
          file_access.try(:controlledDigitalLending)
        end

        def location_based_access?(file_access)
          file_access.view == 'location-based' && file_access.try(:location)
        end

        def no_download?(file_access)
          file_access.try(:download) == 'none'
        end

        def stanford_download?(file_access)
          file_access.try(:download) == 'stanford'
        end

        def location_based_download?(file_access)
          file_access.try(:download) == 'location-based' && file_access.try(:location)
        end

        def document
          root.document
        end
      end
    end
  end
end
