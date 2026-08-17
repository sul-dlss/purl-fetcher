class CurrentReleases
  def initialize(targets:)
    @targets = targets
  end

  attr_reader :targets

  def earthworks?
    targets.include?('Earthworks')
  end

  def searchworks?
    targets.include?('Searchworks')
  end

  def sitemap?
    targets.include?('PURL sitemap')
  end
end
