require 'inferx/adapter'

class Inferx
  class Category < Adapter

    # @param [Redis] redis an instance of Redis
    # @param [Symbol] name a category name
    # @param [Integer] size total of scores
    # @param [Hash] options
    # @option options [String] :namespace namespace of keys to be used to Redis
    # @option options [Boolean] :manual whether manual save, defaults to false
    def initialize(redis, name, size, options = {})
      super(redis, options)
      @name = name
      @size = size
    end

    # Get a category name.
    #
    # @attribute [r] name
    # @return [Symbol] a category name

    # Get total of scores.
    #
    # @attribute [r] size
    # @return [Integer] total of scores
    attr_reader :name, :size

    # Get words with scores in the category.
    #
    # @return [Hash<String, Integer>] words with scores
    def all
      words_with_scores = zrevrange(0, -1, :withscores => true)
      index = 1
      size = words_with_scores.size

      while index < size
        words_with_scores[index] = words_with_scores[index].to_i
        index += 2
      end

      Hash[*words_with_scores]
    end

    # Get score of a word.
    #
    # @param [String] word a word
    # @return [Integer] when the word is member, score of the word
    # @return [nil] when the word is not member
    def get(word)
      score = zscore(word)
      score ? score.to_i : nil
    end
    alias [] get

    # Enhance the training data giving words.
    #
    # @param [Array<String>] words an array of words
    def train(words)
      @redis.pipelined do
        increase = collect(words).inject(0) do |count, pair|
          zincrby(pair[1], pair[0])
          count + pair[1]
        end

        if increase > 0
          hincrby(name, increase)
          @redis.save unless manual?
          @size += increase
        end
      end
    end

    # Prepare to enhance the training data. Use for high performance.
    #
    # @yield [train] process something
    # @yieldparam [Proc] train enhance the training data giving words
    def ready_to_train
      all_words = []
      yield lambda { |words| all_words += words }
      train(all_words)
    end

    # Attenuate the training data giving words.
    #
    # @param [Array<String>] words an array of words
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

      if decrease > 0
        hincrby(name, -decrease)
        @redis.save unless manual?
        @size -= decrease
      end
    end

    # Get effectively scores for each word.
    #
    # @param [Array<String>] words an array of words
    # @return [Array<Integer>] scores for each word
    def scores(words)
      scores = @redis.pipelined { words.map(&method(:zscore)) }
      scores.map { |score| score ? score.to_i : nil }
    end

    private

    %w(zrevrange zscore zincrby zremrangebyscore).each do |command|
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
