require 'spec_helper'
require 'inferx/category/complementary'

describe Inferx::Category::Complementary, '#ready_to_inject' do
  it 'calls #inject with the words to inject block' do
    category = described_class.new(redis_stub, categories_stub, 'red', 2)
    category.should_receive(:inject).with(%w(word1 word2 word3))

    category.ready_to_inject do |inject|
      inject[%w(word1)]
      inject[%w(word2)]
      inject[%w(word3)]
    end
  end
end

describe Inferx::Category::Complementary, '#ready_to_eject' do
  it 'calls #eject with the words to eject block' do
    category = described_class.new(redis_stub, categories_stub, 'red', 2)
    category.should_receive(:eject).with(%w(word1 word2 word3))

    category.ready_to_eject do |eject|
      eject[%w(word1)]
      eject[%w(word2)]
      eject[%w(word3)]
    end
  end
end

describe Inferx::Category::Complementary, '#train' do
  before do
    @filtered_categories = categories_stub do |s|
      s.stub!(:inject => {'red' => 5})
    end

    @categories = categories_stub do |s|
      s.stub!(:except => @filtered_categories)
    end

    @category = described_class.new(redis_stub, @categories, 'red', 2)
  end

  it 'calls Inferx::Categories#except with the category name' do
    @categories.should_receive(:except).with('red').and_return(@filtered_categories)
    @category.train(%w(apple strawberry apple strawberry strawberry))
  end

  it 'calls Inferx::Categories#inject with the words' do
    @filtered_categories.should_receive(:inject).with(%w(apple strawberry apple strawberry strawberry)).and_return('red' => 5)
    @category.train(%w(apple strawberry apple strawberry strawberry))
  end
end

describe Inferx::Category::Complementary, '#untrain' do
  before do
    @filtered_categories = categories_stub do |s|
      s.stub!(:eject => {'red' => 5})
    end

    @categories = categories_stub do |s|
      s.stub!(:except => @filtered_categories)
    end

    @category = described_class.new(redis_stub, @categories, 'red', 7)
  end

  it 'calls Inferx::Categories#except with the category name' do
    @categories.should_receive(:except).with('red').and_return(@filtered_categories)
    @category.untrain(%w(apple strawberry apple strawberry strawberry))
  end

  it 'calls Inferx::Categories#eject with the words' do
    @filtered_categories.should_receive(:eject).with(%w(apple strawberry apple strawberry strawberry)).and_return('red' => 5)
    @category.untrain(%w(apple strawberry apple strawberry strawberry))
  end
end
