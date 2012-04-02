require 'inferx/adapter'
require 'inferx/category'

class Inferx
  class Categories < Adapter

    # Get all category names.
    #
    # @return [Array<Symbol>] category names
    def all
      (hkeys || []).map(&:to_sym)
    end

    # Get a category according name.
    #
    # @param [Symbol] category name
    # @return [Inferx::Category] category
    def get(category_name)
      raise ArgumentError, "'#{category_name}' is missing" unless hexists(category_name)
      spawn(Category, category_name)
    end
    alias [] get

    # Add categories.
    #
    # @param [Array<Symbol>] category names
    def add(*category_names)
      @redis.pipelined do
        category_names.each { |category_name| hsetnx(category_name, 0) }
      end
    end

    # Remove categories.
    #
    # @param [Array<Symbol>] category names
    def remove(*category_names)
      @redis.pipelined do
        category_names.each { |category_name| hdel(category_name) }
        @redis.del(*category_names.map(&method(:make_category_key)))
      end
    end

    include Enumerable

    # Apply process for each category.
    #
    # @yield a block to be called for every category
    # @yieldparam [Inferx::Category] category
    def each
      all.each { |category_name| yield spawn(Category, category_name) }
    end
  end
end
