class Inferx
  module Key
    def categories_key
      parts = %w(inferx categories)
      parts.insert(1, @namespace) if @namespace
      parts.join(':')
    end

    def category_key(category_name)
      "#{categories_key}:#{category_name}"
    end

    def category_size_key(category_name)
      "#{category_key(category_name)}:size"
    end
  end
end
