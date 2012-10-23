require 'inferx/category'

class Inferx
  module Complementary
    class Category < Inferx::Category

      # Inject the words to the training data of the category.
      #
      # @param [Array<String>] words an array of words
      alias inject train

      # Eject the words from the training data of the category.
      #
      # @param [Array<String>] words an array of words
      alias eject untrain

      # Prepare to inject the words to the training data of the category. Use
      # for high performance.
      #
      # @yield [train] process something
      # @yieldparam [Proc] inject inject the words to the training data of the
      #   category
      ready_for :inject

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
        return if words.empty?

        increase = words.size
        words = collect(words)

        category_names = get_other_category_names
        return if category_names.empty?

        @redis.pipelined do
          category_names.each do |category_name|
            category_key = make_category_key(category_name)
            words.each { |word, count| @redis.zincrby(category_key, count, word) }
            hincrby(category_name, increase)
          end

          @redis.save unless manual?
        end
      end

      # Attenuate the training data of other categories giving words.
      #
      # @param [Array<String>] words an array of words
      def untrain(words)
        return if words.empty?

        decrease = words.size
        words = collect(words)

        category_names = get_other_category_names
        return if category_names.empty?

        scores = @redis.pipelined do
          category_names.each do |category_name|
            category_key = make_category_key(category_name)
            words.each { |word, count| @redis.zincrby(category_key, -count, word) }
            @redis.zremrangebyscore(category_key, '-inf', 0)
          end
        end

        length = words.size
        decreases_by_category = {}

        category_names.each_with_index do |category_name, index|
          decrease_by_category = decrease

          scores[index * (length + 1), length].each do |score|
            score = score.to_i
            decrease_by_category += score if score < 0
          end

          decreases_by_category[category_name] = decrease_by_category if decrease_by_category > 0
        end

        return if decreases_by_category.empty?

        @redis.pipelined do
          decreases_by_category.each do |category_name, decrease|
            hincrby(category_name, -decrease)
          end

          @redis.save unless manual?
        end
      end

      private

      def get_other_category_names
        hkeys.reject { |category_name| category_name == name }
      end
    end
  end
end
