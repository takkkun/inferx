require 'redis'

require 'inferx/version'
require 'inferx/categories'

class Inferx

  # @param [Hash] options
  #   - `:namespace => String`: namespace of keys to be used to Redis
  #
  #   Other options are passed to Redis#initialize in:
  #     https://github.com/redis/redis-rb
  def initialize(options = {})
    namespace = options.delete(:namespace)
    redis = Redis.new(options)
    @categories = Categories.new(redis, namespace)
  end

  attr_reader :categories

  # Get a score of a category according to a set of words.
  #
  # @param [Inferx::Category] a category for scoring
  # @param [Array<String>] a set of words
  # @return [Float] a score of the category
  def score(category, words)
    size = category.size.to_f
    return -Float::INFINITY unless size > 0
    words_with_scores = category.all(:rank => 500)
    scores = category.scores(words, words_with_scores)
    scores.inject(0) { |s, score| s + Math.log((score || 0.1) / size) }
  end

  # Get a score for each category according to a set of words.
  #
  # @param [Array<String>] a set of words
  # @return [Hash<Symbol, Float>] scores to key a category
  #
  # @see #score
  def classifications(words)
    words = words.uniq
    Hash[@categories.map { |category| [category.name, score(category, words)] }]
  end

  # Classify words to any one category
  #
  # @param [Array<String>] a set of words
  # @return [Symbol] most high-scoring category name
  #
  # @see #score
  # @see #classifications
  def classify(words)
    category = classifications(words).max_by { |score| score[1] }
    category ? category[0] : nil
  end
end
