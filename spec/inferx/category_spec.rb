require 'spec_helper'
require 'inferx/category'

describe Inferx::Category, '#initialize' do
  it 'calls Inferx::Adapter#initialize' do
    redis = redis_stub
    category = described_class.new(redis, 'red', 2, :namespace => 'example', :manual => true)
    category.instance_eval { @redis }.should == redis
    category.instance_eval { @namespace }.should == 'example'
    category.should be_manual
  end

  it 'sets the category name to the name attribute' do
    category = described_class.new(redis_stub, 'red', 2)
    category.name.should == 'red'
  end

  it 'sets the size to the size attribute' do
    category = described_class.new(redis_stub, 'red', 2)
    category.size.should == 2
  end
end

describe Inferx::Category, '#all' do
  it 'calls Redis#zrevrange' do
    redis = redis_stub do |s|
      s.should_receive(:zrevrange).with('inferx:categories:red', 0, -1, :withscores => true).and_return([])
    end

    category = described_class.new(redis, 'red', 2)
    category.all
  end

  it 'returns the words with the score' do
    redis = redis_stub do |s|
      s.stub!(:zrevrange).with('inferx:categories:red', 0, -1, :withscores => true).and_return(%w(apple 2 strawberry 3))
    end

    category = described_class.new(redis, 'red', 2)
    category.all.should == {'apple' => 2, 'strawberry' => 3}
  end
end

describe Inferx::Category, '#get' do
  it 'calls Redis#zscore' do
    redis = redis_stub do |s|
      s.should_receive(:zscore).with('inferx:categories:red', 'apple')
    end

    category = described_class.new(redis, 'red', 2)
    category.get('apple')
  end

  it 'returns the score as Integer' do
    redis = redis_stub do |s|
      s.stub!(:zscore).with('inferx:categories:red', 'apple').and_return('1')
    end

    category = described_class.new(redis, 'red', 2)
    category.get('apple').should == 1
  end

  context 'with a missing word' do
    it 'returns nil' do
      redis = redis_stub do |s|
        s.stub!(:zscore).with('inferx:categories:red', 'strawberry').and_return(nil)
      end

      category = described_class.new(redis, 'red', 2)
      category.get('strawberry').should be_nil
    end
  end
end

describe Inferx::Category, '#train' do
  it 'calls Redis#zincrby and Redis#hincrby' do
    redis = redis_stub do |s|
      s.should_receive(:zincrby).with('inferx:categories:red', 2, 'apple')
      s.should_receive(:zincrby).with('inferx:categories:red', 3, 'strawberry')
      s.should_receive(:hincrby).with('inferx:categories', 'red', 5)
      s.should_receive(:save)
    end

    category = described_class.new(redis, 'red', 2)
    category.train(%w(apple strawberry apple strawberry strawberry))
  end

  it 'increases the size attribute' do
    redis = redis_stub do |s|
      s.stub!(:zincrby)
      s.stub!(:hincrby)
    end

    category = described_class.new(redis, 'red', 2)
    category.train(%w(apple strawberry apple strawberry strawberry))
    category.size.should == 7
  end

  context 'with no update' do
    it 'does not call Redis#hincrby' do
      redis = redis_stub do |s|
        s.should_not_receive(:hincrby)
        s.should_not_receive(:save)
      end

      category = described_class.new(redis, 'red', 2)
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

      category = described_class.new(redis, 'red', 2, :manual => true)
      category.train(%w(apple strawberry apple strawberry strawberry))
    end
  end
end

describe Inferx::Category, '#ready_to_train' do
  it 'calls #train with the words to train block' do
    category = described_class.new(redis_stub, 'red', 2)
    category.should_receive(:train).with(%w(word1 word2 word3))

    category.ready_to_train do |train|
      train[%w(word1)]
      train[%w(word2)]
      train[%w(word3)]
    end
  end
end

describe Inferx::Category, '#untrain' do
  it 'calls Redis#zincrby, Redis#zremrangebyscore and Redis#hincrby' do
    redis = redis_stub do |s|
      s.stub!(:pipelined).and_return do |&block|
        block.call
        %w(3 -2 1)
      end

      s.should_receive(:zincrby).with('inferx:categories:red', -2, 'apple')
      s.should_receive(:zincrby).with('inferx:categories:red', -3, 'strawberry')
      s.should_receive(:zremrangebyscore).with('inferx:categories:red', '-inf', 0)
      s.should_receive(:hincrby).with('inferx:categories', 'red', -3)
      s.should_receive(:save)
    end

    category = described_class.new(redis, 'red', 7)
    category.untrain(%w(apple strawberry apple strawberry strawberry))
  end

  it 'decreases the size attribute' do
    redis = redis_stub do |s|
      s.stub!(:pipelined).and_return do |&block|
        block.call
        %w(3 -2 1)
      end

      s.stub!(:zincrby)
      s.stub!(:zremrangebyscore)
      s.stub!(:hincrby)
    end

    category = described_class.new(redis, 'red', 7)
    category.untrain(%w(apple strawberry apple strawberry strawberry))
    category.size.should == 4
  end

  context 'with no update' do
    it 'does not call Redis#zremrangebyscore and Redis#hincrby' do
      redis = redis_stub do |s|
        s.stub!(:pipelined).and_return do |&block|
          block.call
          %w(-2 -3 2)
        end

        s.stub!(:zincrby)
        s.should_not_receive(:zremrangebyscore)
        s.should_not_receive(:hincrby)
        s.should_not_receive(:save)
      end

      category = described_class.new(redis, 'red', 7)
      category.untrain(%w(apple strawberry apple strawberry strawberry))
    end
  end

  context 'with manual save' do
    it 'does not call Redis#save' do
      redis = redis_stub do |s|
        s.stub!(:pipelined).and_return do |&block|
          block.call
          %w(3 -2 1)
        end

        s.stub!(:zincrby)
        s.stub!(:zremrangebyscore)
        s.stub!(:hincrby)
        s.should_not_receive(:save)
      end

      category = described_class.new(redis, 'red', 7, :manual => true)
      category.untrain(%w(apple strawberry apple strawberry strawberry))
    end
  end
end

describe Inferx::Category, '#ready_to_untrain' do
  it 'calls #untrain with the words to untrain block' do
    category = described_class.new(redis_stub, 'red', 2)
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

    category = described_class.new(redis, 'red', 2)
    category.scores(%w(apple strawberry))
  end

  it 'returns the scores' do
    redis = redis_stub do |s|
      s.stub!(:pipelined).and_return(%w(2 3))
    end

    category = described_class.new(redis, 'red', 2)
    scores = category.scores(%w(apple strawberry))
    scores.should == [2, 3]
  end
end
