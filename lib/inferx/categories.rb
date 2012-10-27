require 'inferx/category'
require 'inferx/category/complementary'
require 'set'

class Inferx
  class Categories
    include Enumerable

    # @param [Redis] redis an instance of Redis
    # @param [Hash] options
    # @option options [Boolean] :complementary use complementary Bayes
    #   classifier
    # @option options [String] :namespace namespace of keys to be used to Redis
    # @option options [Boolean] :manual whether manual save, defaults to false
    def initialize(redis, options = {})
      @redis = redis
      @category_class = options[:complementary] ? Category::Complementary : Category
      parts = %w(inferx categories)
      parts.insert(1, options[:namespace]) if options[:namespace]
      @key = parts.join(':')
      @manual = !!options[:manual]
      @filter = nil
      @except = Set.new
    end

    # Get key for access to the categories on Redis.
    #
    # @attribute [r] key
    # @return [String] the key
    attr_reader :key

    # Determine if manual save.
    #
    # @return [Boolean] whether manual save
    def manual?
      @manual
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
      make_category(category_name, size.to_i)
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
        yield make_category(category_name, size.to_i)
      end
    end

    # Inject the words to the training data of the categories.
    #
    # @param [Array<String>] words an array of words
    # @return [Hash<String, Integer>] increase for each category
    def inject(words)
      category_names = all
      return {} if category_names.empty?
      return associate(category_names, 0) if words.empty?

      increase = words.size
      words = collect(words)

      associate(category_names, increase) do
        @redis.pipelined do
          category_names.each do |category_name|
            words.each { |word, count| zincrby(category_name, count, word) }
            hincrby(category_name, increase)
          end

          @redis.save unless manual?
        end
      end
    end

    # Eject the words from the training data of the categories.
    #
    # @param [Array<String>] words an array of words
    # @return [Hash<String, Integer>] decrease for each category
    def eject(words)
      category_names = all
      return {} if category_names.empty?
      return associate(category_names, 0) if words.empty?

      decrease = words.size
      words = collect(words)

      associate(category_names, decrease) do |fluctuation|
        all_scores = @redis.pipelined do
          category_names.each do |category_name|
            words.each { |word, count| zincrby(category_name, -count, word) }
            zremrangebyscore(category_name, '-inf', 0)
          end
        end

        length = words.size

        category_names.each_with_index do |category_name, index|
          scores = all_scores[index * (length + 1), length]
          initial = fluctuation[category_name]

          fluctuation[category_name] = scores.inject(initial) do |decrease, score|
            score = score.to_i
            score < 0 ? decrease + score : decrease
          end
        end

        @redis.pipelined do
          fluctuation.each do |category_name, decrease|
            hincrby(category_name, -decrease)
          end

          @redis.save unless manual?
        end
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

    def make_category_key(category_name)
      "#{@key}:#{category_name}"
    end

    def make_category(*args)
      @category_class.new(@redis, self, *args)
    end

    def collect(words)
      words.inject({}) do |hash, word|
        hash[word] ||= 0
        hash[word] += 1
        hash
      end
    end

    def associate(keys, value, &block)
      keys_and_values = Hash[keys.map { |key| [key, value] }]
      yield *(block.arity.zero? ? [] : [keys_and_values]) if block_given?
      keys_and_values
    end

    %w(hdel hget hgetall hincrby hkeys hsetnx).each do |command|
      define_method(command) do |*args|
        @redis.__send__(command, @key, *args)
      end
    end

    %w(zincrby zremrangebyscore).each do |command|
      define_method(command) do |category_name, *args|
        key = make_category_key(category_name)
        @redis.__send__(command, key, *args)
      end
    end
  end
end
