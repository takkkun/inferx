require 'inferx/category'

class Inferx
  module Complementary
    class Category < Inferx::Category
      def initialize(categories, redis, name, size, options = {})
        @categories = categories
        super redis, name, size, options
      end
    end
  end
end
