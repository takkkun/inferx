require 'spec_helper'
require 'inferx/category'

describe Inferx::Category, '#initialize' do
  it 'sets key for access to training data of the category to key attribute' do
    category = described_class.new(redis_stub, categories_stub, 'red', 2)
    category.key.should == 'inferx:categories:red'
  end

  it 'sets the category name to name attribute' do
    category = described_class.new(redis_stub, categories_stub, 'red', 2)
    category.name.should == 'red'
  end

  it 'sets the size to size attribute' do
    category = described_class.new(redis_stub, categories_stub, 'red', 2)
    category.size.should == 2
  end
end

describe Inferx::Category, '#all' do
  it 'calls Redis#zrevrange' do
    redis = redis_stub do |s|
      s.should_receive(:zrevrange).with('inferx:categories:red', 0, -1, :withscores => true).and_return([])
    end

    category = described_class.new(redis, categories_stub, 'red', 2)
    category.all
  end

  it 'returns the words with the score' do
    redis = redis_stub do |s|
      s.stub!(:zrevrange).with('inferx:categories:red', 0, -1, :withscores => true).and_return([['apple', 2.0], ['strawberry', 3.0]])
    end

    category = described_class.new(redis, categories_stub, 'red', 2)
    category.all.should == {'apple' => 2, 'strawberry' => 3}
  end

  context 'when return old format' do
    it 'returns the words with the score' do
      redis = redis_stub do |s|
        s.stub!(:zrevrange).with('inferx:categories:red', 0, -1, :withscores => true).and_return(%w(apple 2 strawberry 3))
      end

      category = described_class.new(redis, categories_stub, 'red', 2)
      category.all.should == {'apple' => 2, 'strawberry' => 3}
    end
  end
end

describe Inferx::Category, '#get' do
  it 'calls Redis#zscore' do
    redis = redis_stub do |s|
      s.should_receive(:zscore).with('inferx:categories:red', 'apple')
    end

    category = described_class.new(redis, categories_stub, 'red', 2)
    category.get('apple')
  end

  it 'returns the score as Integer' do
    redis = redis_stub do |s|
      s.stub!(:zscore).with('inferx:categories:red', 'apple').and_return('1')
    end

    category = described_class.new(redis, categories_stub, 'red', 2)
    category.get('apple').should == 1
  end

  context 'with a missing word' do
    it 'returns nil' do
      redis = redis_stub do |s|
        s.stub!(:zscore).with('inferx:categories:red', 'strawberry').and_return(nil)
      end

      category = described_class.new(redis, categories_stub, 'red', 2)
      category.get('strawberry').should be_nil
    end
  end
end

describe Inferx::Category, '#train' do
  before do
    @filtered_categories = categories_stub do |s|
      s.stub!(:inject => {'red' => 5})
    end

    @categories = categories_stub do |s|
      s.stub!(:filter => @filtered_categories)
    end

    @category = described_class.new(redis_stub, @categories, 'red', 2)
  end

  it 'calls Inferx::Categories#filter with the category name' do
    @categories.should_receive(:filter).with('red').and_return(@filtered_categories)
    @category.train(%w(apple strawberry apple strawberry strawberry))
  end

  it 'calls Inferx::Categories#inject with the words' do
    @filtered_categories.should_receive(:inject).with(%w(apple strawberry apple strawberry strawberry)).and_return('red' => 5)
    @category.train(%w(apple strawberry apple strawberry strawberry))
  end

  it 'increases size attribute' do
    @category.train(%w(apple strawberry apple strawberry strawberry))
    @category.size.should == 7
  end
end

describe Inferx::Category, '#ready_to_train' do
  it 'calls #train with the words to train block' do
    category = described_class.new(redis_stub, categories_stub, 'red', 2)
    category.should_receive(:train).with(%w(word1 word2 word3))

    category.ready_to_train do |train|
      train[%w(word1)]
      train[%w(word2)]
      train[%w(word3)]
    end
  end
end

describe Inferx::Category, '#untrain' do
  before do
    @filtered_categories = categories_stub do |s|
      s.stub!(:eject => {'red' => 5})
    end

    @categories = categories_stub do |s|
      s.stub!(:filter => @filtered_categories)
    end

    @category = described_class.new(redis_stub, @categories, 'red', 7)
  end

  it 'calls Inferx::Categories#filter with the category name' do
    @categories.should_receive(:filter).with('red').and_return(@filtered_categories)
    @category.untrain(%w(apple strawberry apple strawberry strawberry))
  end

  it 'calls Inferx::Categories#eject with the words' do
    @filtered_categories.should_receive(:eject).with(%w(apple strawberry apple strawberry strawberry)).and_return('red' => 5)
    @category.untrain(%w(apple strawberry apple strawberry strawberry))
  end

  it 'decreases size attribute' do
    @category.untrain(%w(apple strawberry apple strawberry strawberry))
    @category.size.should == 2
  end
end

describe Inferx::Category, '#ready_to_untrain' do
  it 'calls #untrain with the words to untrain block' do
    category = described_class.new(redis_stub, categories_stub, 'red', 2)
    category.should_receive(:untrain).with(%w(word1 word2 word3))

    category.ready_to_untrain do |untrain|
      untrain[%w(word1)]
      untrain[%w(word2)]
      untrain[%w(word3)]
    end
  end
end

describe Inferx::Category, '#scores' do
  it 'calls Redis#zscore' do
    redis = redis_stub do |s|
      s.should_receive(:zscore).with('inferx:categories:red', 'apple')
      s.should_receive(:zscore).with('inferx:categories:red', 'strawberry')
    end

    category = described_class.new(redis, categories_stub, 'red', 2)
    category.scores(%w(apple strawberry))
  end

  it 'returns the scores' do
    redis = redis_stub do |s|
      s.stub!(:pipelined => %w(2 3))
    end

    category = described_class.new(redis, categories_stub, 'red', 2)
    scores = category.scores(%w(apple strawberry))
    scores.should == [2, 3]
  end
end
