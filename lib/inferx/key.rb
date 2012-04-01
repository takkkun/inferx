class Inferx
  module Key

    # Get the key for access to categories.
    #
    # @return [String] the key
    def categories_key
      parts = %w(inferx categories)
      parts.insert(1, @namespace) if @namespace
      parts.join(':')
    end

    # Get the key for access to scores stored each by word.
    #
    # @param [Symbol] a category name
    # @return [String] the key
    def category_key(category_name)
      "#{categories_key}:#{category_name}"
    end

    # Get the key for access to total of score.
    #
    # @param [Symbol] a category name
    # @return [String] the key
    def category_size_key(category_name)
      "#{category_key(category_name)}:size"
    end
  end
end
