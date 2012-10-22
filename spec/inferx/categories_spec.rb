require 'spec_helper'
require 'inferx/categories'

describe Inferx::Categories do
  it 'includes Enumerable' do
    described_class.should be_include(Enumerable)
  end
end

describe Inferx::Categories, '#initialize' do
  it 'calls Inferx::Adapter#initialize' do
    redis = redis_stub
    categories = described_class.new(redis, :namespace => 'example', :manual => true)
    categories.instance_eval { @redis }.should == redis
    categories.instance_eval { @namespace }.should == 'example'
    categories.should be_manual
  end
end

describe Inferx::Categories, '#all' do
  it 'calls Redis#hkeys' do
    redis = redis_stub do |s|
      s.should_receive(:hkeys).with('inferx:categories')
    end

    categories = described_class.new(redis)
    categories.all
  end

  it 'returns the all categories as Symbol' do
    redis = redis_stub do |s|
      s.stub!(:hkeys).and_return(%w(red green blue))
    end

    categories = described_class.new(redis)
    categories.all.should == [:red, :green, :blue]
  end

  it 'returns an empty array if the key is missing' do
    redis = redis_stub do |s|
      s.stub!(:hkeys).and_return([])
    end

    categories = described_class.new(redis)
    categories.all.should be_empty
  end
end

describe Inferx::Categories, '#get' do
  it 'calls Redis#hget' do
    redis = redis_stub do |s|
      s.should_receive(:hget).with('inferx:categories', :red).and_return('2')
    end

    categories = described_class.new(redis)
    categories.get(:red)
  end

  it 'calles Inferx::Category.new with the instance of Redis, the category name and the options' do
    redis = redis_stub do |s|
      s.stub!(:hget).and_return('2')
    end

    Inferx::Category.should_receive(:new).with(redis, :red, 2, :namespace => 'example', :manual => true)
    categories = described_class.new(redis, :namespace => 'example', :manual => true)
    categories.get(:red)
  end

  it 'returns an instance of Inferx::Category' do
    redis = redis_stub do |s|
      s.stub!(:hget).and_return('2')
    end

    categories = described_class.new(redis)
    categories.get(:red).should be_an(Inferx::Category)
  end

  context 'with a missing category' do
    it 'raises ArgumentError' do
      redis = redis_stub do |s|
        s.stub!(:hget).and_return(nil)
      end

      categories = described_class.new(redis)
      lambda { categories.get(:red) }.should raise_error(ArgumentError, /'red' is missing/)
    end
  end
end

describe Inferx::Categories, '#add' do
  it 'calls Redis#hsetnx' do
    redis = redis_stub do |s|
      s.should_receive(:hsetnx).with('inferx:categories', :red, 0)
      s.should_receive(:save)
    end

    categories = described_class.new(redis)
    categories.add(:red)
  end

  it 'calls Redis#hsetnx according to the number of the categories' do
    redis = redis_stub do |s|
      s.should_receive(:hsetnx).with('inferx:categories', :red, 0)
      s.should_receive(:hsetnx).with('inferx:categories', :green, 0)
      s.should_receive(:save)
    end

    categories = described_class.new(redis)
    categories.add(:red, :green)
  end

  context 'with manual save' do
    it 'does not call Redis#save' do
      redis = redis_stub do |s|
        s.stub(:hsetnx)
        s.should_not_receive(:save)
      end

      categories = described_class.new(redis, :manual => true)
      categories.add(:red)
    end
  end
end

describe Inferx::Categories, '#remove' do
  it 'calls Redis#hdel and Redis#del' do
    redis = redis_stub do |s|
      s.should_receive(:hdel).with('inferx:categories', :red)
      s.should_receive(:del).with('inferx:categories:red')
      s.should_receive(:save)
    end

    categories = described_class.new(redis)
    categories.remove(:red)
  end

  it 'calls Redis#hdel according to the number of the categories' do
    redis = redis_stub do |s|
      s.should_receive(:hdel).with('inferx:categories', :red)
      s.should_receive(:hdel).with('inferx:categories', :green)
      s.should_receive(:del).with('inferx:categories:red', 'inferx:categories:green')
      s.should_receive(:save)
    end

    categories = described_class.new(redis)
    categories.remove(:red, :green)
  end

  context 'with manual save' do
    it 'does not call Redis#save' do
      redis = redis_stub do |s|
        s.stub!(:hdel)
        s.stub!(:del)
        s.should_not_receive(:save)
      end

      categories = described_class.new(redis, :manual => true)
      categories.remove(:red)
    end
  end
end

describe Inferx::Categories, '#each' do
  before do
    @redis = redis_stub do |s|
      s.stub!(:hgetall).and_return(%w(red green blue))
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

describe Inferx::Categories, '#spawn_category' do
  before do
    @categories = described_class.new(redis_stub).tap do |s|
      s.stub!(:spawn => 'category')
    end
  end

  it 'calls #spawn with Inferx::Category and the arguments' do
    @categories.should_receive(:spawn).with(Inferx::Category, 'arg1', 'arg2')
    @categories.__send__(:spawn_category, 'arg1', 'arg2')
  end

  it 'returns the return value from #spawn' do
    @categories.__send__(:spawn_category, 'arg1', 'arg2').should == 'category'
  end
end
