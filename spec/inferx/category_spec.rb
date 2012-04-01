require 'spec_helper'
require 'inferx/category'

describe Inferx::Category, '#initialize' do
  it 'sets the instance of Redis to @redis' do
    redis = redis_stub
    category = described_class.new(redis, :red)
    category.instance_eval { @redis }.should == redis
  end

  it 'sets the category name to @name' do
    category = described_class.new(redis_stub, :red)
    category.instance_eval { @name }.should == :red
  end

  it 'sets "inferx:categories:CATEGORY_NAME" to @key' do
    category = described_class.new(redis_stub, :red)
    category.instance_eval { @key }.should == 'inferx:categories:red'
  end

  it 'sets "inferx:categories:CATEGORY_NAME:size" to @size_key' do
    category = described_class.new(redis_stub, :red)
    category.instance_eval { @size_key }.should == 'inferx:categories:red:size'
  end

  context 'with a namespace' do
    it 'sets "inferx:NAMESPACE:categories:CATEGORY_NAME" to @key' do
      category = described_class.new(redis_stub, :red, 'example')
      category.instance_eval { @key }.should == 'inferx:example:categories:red'
    end

    it 'sets "inferx:NAMESPACE:categories:CATEGORY_NAME:size" to @size_key' do
      category = described_class.new(redis_stub, :red, 'example')
      category.instance_eval { @size_key }.should == 'inferx:example:categories:red:size'
    end
  end
end

describe Inferx::Category, '#all' do
  it 'calls Redis#revrange' do
    redis = redis_stub do |s|
      s.should_receive(:zrevrange).with('inferx:categories:red', 0, -1, :withscores => true).and_return([])
    end

    category = described_class.new(redis, :red)
    category.all
  end

  it 'returns the words with the score' do
    redis = redis_stub do |s|
      s.stub!(:zrevrange).with('inferx:categories:red', 0, -1, :withscores => true).and_return(%w(apple 2 strawberry 3))
    end

    category = described_class.new(redis, :red)
    category.all.should == {'apple' => 2, 'strawberry' => 3}
  end

  context 'with the score option' do
    it 'calls Redis#zrevrangebyscore' do
      redis = redis_stub do |s|
        s.should_receive(:zrevrangebyscore).with('inferx:categories:red', '+inf', 2, :withscores => true).and_return([])
      end

      category = described_class.new(redis, :red)
      category.all(:score => 2)
    end
  end

  context 'with the rank option' do
    it 'calls Redis#zrevrange' do
      redis = redis_stub do |s|
        s.should_receive(:zrevrange).with('inferx:categories:red', 0, 1000, :withscores => true).and_return([])
      end

      category = described_class.new(redis, :red)
      category.all(:rank => 1000)
    end
  end
end

describe Inferx::Category, '#get' do
  it 'calls Redis#zscore' do
    redis = redis_stub do |s|
      s.should_receive(:zscore).with('inferx:categories:red', 'apple')
    end

    category = described_class.new(redis, :red)
    category.get('apple')
  end

  it 'returns the score as Integer' do
    redis = redis_stub do |s|
      s.stub!(:zscore).with('inferx:categories:red', 'apple').and_return('1')
    end

    category = described_class.new(redis, :red)
    category.get('apple').should == 1
  end

  context 'with a missing word' do
    it 'returns nil' do
      redis = redis_stub do |s|
        s.stub!(:zscore).with('inferx:categories:red', 'strawberry').and_return(nil)
      end

      category = described_class.new(redis, :red)
      category.get('strawberry').should be_nil
    end
  end
end

describe Inferx::Category, '#train' do
  it 'calls Redis#zincrby and Redis#incrby' do
    redis = redis_stub do |s|
      s.should_receive(:zincrby).with('inferx:categories:red', 2, 'apple')
      s.should_receive(:zincrby).with('inferx:categories:red', 3, 'strawberry')
      s.should_receive(:incrby).with('inferx:categories:red:size', 5)
    end

    category = described_class.new(redis, :red)
    category.train(%w(apple strawberry apple strawberry strawberry))
  end

  context 'with no update' do
    it 'does not call Redis#incrby' do
      redis = redis_stub do |s|
        s.should_not_receive(:incrby)
      end

      category = described_class.new(redis, :red)
      category.train(%w())
    end
  end
end

describe Inferx::Category, '#untrain' do
  it 'calls Redis#zincrby, Redis#zremrangebyscore and Redis#incrby' do
    redis = redis_stub do |s|
      s.should_receive(:zincrby).with('inferx:categories:red', -2, 'apple')
      s.should_receive(:zincrby).with('inferx:categories:red', -3, 'strawberry')
      s.should_receive(:zremrangebyscore).with('inferx:categories:red', '-inf', 0).and_return(%w(3 -2 1))
      s.should_receive(:incrby).with('inferx:categories:red:size', -3)
    end

    category = described_class.new(redis, :red)
    category.untrain(%w(apple strawberry apple strawberry strawberry))
  end

  context 'with no update' do
    it 'does not call Redis#incrby' do
      redis = redis_stub do |s|
        s.stub!(:zincrby)
        s.stub!(:zremrangebyscore).and_return(%w(-2 -3 2))
        s.should_not_receive(:incrby)
      end

      category = described_class.new(redis, :red)
      category.untrain(%w(apple strawberry apple strawberry strawberry))
    end
  end
end

describe Inferx::Category, '#size' do
  it 'calls Redis#get' do
    redis = redis_stub do |s|
      s.should_receive(:get).with('inferx:categories:red:size')
    end

    category = described_class.new(redis, :red)
    category.size
  end

  it 'returns total of the score of the words as Integer' do
    redis = redis_stub do |s|
      s.stub!(:get).and_return('1')
    end

    category = described_class.new(redis, :red)
    category.size.should == 1
  end

  context 'with the missing key' do
    it 'returns 0' do
      redis = redis_stub do |s|
        s.stub!(:get).and_return(nil)
      end

      category = described_class.new(redis, :red)
      category.size.should == 0
    end
  end
end

describe Inferx::Category, '#scores' do
  it 'calls Redis#zscore' do
    redis = redis_stub do |s|
      s.should_receive(:zscore).with('inferx:categories:red', 'apple')
      s.should_receive(:zscore).with('inferx:categories:red', 'strawberry')
    end

    category = described_class.new(redis, :red)
    category.scores(%w(apple strawberry))
  end

  it 'returns the scores' do
    redis = redis_stub do |s|
      s.stub!(:pipelined).and_return(%w(2 3))
    end

    category = described_class.new(redis, :red)
    scores = category.scores(%w(apple strawberry))
    scores.should == [2, 3]
  end

  context 'with words with scores' do
    it 'returns the scores to use the cache' do
      redis = redis_stub do |s|
        s.should_not_receive(:zscore).with('inferx:categories:red', 'strawberry')
        s.stub!(:pipelined).and_return { |&block| block.call; [2] }
      end

      category = described_class.new(redis, :red)
      scores = category.scores(%w(apple strawberry), 'strawberry' => 3, 'hoge' => 1)
      scores.should == [2, 3]
    end
  end
end
