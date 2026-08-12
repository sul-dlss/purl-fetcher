# Writes indexer log messages to Kafka based on the PURL's true targets or if it was deleted.
class IndexerLogWriter
  def self.produce_indexer_log_message(purl, async: false)
    new(purl, async).produce
  end

  def initialize(purl, async)
    @purl = purl
    @async = async
  end

  attr_reader :purl, :async

  def produce
    send_to_topic(Settings.indexer.searchworks) if searchworks?
    send_to_topic(Settings.indexer.earthworks) if earthworks?
  end

  private

  def send_to_topic(topic)
    Racecar.public_send(racecar_method, value:, topic:, key:)
  end

  def earthworks?
    target?('Earthworks')
  end

  def searchworks?
    target?('Searchworks')
  end

  def target?(name)
    purl.true_targets.include?(name) || purl.false_targets.include?(name)
  end

  def value
    purl.as_public_json.to_json
  end

  def key
    purl.druid
  end

  def racecar_method
    async ? :produce_async : :produce_sync
  end
end
