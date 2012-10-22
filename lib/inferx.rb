require 'redis'

require 'inferx/version'
require 'inferx/categories'
require 'inferx/complementary/categories'

class Inferx

  # @param [Hash] options other options are passed to Redis#initialize in
  #   {https://github.com/redis/redis-rb redis}
  #
  # @option options [Boolean] :complementary
  # @option options [String] :namespace namespace of keys to be used to Redis
  # @option options [Boolean] :manual whether manual save, defaults to false
  def initialize(options = {})
    @complementary = !!options[:complementary]
    categories_class = @complementary ? Complementary::Categories : Categories
    @categories = categories_class.new(Redis.new(options), options)
  end

  attr_reader :categories

  # Get a score of a category according to a set of words.
  #
  # @param [Inferx::Category] category a category for scoring
  # @param [Array<String>] words a set of words
  # @return [Float] a score of the category
  def score(category, words)
    size = category.size.to_f
    return -Float::INFINITY unless size > 0
    scores = category.scores(words)
    scores.inject(0.0) { |s, score| s + Math.log((score || 0.1) / size) }
  end

  # Get a score for each category according to a set of words.
  #
  # @param [Array<String>] words a set of words
  # @return [Hash<Symbol, Float>] scores to key a category
  #
  # @see #score
  def classifications(words)
    words = words.uniq
    Hash[@categories.map { |category| [category.name, score(category, words)] }]
  end

  # Classify words to any one category.
  #
  # @param [Array<String>] words a set of words
  # @return [Symbol] most high-scoring category name
  #
  # @see #score
  # @see #classifications
  def classify(words)
    method_name = @complementary ? :min_by : :max_by
    category = classifications(words).__send__(method_name) { |score| score[1] }
    category ? category[0] : nil
  end
end
