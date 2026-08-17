class Releases
  def initialize(true_targets:, false_targets:)
    @true_targets = true_targets
    @false_targets = false_targets
  end

  attr_reader :true_targets, :false_targets

  def earthworks?
    true_targets.include?('Earthworks') || false_targets.include?('Earthworks')
  end

  def searchworks?
    true_targets.include?('Searchworks') || false_targets.include?('Searchworks')
  end

  def sitemap?
    true_targets.include?('PURL sitemap') || false_targets.include?('PURL sitemap')
  end
end
