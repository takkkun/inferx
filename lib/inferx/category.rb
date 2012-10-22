require 'inferx/adapter'

class Inferx
  class Category < Adapter

    # @param [Redis] redis an instance of Redis
    # @param [String] name a category name
    # @param [Integer] size total of scores
    # @param [Hash] options
    # @option options [String] :namespace namespace of keys to be used to Redis
    # @option options [Boolean] :manual whether manual save, defaults to false
    def initialize(redis, name, size, options = {})
      super(redis, options)
      @name = name.to_s
      @size = size
    end

    # Get a category name.
    #
    # @attribute [r] name
    # @return [String] a category name

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
      return if words.empty?

      increase = words.size
      words = collect(words)

      @redis.pipelined do
        words.each { |word, count| zincrby(count, word) }
        hincrby(name, increase)
        @redis.save unless manual?
      end

      @size += increase
    end

    # Prepare to enhance the training data. Use for high performance.
    #
    # @yield [train] process something
    # @yieldparam [Proc] train enhance the training data giving words
    def ready_to_train(&process)
      train(aggregate(&process))
    end

    # Attenuate the training data giving words.
    #
    # @param [Array<String>] words an array of words
    def untrain(words)
      return if words.empty?

      decrease = words.size
      words = collect(words)

      scores = @redis.pipelined do
        words.each { |word, count| zincrby(-count, word) }
      end

      scores.each do |score|
        score = score.to_i
        decrease += score if score < 0
      end

      return unless decrease > 0

      @redis.pipelined do
        zremrangebyscore('-inf', 0)
        hincrby(name, -decrease)
        @redis.save unless manual?
      end

      @size -= decrease
    end

    # Prepare to attenuate the training data giving words.
    #
    # @yield [untrain] process something
    # @yieldparam [Proc] untrain attenuate the training data giving words
    def ready_to_untrain(&process)
      untrain(aggregate(&process))
    end

    # Get effectively scores for each word.
    #
    # @param [Array<String>] words an array of words
    # @return [Array<Integer>] scores for each word
    def scores(words)
      scores = @redis.pipelined { words.map(&method(:zscore)) }
      scores.map { |score| score ? score.to_i : nil }
    end

    protected

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

    def aggregate
      all = []
      yield lambda { |items| all += items }
      all
    end
  end
end
