class Inferx
  module Key
    def categories_key
      @categories_key ||= begin
                            parts = %w(inferx)
                            parts << @namespace if @namespace
                            parts << 'categories'
                            parts.join(':')
                          end
    end

    def category_key(category_name)
      "#{categories_key}:#{category_name}"
    end

    def category_size_key(category_name)
      "#{category_key(category_name)}:size"
    end
  end
end
