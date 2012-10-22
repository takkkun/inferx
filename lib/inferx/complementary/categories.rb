require 'inferx/categories'
require 'inferx/complementary/category'

class Inferx
  module Complementary
    class Categories < Inferx::Categories
      protected

      def spawn_category(*args)
        spawn(Category, *args)
      end
    end
  end
end