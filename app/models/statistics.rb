class Statistics
  def published
    Purl.published.count
  end

  def deleted
    Purl.status('deleted').count
  end

  def changes
    Purl.published
        .status('public')
        .count
  end

  def deletes
    Purl.count
  end

  def histogram
    collect_histogram_data(Purl.published.status('public'))
  end

  def release_tags
    ReleaseTag.group(:name, :release_type).count
  end

  def searchworks
    {
      released_with_catkey: released_to_searchworks.where.not(catkey: '').count,
      released_without_catkey: released_to_searchworks.where(catkey: '').count,
      histogram: collect_histogram_data(released_to_searchworks)
    }
  end

  private

  def collect_histogram_data(target)
    %i[beginning_of_day beginning_of_week beginning_of_month beginning_of_year].to_h do |time|
      [
        time,
        target
          .where(updated_at: Time.zone.now.public_send(time)..Time.zone.now)
          .count
      ]
    end
  end

  def released_to_searchworks
    @released_to_searchworks ||= Purl.published
                                     .status('public')
                                     .target('Searchworks')
                                     .where('release_tags.release_type=?', true)
  end
end
