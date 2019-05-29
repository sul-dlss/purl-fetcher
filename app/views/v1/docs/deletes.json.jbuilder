json.deletes @deletes do |delete|
  json.druid delete.druid
  json.updated_at delete.updated_at.iso8601
  json.latest_change delete.deleted_at.iso8601
end
json.partial! 'shared/paginate', locals: { object: @deletes }
json.range do
  json.first_modified @first_modified.iso8601
  json.last_modified @last_modified.iso8601
end
