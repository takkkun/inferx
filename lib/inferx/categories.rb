require 'inferx/key'
require 'inferx/category'

class Inferx
  class Categories
    include Key

    def initialize(redis, namespace = nil)
      @redis = redis
      @namespace = namespace
      @key = categories_key
    end

    def all
      (@redis.smembers(@key) || []).map(&:to_sym)
    end

    def get(category_name)
      raise ArgumentError, "'#{category_name}' is missing" unless @redis.sismember(@key, category_name)
      Category.new(@redis, category_name, @namespace)
    end
    alias [] get

    def add(*category_names)
      @redis.pipelined do
        category_names.each { |category_name| @redis.sadd(@key, category_name) }
      end
    end

    def remove(*category_names)
      @redis.pipelined do
        keys = []

        category_names.each do |category_name|
          @redis.srem(@key, category_name)
          keys << category_key(category_name)
          keys << category_size_key(category_name)
        end

        @redis.del(*keys)
      end
    end

    include Enumerable

    def each
      all.each { |category_name| yield Category.new(@redis, category_name, @namespace) }
    end
  end
end
