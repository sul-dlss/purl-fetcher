json.deletes @deletes do |delete|
  json.merge! delete.as_public_json
end
json.partial! 'shared/paginate', locals: { object: @deletes }
json.range do
  json.first_modified @first_modified.iso8601
  json.last_modified @last_modified.iso8601
end
