# Disable all the activestorage routes. We will manually add only the routes we need.
Rails.application.config.active_storage.draw_routes = false

# Override the default (5.minutes), so that large files have enough time to upload
Rails.application.config.active_storage.service_urls_expire_in = 20.minute
