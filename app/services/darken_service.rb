# frozen_string_literal: true

# Service for darkening an object.
# This service removes files from the stacks filesystem in order to make an objct dark.
class DarkenService
  def self.call(...)
    new(...).call
  end

  def initialize(druid)
    @stacks_druid_path = DruidTools::PurlDruid.new(druid, Settings.filesystems.stacks_root).pathname
  end

  # Remove the object from the stacks filesystem and clean up any empty directories in the druid tree.
  def call
    FileUtils.rm_rf(stacks_druid_path)

    clean_druid_tree(stacks_druid_path.parent)
  end

  private

  attr_reader :stacks_druid_path

  # Clean up any empty directories in the druid tree.
  def clean_druid_tree(path)
    return unless path.exist? && path.empty?

    FileUtils.rm_rf(path)
    clean_druid_tree(path.parent)
  end
end
