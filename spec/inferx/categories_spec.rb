require 'spec_helper'
require 'inferx/categories'

describe Inferx::Categories do
  it 'includes Enumerable' do
    described_class.should be_include(Enumerable)
  end
end

describe Inferx::Categories, '#initialize' do
  it 'sets the instance of Redis to @redis' do
    redis = redis_stub
    categories = described_class.new(redis)
    categories.instance_eval { @redis }.should == redis
  end

  it 'sets "inferx:categories" to @key' do
    categories = described_class.new(redis_stub)
    categories.instance_eval { @key }.should == 'inferx:categories'
  end

  context 'with a namespace' do
    it 'sets the namespace to @namespace' do
      categories = described_class.new(redis_stub, 'example')
      categories.instance_eval { @namespace }.should == 'example'
    end

    it 'sets "inferx:NAMESPACE:categories" to @key' do
      categories = described_class.new(redis_stub, 'example')
      categories.instance_eval { @key }.should == 'inferx:example:categories'
    end
  end
end

describe Inferx::Categories, '#all' do
  it 'calls Redis#smembers' do
    redis = redis_stub do |s|
      s.should_receive(:smembers).with('inferx:categories')
    end

    categories = described_class.new(redis)
    categories.all
  end

  it 'returns the all categories as Symbol' do
    redis = redis_stub do |s|
      s.stub!(:smembers).and_return(%w(red green blue))
    end

    categories = described_class.new(redis)
    categories.all.should == [:red, :green, :blue]
  end

  it 'returns an empty array if the key is missing' do
    redis = redis_stub do |s|
      s.stub!(:smembers).and_return(nil)
    end

    categories = described_class.new(redis)
    categories.all.should be_empty
  end
end

describe Inferx::Categories, '#get' do
  it 'calls Redis#sismember' do
    redis = redis_stub do |s|
      s.should_receive(:sismember).with('inferx:categories', :red).and_return(true)
    end

    categories = described_class.new(redis)
    categories.get(:red)
  end

  it 'calles Inferx::Category.new with the instance of Redis, the category name and the namepsace' do
    redis = redis_stub do |s|
      s.stub!(:sismember).and_return(true)
    end

    Inferx::Category.should_receive(:new).with(redis, :red, 'example')
    categories = described_class.new(redis, 'example')
    categories.get(:red)
  end

  it 'returns an instance of Inferx::Category' do
    redis = redis_stub do |s|
      s.stub!(:sismember).and_return(true)
    end

    categories = described_class.new(redis)
    categories.get(:red).should be_an(Inferx::Category)
  end

  context 'with a missing category' do
    it 'raises ArgumentError' do
      redis = redis_stub do |s|
        s.stub!(:sismember).and_return(false)
      end

      categories = described_class.new(redis)
      lambda { categories.get(:red) }.should raise_error(ArgumentError, /'red' is missing/)
    end
  end
end

describe Inferx::Categories, '#add' do
  it 'calls Redis#sadd' do
    redis = redis_stub do |s|
      s.should_receive(:sadd).with('inferx:categories', :red)
    end

    categories = described_class.new(redis)
    categories.add(:red)
  end

  it 'calls Redis#sadd according to the number of the categories' do
    redis = redis_stub do |s|
      s.should_receive(:sadd).with('inferx:categories', :red)
      s.should_receive(:sadd).with('inferx:categories', :green)
    end

    categories = described_class.new(redis)
    categories.add(:red, :green)
  end
end

describe Inferx::Categories, '#remove' do
  it 'calls Redis#srem and Redis#del' do
    redis = redis_stub do |s|
      s.should_receive(:srem).with('inferx:categories', :red)
      s.should_receive(:del).with(*%w(inferx:categories:red inferx:categories:red:size))
    end

    categories = described_class.new(redis)
    categories.remove(:red)
  end

  it 'calls Redis#srem according to the number of the categories' do
    redis = redis_stub do |s|
      s.should_receive(:srem).with('inferx:categories', :red)
      s.should_receive(:srem).with('inferx:categories', :green)
      s.should_receive(:del).with(*%w(inferx:categories:red inferx:categories:red:size inferx:categories:green inferx:categories:green:size))
    end

    categories = described_class.new(redis)
    categories.remove(:red, :green)
  end
end

describe Inferx::Categories, '#each' do
  before do
    @redis = redis_stub do |s|
      s.stub!(:smembers).and_return(%w(red green blue))
    end
  end

  it 'passes an instance of Inferx::Category to the block' do
    categories = described_class.new(@redis)
    categories.each { |category| category.should be_an(Inferx::Category) }
  end

  it 'calls the block according to the number of the categories' do
    n = 0
    categories = described_class.new(@redis)
    categories.each { |category| n += 1 }
    n.should == 3
  end
end
