require 'inferx/category'

class Inferx
  class Category
    class Complementary < Category

      # Inject the words to the training data of the category.
      #
      # @param [Array<String>] words an array of words
      alias inject train

      # Prepare to inject the words to the training data of the category. Use
      # for high performance.
      #
      # @yield [train] process something
      # @yieldparam [Proc] inject inject the words to the training data of the
      #   category
      ready_for :inject

      # Eject the words from the training data of the category.
      #
      # @param [Array<String>] words an array of words
      alias eject untrain

      # Prepare to eject the words from the training data of the category. Use
      # for high performance.
      #
      # @yield [train] process something
      # @yieldparam [Proc] eject eject the words from the training data of the
      #   category
      ready_for :eject

      # Enhance the training data of other categories giving words.
      #
      # @param [Array<String>] words an array of words
      def train(words)
        @categories.except(@name).inject(words)
      end

      # Attenuate the training data of other categories giving words.
      #
      # @param [Array<String>] words an array of words
      def untrain(words)
        @categories.except(@name).eject(words)
      end
    end
  end
end
