require 'inferx/adapter'

class Inferx
  class Category < Adapter

    # @param [Redis] an instance of Redis
    # @param [Symbol] a category name
    # @param [String] namespace of keys to be used to Redis
    def initialize(redis, name, namespace = nil)
      super(redis, namespace)
      @name = name
    end

    attr_reader :name

    # Get words with scores in the category.
    #
    # @param [Hash] options
    #   - `:score => Integer`: lower limit for getting by score
    #   - `:rank  => Integer`: upper limit for getting by rank
    #
    # @return [Hash<String, Integer>] words with scores
    def all(options = {})
      words_with_scores = if score = options[:score]
                            zrevrangebyscore('+inf', score, :withscores => true)
                          else
                            rank = options[:rank] || -1
                            zrevrange(0, rank, :withscores => true)
                          end

      size = words_with_scores.size
      index = 1

      while index < size
        words_with_scores[index] = words_with_scores[index].to_i
        index += 2
      end

      Hash[*words_with_scores]
    end

    # Get score of a word.
    #
    # @param [String] a word
    # @return [Integer, nil]
    #   - when the word is member, score of the word
    #   - when the word is not member, nil
    def get(word)
      score = zscore(word)
      score ? score.to_i : nil
    end
    alias [] get

    # Enhance the training data giving words.
    #
    # @param [Array<String>] words
    def train(words)
      @redis.pipelined do
        increase = collect(words).inject(0) do |count, pair|
          zincrby(pair[1], pair[0])
          count + pair[1]
        end

        hincrby(name, increase) if increase > 0
      end
    end

    # Attenuate the training data giving words.
    #
    # @param [Array<String>] words
    def untrain(words)
      decrease = 0

      values = @redis.pipelined do
        decrease = collect(words).inject(0) do |count, pair|
          zincrby(-pair[1], pair[0])
          count + pair[1]
        end

        zremrangebyscore('-inf', 0)
      end

      values[0..-2].each do |score|
        score = score.to_i
        decrease += score if score < 0
      end

      hincrby(name, -decrease) if decrease > 0
    end

    # Get total of scores.
    #
    # @return [Integer] total of scores
    def size
      (hget(name) || 0).to_i
    end

    # Get effectively scores for each word.
    #
    # @param [Array<String>] words
    # @param [Hash<String, Integer>] words with scores prepared in advance for
    #   reduce access to Redis
    # @return [Array<Integer>] scores for each word
    def scores(words, words_with_scores = {})
      scores = @redis.pipelined do
        words.each do |word|
          zscore(word) unless words_with_scores[word]
        end
      end

      index = 0

      next_score = lambda do
        score = scores[index]
        index += 1
        score ? score.to_i : nil
      end

      words.map { |word| words_with_scores[word] || next_score[] }
    end

    private

    %w(zrevrange zrevrangebyscore zscore zincrby zremrangebyscore).each do |command|
      define_method(command) do |*args|
        @category_key ||= make_category_key(@name)
        @redis.__send__(command, @category_key, *args)
      end
    end

    def collect(words)
      words.inject({}) do |hash, word|
        hash[word] ||= 0
        hash[word] += 1
        hash
      end
    end
  end
end
