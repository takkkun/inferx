require 'inferx/key'
require 'inferx/category'

class Inferx
  class Categories
    include Key

    # @param [Redis] an instance of Redis
    # @param [String] namespace of keys to be used to Redis
    def initialize(redis, namespace = nil)
      @redis = redis
      @namespace = namespace
      @key = categories_key
    end

    # Get all category names.
    #
    # @return [Array<Symbol>] category names
    def all
      (@redis.smembers(@key) || []).map(&:to_sym)
    end

    # Get a category according name.
    #
    # @param [Symbol] category name
    # @return [Inferx::Category] category
    def get(category_name)
      raise ArgumentError, "'#{category_name}' is missing" unless @redis.sismember(@key, category_name)
      category(category_name)
    end
    alias [] get

    # Add categories.
    #
    # @param [Array<Symbol>] category names
    def add(*category_names)
      @redis.pipelined do
        category_names.each { |category_name| @redis.sadd(@key, category_name) }
      end
    end

    # Remove categories.
    #
    # @param [Array<Symbol>] category names
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

    # Apply process for each category.
    #
    # @yield a block to be called for every category
    # @yieldparam [Inferx::Category] category
    def each
      all.each { |category_name| yield category(category_name) }
    end

    private

    def category(category_name)
      Category.new(@redis, category_name, @namespace)
    end
  end
end
