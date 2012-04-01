require 'redis'

require 'inferx/version'
require 'inferx/categories'

class Inferx
  def initialize(options = {})
    namespace = options.delete(:namespace)
    redis = Redis.new(options)
    @categories = Categories.new(redis, namespace)
  end

  attr_reader :categories

  def score(category, words)
    size = category.size.to_f
    return -Float::INFINITY unless size > 0
    words_with_scores = category.all(:rank => 500)
    scores = category.scores(words, words_with_scores)
    scores.inject(0) { |s, score| s + Math.log((score || 0.1) / size) }
  end

  def classifications(words)
    words = words.uniq
    Hash[@categories.map { |category| [category.name, score(category, words)] }]
  end

  def classify(words)
    category = classifications(words).max_by { |score| score[1] }
    category ? category[0] : nil
  end
end
