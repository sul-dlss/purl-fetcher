class VersionedFilesService
  # Deletes the object from stacksb.
  class DeleteAction
    # @param object [VersionedFilesService::Object] the object
    def initialize(object:)
      @object = object
    end

    def call
      FileUtils.rm_rf(@object.stacks_object_path)
    end

    delegate :head_version, :version_manifest, :version?, to: :@object
  end
end
