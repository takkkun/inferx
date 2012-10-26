require 'inferx/adapter'
require 'inferx/category'
require 'set'

class Inferx
  class Categories < Adapter
    include Enumerable

    # @param [Redis] redis an instance of Redis
    # @param [Hash] options
    # @option options [String] :namespace namespace of keys to be used to Redis
    # @option options [Boolean] :manual whether manual save, defaults to false
    def initialize(redis, options = {})
      super
      @filter = Set.new
      @except = Set.new
    end

    # Filter categories.
    #
    # @param [Array<String>] category_names category names
    # @return [Inferx::Categories] categories filtered by the category names
    def filter(*category_names)
      append(:@filter, category_names)
    end

    # Filter by excepting categories.
    #
    # @param [Array<String>] category_names category names
    # @return [Inferx::Categories] categories filterd by the category names
    def except(*category_names)
      append(:@except, category_names)
    end

    # Get all category names.
    #
    # @return [Array<String>] category names
    def all
      all_in_visible.to_a
    end

    # Get a category according the name.
    #
    # @param [String] category_name a category name
    # @return [Inferx::Category] the category
    def get(category_name)
      size = hget(category_name)
      raise ArgumentError, "#{category_name.inspect} is missing" unless size
      raise ArgumentError, "#{category_name.inspect} does not exist in filtered categories" unless all_in_visible.include?(category_name)
      spawn_category(category_name, size.to_i)
    end
    alias [] get

    # Add categories.
    #
    # @param [Array<String>] category_names category names
    def add(*category_names)
      @redis.pipelined do
        category_names.each { |category_name| hsetnx(category_name, 0) }
        @redis.save unless manual?
      end
    end

    # Remove categories.
    #
    # @param [Array<String>] category_names category names
    def remove(*category_names)
      @redis.pipelined do
        category_names.each { |category_name| hdel(category_name) }
        @redis.del(*category_names.map(&method(:make_category_key)))
        @redis.save unless manual?
      end
    end

    # Determine if the category is defined.
    #
    # @param [String] category_name a category name
    # @return whether the category is defined
    def exists?(category_name)
      all_in_visible.include?(category_name.to_s)
    end

    # Apply process for each category.
    #
    # @yield a block to be called for every category
    # @yieldparam [Inferx::Category] category a category
    def each
      visible_category_names = all_in_visible

      hgetall.each do |category_name, size|
        next unless visible_category_names.include?(category_name)
        yield spawn_category(category_name, size.to_i)
      end
    end

    protected

    def spawn_category(*args)
      spawn(Category, *args)
    end

    private

    def append(instance_variable_name, category_names)
      dup.tap do |categories|
        categories.instance_eval do
          set = instance_variable_get(instance_variable_name)
          set.merge(category_names.map(&:to_s))
        end
      end
    end

    def all_in_visible
      all = Set.new(hkeys || [])
      all &= @filter unless @filter.empty?
      all - @except
    end
  end
end
