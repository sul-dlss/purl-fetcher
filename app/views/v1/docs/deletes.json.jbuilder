json.deletes @deletes do |delete|
  json.druid delete.druid
  json.latest_change delete.deleted_at.iso8601
end
json.partial! 'shared/paginate', locals: { object: @deletes }