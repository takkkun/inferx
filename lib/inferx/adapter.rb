class Inferx
  class Adapter

    # @param [Redis] an instance of Redis
    # @param [String] namespace of keys to be used to Redis
    def initialize(redis, namespace = nil)
      @redis = redis
      @namespace = namespace
    end

    # Get the key for access to categories.
    #
    # @return [String] the key
    def categories_key
      @categories_key ||= make_categories_key
    end

    # Make the key for access to categories.
    #
    # @return [String] the key
    def make_categories_key
      parts = %w(inferx categories)
      parts.insert(1, @namespace) if @namespace
      parts.join(':')
    end

    # Make the key for access to scores stored each by word.
    #
    # @param [Symbol] a category name
    # @return [String] the key
    def make_category_key(category_name)
      "#{categories_key}:#{category_name}"
    end

    # Spawn an instance of any class.
    #
    # @param [Class] any class, constructor takes the instance of Redis to
    #   first argument, and takes the namespace to last argument
    # @return [Object] a instance of the class
    def spawn(klass, *args)
      klass.new(@redis, *args, @namespace)
    end

    protected

    %w(hdel hexists hget hincrby hkeys hsetnx).each do |command|
      define_method(command) do |*args|
        @redis.__send__(command, categories_key, *args)
      end
    end
  end
end
