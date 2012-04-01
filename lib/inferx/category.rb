require 'inferx/key'

class Inferx
  class Category
    include Key

    def initialize(redis, category_name, namespace = nil)
      @redis = redis
      @name = category_name
      @namespace = namespace
      @key = category_key(category_name)
      @size_key = category_size_key(category_name)
    end

    attr_reader :name

    def all(options = {})
      command, range = if score = options[:score]
                         [:zrevrangebyscore, ['+inf', score]]
                       else
                         rank = options[:rank] || -1
                         [:zrevrange, [0, rank]]
                       end

      words_with_score = @redis.__send__(command, @key, *range, :withscores => true)
      size = words_with_score.size
      index = 1

      while index < size
        words_with_score[index] = words_with_score[index].to_i
        index += 2
      end

      Hash[*words_with_score]
    end

    def get(word)
      score = @redis.zscore(@key, word)
      score ? score.to_i : nil
    end
    alias [] get

    def train(words)
      @redis.pipelined do
        increase = collect(words).inject(0) do |count, pair|
          @redis.zincrby(@key, pair[1], pair[0])
          count + pair[1]
        end

        @redis.incrby(@size_key, increase) if increase > 0
      end
    end

    def untrain(words)
      decrease = 0

      values = @redis.pipelined do
        decrease = collect(words).inject(0) do |count, pair|
          @redis.zincrby(@key, -pair[1], pair[0])
          count + pair[1]
        end

        @redis.zremrangebyscore(@key, '-inf', 0)
      end

      values[0..-2].each do |score|
        score = score.to_i
        decrease += score if score < 0
      end

      @redis.incrby(@size_key, -decrease) if decrease > 0
    end

    def size
      (@redis.get(@size_key) || 0).to_i
    end

    def scores(words, options = {})
      default = options[:default]
      cache = options[:cache] || {}

      scores = @redis.pipelined do
        words.each do |word|
          @redis.zscore(@key, word) unless cache[word]
        end
      end

      index = 0

      next_score = lambda do
        score = scores[index]
        index += 1
        score ? score.to_i : default
      end

      words.map { |word| cache[word] || next_score[] }
    end

    private

    def collect(words)
      words.inject({}) do |hash, word|
        hash[word] ||= 0
        hash[word] += 1
        hash
      end
    end
  end
end
