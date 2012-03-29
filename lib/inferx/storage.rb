require 'redis'

class Inferx
  class Storage
    def initialize(options = {})
      @redis = Redis.new(options)
      parts = %w(inferx)
      parts << options[:namespace] if options[:namespace]
      @namespace = parts.join(':')
    end

    attr_reader :namespace

    def load
      Hash[categories.map { |category| [category, get(category)] }]
    end

    def save(categories)
      # If Redis#smembers is called in given block to Redis#multi,
      # it would return an empty array.
      keys = self.categories.map { |category| category_key(category) }

      @redis.multi do
        @redis.del(categories_key, *keys)
        categories.each { |category, frequency| set(category, frequency) }
      end
    end

    def categories
      (@redis.smembers(categories_key) || []).map(&:to_sym)
    end

    def get(category)
      Hash[@redis.hgetall(category_key(category)).map { |word, count| [word, count.to_i] }]
    end

    def set(category, frequency)
      @redis.sadd(categories_key, category)
      @redis.mapped_hmset(category_key(category), frequency)
    end

    private

    def categories_key
      @categories_key ||= "#{namespace}:categories"
    end

    def category_key(category)
      "#{categories_key}:#{category}"
    end
  end
end
