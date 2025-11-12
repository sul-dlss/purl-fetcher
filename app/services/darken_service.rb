# frozen_string_literal: true

# Service for darkening an object.
# This service removes files from the stacks filesystem in order to make an objct dark.
class DarkenService
  def self.call(...)
    new(...).call
  end

  def initialize(druid)
    @object_store = ObjectStore.new(druid:)
  end

  # Remove the object from the stacks filesystem and clean up any empty directories in the druid tree.
  def call
    @object_store.destroy
  end
end
