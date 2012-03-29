require 'inferx/version'
require 'inferx/storage'

class Inferx
  class MissingCategory < StandardError
    def initialize(category)
      super "\"#{category}\" category is missing"
    end
  end

  def initialize(options = {})
    @storage = Storage.new(options)
    @categories = @storage.load
    @manual = !!options[:manual]
  end

  attr_writer :manual

  def manual?
    @manual
  end

  def categories
    @categories.keys
  end

  def frequency(category)
    @categories[category.to_sym]
  end

  def add(*categories)
    update_category(categories) do |category|
      next if @categories.key?(category)
      @categories[category] = {}
    end
  end

  def remove(*categories)
    update_category(categories) do |category|
      next unless @categories.key?(category)
      @categories.delete(category)
    end
  end

  def train(category, frequency)
    update_frequency(category, frequency) do |f, word, count|
      f[word] ||= 0
      f[word] += count
      count
    end
  end

  def untrain(category, frequency)
    update_frequency(category, frequency) do |f, word, count|
      next 0 unless f.key?(word)

      if f[word] <= count
        count = f.delete(word)
      else
        f[word] -= count
      end

      -count
    end
  end

  def classifications(words)
    @categories.inject({}) do |scores, pair|
      category, frequency = pair
      total = frequency.inject(0) { |count, pair| count + pair[1] }.to_f

      scores[category] = words.inject(0) do |score, word|
        score + Math.log((frequency[word] || 0.1) / total)
      end

      scores
    end
  end

  def classify(words)
    classifications(words).max_by { |score| score[1] }[0]
  end

  def save
    @storage.save(@categories)
  end

  private

  def update_category(categories)
    updated = categories.inject(false) do |updated, category|
      # If you used || operator in the following code, the block does not
      # called for short circuit.
      updated | yield(category.to_sym)
    end

    save if updated and !manual?
  end

  def update_frequency(category, frequency)
    f = @categories[category.to_sym]
    raise MissingCategory, category unless f
    count = frequency.inject(0) { |count, pair| count + yield(f, *pair) }
    save if count != 0 and !manual?
  end
end
