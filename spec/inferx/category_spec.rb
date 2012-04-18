require 'spec_helper'
require 'inferx/category'

describe Inferx::Category, '#initialize' do
  it 'calls Inferx::Adapter#initialize' do
    redis = redis_stub
    category = described_class.new(redis, :red, :namespace => 'example', :manual => true)
    category.instance_eval { @redis }.should == redis
    category.instance_eval { @namespace }.should == 'example'
    category.should be_manual
  end

  it 'sets the category name to the name attribute' do
    category = described_class.new(redis_stub, :red)
    category.name.should == :red
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
  it 'calls Redis#zincrby and Redis#hincrby' do
    redis = redis_stub do |s|
      s.should_receive(:zincrby).with('inferx:categories:red', 2, 'apple')
      s.should_receive(:zincrby).with('inferx:categories:red', 3, 'strawberry')
      s.should_receive(:hincrby).with('inferx:categories', :red, 5)
      s.should_receive(:save)
    end

    category = described_class.new(redis, :red)
    category.train(%w(apple strawberry apple strawberry strawberry))
  end

  context 'with no update' do
    it 'does not call Redis#hincrby' do
      redis = redis_stub do |s|
        s.should_not_receive(:hincrby)
        s.should_not_receive(:save)
      end

      category = described_class.new(redis, :red)
      category.train(%w())
    end
  end

  context 'with manual save' do
    it 'does not call Redis#save' do
      redis = redis_stub do |s|
        s.stub!(:zincrby)
        s.stub!(:hincrby)
        s.should_not_receive(:save)
      end

      category = described_class.new(redis, :red, :manual => true)
      category.train(%w(apple strawberry apple strawberry strawberry))
    end
  end
end

describe Inferx::Category, '#untrain' do
  it 'calls Redis#zincrby, Redis#zremrangebyscore and Redis#hincrby' do
    redis = redis_stub do |s|
      s.should_receive(:zincrby).with('inferx:categories:red', -2, 'apple')
      s.should_receive(:zincrby).with('inferx:categories:red', -3, 'strawberry')
      s.should_receive(:zremrangebyscore).with('inferx:categories:red', '-inf', 0).and_return(%w(3 -2 1))
      s.should_receive(:hincrby).with('inferx:categories', :red, -3)
      s.should_receive(:save)
    end

    category = described_class.new(redis, :red)
    category.untrain(%w(apple strawberry apple strawberry strawberry))
  end

  context 'with no update' do
    it 'does not call Redis#hincrby' do
      redis = redis_stub do |s|
        s.stub!(:zincrby)
        s.stub!(:zremrangebyscore).and_return(%w(-2 -3 2))
        s.should_not_receive(:hincrby)
        s.should_not_receive(:save)
      end

      category = described_class.new(redis, :red)
      category.untrain(%w(apple strawberry apple strawberry strawberry))
    end
  end

  context 'with manual save' do
    it 'does not call Redis#save' do
      redis = redis_stub do |s|
        s.stub!(:zincrby)
        s.stub!(:zremrangebyscore).and_return(%w(3 -2 1))
        s.stub!(:hincrby)
        s.should_not_receive(:save)
      end

      category = described_class.new(redis, :red, :manual => true)
      category.untrain(%w(apple strawberry apple strawberry strawberry))
    end
  end
end

describe Inferx::Category, '#size' do
  it 'calls Redis#hget' do
    redis = redis_stub do |s|
      s.should_receive(:hget).with('inferx:categories', :red)
    end

    category = described_class.new(redis, :red)
    category.size
  end

  it 'returns total of the score of the words as Integer' do
    redis = redis_stub do |s|
      s.stub!(:hget).and_return('1')
    end

    category = described_class.new(redis, :red)
    category.size.should == 1
  end

  context 'with the missing key' do
    it 'returns 0' do
      redis = redis_stub do |s|
        s.stub!(:hget).and_return(nil)
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
end
