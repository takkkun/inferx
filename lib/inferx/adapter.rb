class Inferx
  class Adapter

    # @param [Redis] redis an instance of Redis
    # @param [Hash] options
    # @option options [String] :namespace namespace of keys to be used to Redis
    # @option options [Boolean] :manual whether manual save, defaults to false
    def initialize(redis, options = {})
      @redis = redis
      @options = options
      @namespace = options[:namespace]
      @manual = !!options[:manual]
    end

    # Determine if manual save.
    #
    # @return [Boolean] whether or not manual save
    def manual?
      @manual
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
    # @param [String] category_name a category name
    # @return [String] the key
    def make_category_key(category_name)
      "#{categories_key}:#{category_name}"
    end

    # Spawn an instance of any class.
    #
    # @param [Class] klass any class, constructor takes the instance of Redis to
    #   first argument, and takes the options to last argument
    # @param [Array] args any arguments
    # @return [Object] a instance of the class
    def spawn(klass, *args)
      klass.new(@redis, *args, @options)
    end
  end
end
