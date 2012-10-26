require 'inferx/adapter'
require 'inferx/category'
require 'inferx/category/complementary'
require 'set'

class Inferx
  class Categories < Adapter
    include Enumerable

    # @param [Redis] redis an instance of Redis
    # @param [Hash] options
    # @option options [Boolean] :complementary use complementary Bayes
    #   classifier
    # @option options [String] :namespace namespace of keys to be used to Redis
    # @option options [Boolean] :manual whether manual save, defaults to false
    def initialize(redis, options = {})
      super
      @filter = nil
      @except = Set.new
      @category_class = options[:complementary] ? Category::Complementary : Category
    end

    # Filter categories.
    #
    # @param [Array<String>] category_names category names
    # @return [Inferx::Categories] categories filtered by the category names
    def filter(*category_names)
      category_names = category_names.map(&:to_s)

      filtered do
        @filter = @filter ? @filter & category_names : Set.new(category_names)
      end
    end

    # Filter by excepting categories.
    #
    # @param [Array<String>] category_names category names
    # @return [Inferx::Categories] categories filterd by the category names
    def except(*category_names)
      category_names = category_names.map(&:to_s)

      filtered do
        @except.merge(category_names)
      end
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
      raise ArgumentError, "#{category_name.inspect} does not exist in filtered categories" unless all_in_visible.include?(category_name.to_s)
      spawn(@category_class, category_name, size.to_i, self)
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
        yield spawn(@category_class, category_name, size.to_i, self)
      end
    end

    private

    def filtered(&block)
      dup.tap { |filtered| filtered.instance_eval(&block) }
    end

    def all_in_visible
      all = Set.new(hkeys || [])
      all &= @filter if @filter
      all - @except
    end
  end
end
