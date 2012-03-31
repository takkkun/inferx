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
      cached_scores = category.all(:score => 2)
      size = category.size

      # FEATURE: Use pipelined
      scores[category.name] = words.inject(0) do |score, word|
        score + Math.log((cached_scores[word] || category[word] || 0.1) / size)
      end

      scores
    end
  end

  def classify(words)
    classifications(words).max_by { |score| score[1] }[0]
  end
end
