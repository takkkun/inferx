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

  def classifications(words)
    words = words.uniq

    @categories.inject({}) do |scores, category|
      size = category.size.to_f
      scores[category.name] = size > 0 ? score(category, size, words) : -Float::INFINITY
      scores
    end
  end

  def classify(words)
    classifications(words).max_by { |score| score[1] }[0]
  end

  private

  def score(category, size, words)
    cached_scores = category.all(:score => 2)

    # FEATURE: Use pipelined
    words.inject(0) do |score, word|
      score + Math.log((cached_scores[word] || category[word] || 0.1) / size)
    end
  end
end
