class VersionedFilesService
  # Creates symlinks in the Stacks filesystem for the given object.
  class StacksLinkAction
    # @param service [VersionedFilesService] the service
    # @param version [String] the version number
    def initialize(service:, version:)
      @version = version
      @service = service
    end

    def call
      FileUtils.mkdir_p(stacks_object_path)
      shelve_file_map.each do |filename, md5|
        LinkSupport.link(content_path_for(md5:), stacks_object_path.join(filename))
      end
      recursive_cleanup(stacks_object_path)
    end

    private

    attr_reader :cocina, :version

    delegate :stacks_object_path, :content_path_for, :cocina_path_for, :object_path, to: :@service

    def shelve_file_map
      @shelve_file_map ||= version ? Cocina.new(hash: cocina_hash).shelve_file_map : {}
    end

    def cocina_hash
      JSON.parse(cocina_path_for(version:).read).to_h
    end

    def recursive_cleanup(path)
      if path.directory?
        return if path == object_path

        path.children.each do |child|
          recursive_cleanup(child)
        end
        path.rmdir if path.empty? && path != stacks_object_path
      else
        relative_path = path.relative_path_from(stacks_object_path).to_s
        return if shelve_file_map.key?(relative_path)

        path.unlink
      end
    end
  end
end
