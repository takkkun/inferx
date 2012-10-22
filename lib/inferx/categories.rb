require 'inferx/adapter'
require 'inferx/category'

class Inferx
  class Categories < Adapter
    include Enumerable

    # Get all category names.
    #
    # @return [Array<Symbol>] category names
    def all
      (hkeys || []).map(&:to_sym)
    end

    # Get a category according the name.
    #
    # @param [Symbol] category_name a category name
    # @return [Inferx::Category] a category
    def get(category_name)
      size = hget(category_name)
      raise ArgumentError, "'#{category_name}' is missing" unless size
      spawn_category(category_name, size.to_i)
    end
    alias [] get

    # Add categories.
    #
    # @param [Array<Symbol>] category_names category names
    def add(*category_names)
      @redis.pipelined do
        category_names.each { |category_name| hsetnx(category_name, 0) }
        @redis.save unless manual?
      end
    end

    # Remove categories.
    #
    # @param [Array<Symbol>] category_names category names
    def remove(*category_names)
      @redis.pipelined do
        category_names.each { |category_name| hdel(category_name) }
        @redis.del(*category_names.map(&method(:make_category_key)))
        @redis.save unless manual?
      end
    end

    # Apply process for each category.
    #
    # @yield a block to be called for every category
    # @yieldparam [Inferx::Category] category a category
    def each
      hgetall.each do |category_name, size|
        yield spawn_category(category_name, size.to_i)
      end
    end

    protected

    def spawn_category(*args)
      spawn(Category, *args)
    end
  end
end
