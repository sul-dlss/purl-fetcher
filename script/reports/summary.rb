# Summary statistics
require 'csv'

now = Time.current
puts "Summary report as of #{now.localtime} on #{`hostname`}"

n = Purl.count
puts "PURLs: #{n}"

n = Purl.where.not(deleted_at: nil).count
puts "Deleted PURLs: #{n}"

n = Purl.where.not(published_at: nil).count
puts "Published PURLs: #{n}"

n = Purl.where(published_at: now - 7.days..).count
puts "Published PURLs in last week: #{n}"

n = Purl.joins(:release_tags)
        .where(release_tags: { name: 'SearchWorks', release_type: true })
        .count
puts "Released to SearchWorks: #{n}"
