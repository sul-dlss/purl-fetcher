class PurlUpdatesConsumer < Racecar::Consumer
  subscribes_to "purl-updates"

  # Update the Purl database record with Cocina data passed in the message
  def process(message) # rubocop:disable Metrics/MethodLength
    json = JSON.parse(message.value)
    cocina_object = nil
    actions = nil
    if json.key?('cocina')
      cocina_object = Cocina::Models.build(json['cocina'])
      actions = json['actions']
    else
      cocina_object = Cocina::Models.build(json)
      actions = { 'index' => [], 'delete' => [] }.tap do |releases|
        cocina_object.administrative.releaseTags.each do |tag|
          releases[tag.release ? 'index' : 'delete'] << tag.to
        end
      end
    end
    purl = Purl.find_by!(druid: cocina_object.externalIdentifier)
    PurlCocinaUpdater.new(purl, cocina_object, actions).update

    purl.produce_indexer_log_message
  rescue StandardError => e
    Honeybadger.notify(e)
    raise e
  end
end
