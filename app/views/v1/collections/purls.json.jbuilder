json.purls do
  json.array! @purls, partial: 'purl', as: :purl
end
json.partial! 'shared/paginate', locals: { object: @purls }
