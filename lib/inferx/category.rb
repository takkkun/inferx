class Inferx
  class Category

    def self.ready_for(method_name)
      define_method("ready_to_#{method_name}") do |&block|
        all = []
        block[lambda { |items| all += items }]
        __send__(method_name, all)
      end
    end

    # @param [Redis] redis an instance of Redis
    # @param [Inferx::Categories] categories the categories
    # @param [String] name a category name
    # @param [Integer] size total of scores
    def initialize(redis, categories, name, size)
      @redis = redis
      @categories = categories
      @key = "#{categories.key}:#{name}"
      @name = name.to_s
      @size = size
    end

    # Get key for access to training data of the category.
    #
    # @attribute [r] key
    # @return [String] the key
    attr_reader :key

    # Get a category name.
    #
    # @attribute [r] name
    # @return [String] a category name
    attr_reader :name

    # Get total of scores.
    #
    # @attribute [r] size
    # @return [Integer] total of scores
    attr_reader :size

    # Get words with scores in the category.
    #
    # @return [Hash<String, Integer>] words with scores
    def all
      words_with_scores = zrevrange(0, -1, :withscores => true)

      if !words_with_scores.empty? and words_with_scores.first.is_a?(Array)
        words_with_scores.each { |pair| pair[1] = pair[1].to_i }
        Hash[words_with_scores]
      else
        index = 1
        size = words_with_scores.size

        while index < size
          words_with_scores[index] = words_with_scores[index].to_i
          index += 2
        end

        Hash[*words_with_scores]
      end
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
      increases = @categories.filter(name).inject(words)
      @size += increases[name]
    end

    # Prepare to enhance the training data. Use for high performance.
    #
    # @yield [train] process something
    # @yieldparam [Proc] train enhance the training data giving words
    ready_for :train

    # Attenuate the training data giving words.
    #
    # @param [Array<String>] words an array of words
    def untrain(words)
      decreases = @categories.filter(name).eject(words)
      @size -= decreases[name]
    end

    # Prepare to attenuate the training data giving words.
    #
    # @yield [untrain] process something
    # @yieldparam [Proc] untrain attenuate the training data giving words
    ready_for :untrain

    # Get effectively scores for each word.
    #
    # @param [Array<String>] words an array of words
    # @return [Array<Integer>] scores for each word
    def scores(words)
      scores = @redis.pipelined { words.map(&method(:zscore)) }
      scores.map { |score| score ? score.to_i : nil }
    end

    private

    %w(zrevrange zscore).each do |command|
      define_method(command) do |*args|
        @redis.__send__(command, @key, *args)
      end
    end
  end
end
