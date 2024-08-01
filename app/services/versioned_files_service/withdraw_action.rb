class VersionedFilesService
  # Service for withdrawing / restoring a version.
  class WithdrawAction
    # @param version [Integer] the version number
    # @param withdrawn [Boolean] true to withdraw, false to restore
    # @param object [VersionedFilesService::Object] the object
    def initialize(version:, withdrawn:, object:)
      @version = version.to_i
      @withdrawn = withdrawn
      @object = object
    end

    def call
      raise BadRequestError, 'Cannot withdraw head version' if version == head_version

      version_manifest.withdraw(version:, withdrawn:)
    end

    private

    attr_reader :version, :withdrawn, :object

    delegate :version_manifest, :head_version, to: :@object
  end
end
