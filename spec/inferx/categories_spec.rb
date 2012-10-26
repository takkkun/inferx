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

describe Inferx::Categories, '#filter' do
  before do
    redis = redis_stub do |s|
      s.stub!(:hkeys => %w(red green blue))
    end

    @categories = described_class.new(redis)
  end

  it "returns an instance of #{described_class}" do
    categories = @categories.filter('red', 'green')
    categories.should be_an(described_class)
  end

  it 'returns an instance that is different from their own' do
    categories = @categories.filter('red', 'green')
    categories.object_id.should_not == @categories.object_id
  end

  it 'returns categories filtered by the category names' do
    categories = @categories.filter('red', 'green')
    categories.all.should == %w(red green)
  end

  context 'when calling many times' do
    it 'returns categories filtered by the collective category names' do
      categories = @categories.filter('red', 'green').filter('green')
      categories.all.should == %w(green)
    end
  end
end

describe Inferx::Categories, '#except' do
  before do
    redis = redis_stub do |s|
      s.stub!(:hkeys => %w(red green blue))
    end

    @categories = described_class.new(redis)
  end

  it "returns an instance of #{described_class}" do
    categories = @categories.except('red')
    categories.should be_an(described_class)
  end

  it 'returns an instance that is different from their own' do
    categories = @categories.except('red')
    categories.object_id.should_not == @categories.object_id
  end

  it 'returns categories filtered by the category names' do
    categories = @categories.except('red')
    categories.all.should == %w(green blue)
  end

  context 'when calling many times' do
    it 'returns categories filtered by the successive category names' do
      categories = @categories.except('red').except('green')
      categories.all.should == %w(blue)
    end
  end
end

describe Inferx::Categories, '#all' do
  before do
    @redis = redis_stub do |s|
      s.stub!(:hkeys => %w(red green blue))
    end

    @categories = described_class.new(@redis)
  end

  it 'calls Redis#hkeys' do
    @redis.should_receive(:hkeys).with('inferx:categories')
    @categories.all
  end

  it 'returns an instance of Array' do
    @categories.all.should be_an(Array)
  end

  it 'returns an empty array if the key is missing' do
    @redis.stub!(:hkeys => nil)
    @categories.all.should be_empty
  end

  context 'when filtered' do
    it 'returns filtered category names' do
      categories = @categories.filter('red', 'green').except('red')
      categories.all.should == %w(green)
    end
  end
end

describe Inferx::Categories, '#get' do
  before do
    @redis = redis_stub do |s|
      s.stub!(:hget => '2', :hkeys => %w(red green blue))
    end
  end

  it 'calls Redis#hget' do
    @redis.should_receive(:hget).with('inferx:categories', 'red').and_return('2')
    categories = described_class.new(@redis)
    categories.get('red')
  end

  it 'calles Inferx::Category.new with the instance of Redis, the category name and the options' do
    categories = described_class.new(@redis, :namespace => 'example', :manual => true)
    Inferx::Category.should_receive(:new).with(@redis, 'red', 2, categories, :namespace => 'example', :manual => true)
    categories.get('red')
  end

  it 'returns an instance of Inferx::Category' do
    categories = described_class.new(@redis)
    categories.get('red').should be_an(Inferx::Category)
  end

  context 'with a missing category' do
    it 'raises ArgumentError' do
      @redis.stub!(:hget => nil)
      categories = described_class.new(@redis)
      lambda { categories.get('red') }.should raise_error(ArgumentError, /"red" is missing/)
    end
  end

  context 'when filtered' do
    it 'raises ArgumentError if the category is not defined in filtered categories' do
      categories = described_class.new(@redis)
      categories = categories.filter('red', 'green').except('red')
      lambda { categories.get('red') }.should raise_error(ArgumentError, '"red" does not exist in filtered categories')
    end
  end

  context 'when construct with :complementary option' do
    it 'returns an instance of Inferx::Category::Complementary' do
      categories = described_class.new(@redis, :complementary => true)
      categories.get('red').should be_an(Inferx::Category::Complementary)
    end
  end
end

describe Inferx::Categories, '#add' do
  it 'calls Redis#hsetnx' do
    redis = redis_stub do |s|
      s.should_receive(:hsetnx).with('inferx:categories', 'red', 0)
      s.should_receive(:save)
    end

    categories = described_class.new(redis)
    categories.add('red')
  end

  it 'calls Redis#hsetnx according to the number of the categories' do
    redis = redis_stub do |s|
      s.should_receive(:hsetnx).with('inferx:categories', 'red', 0)
      s.should_receive(:hsetnx).with('inferx:categories', 'green', 0)
      s.should_receive(:save)
    end

    categories = described_class.new(redis)
    categories.add('red', 'green')
  end

  context 'with manual save' do
    it 'does not call Redis#save' do
      redis = redis_stub do |s|
        s.stub(:hsetnx)
        s.should_not_receive(:save)
      end

      categories = described_class.new(redis, :manual => true)
      categories.add('red')
    end
  end
end

describe Inferx::Categories, '#remove' do
  it 'calls Redis#hdel and Redis#del' do
    redis = redis_stub do |s|
      s.should_receive(:hdel).with('inferx:categories', 'red')
      s.should_receive(:del).with('inferx:categories:red')
      s.should_receive(:save)
    end

    categories = described_class.new(redis)
    categories.remove('red')
  end

  it 'calls Redis#hdel according to the number of the categories' do
    redis = redis_stub do |s|
      s.should_receive(:hdel).with('inferx:categories', 'red')
      s.should_receive(:hdel).with('inferx:categories', 'green')
      s.should_receive(:del).with('inferx:categories:red', 'inferx:categories:green')
      s.should_receive(:save)
    end

    categories = described_class.new(redis)
    categories.remove('red', 'green')
  end

  context 'with manual save' do
    it 'does not call Redis#save' do
      redis = redis_stub do |s|
        s.stub!(:hdel)
        s.stub!(:del)
        s.should_not_receive(:save)
      end

      categories = described_class.new(redis, :manual => true)
      categories.remove('red')
    end
  end
end

describe Inferx::Categories, '#exists?' do
  before do
    redis = redis_stub.tap do |s|
      s.stub!(:hkeys => %w(red green blue))
    end

    @categories = described_class.new(redis)
  end

  it 'returns true if the category is defined' do
    @categories.should be_exists('red')
  end

  it 'returns false if the category is not defined' do
    @categories.should_not be_exists('cyan')
  end

  context 'when filtered' do
    it 'returns true if the category is defined in filtered categories' do
      categories = @categories.filter('red', 'green').except('red')
      categories.should be_exists('green')
    end

    it 'returns false if the category is not defined in filtered categories' do
      categories = @categories.filter('red', 'green').except('red')
      categories.should_not be_exists('red')
    end
  end
end

describe Inferx::Categories, '#each' do
  before do
    @redis = redis_stub do |s|
      s.stub!(:hkeys => %w(red green blue), :hgetall => {
        'red'   => 2,
        'green' => 3,
        'blue'  => 1
      })
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

  context 'when filtered' do
    it 'passes an instance of Inferx::Category in filtered categories to the block' do
      categories = described_class.new(@redis)
      categories = categories.filter('red', 'green').except('red')
      category_names = []
      categories.each { |category| category_names << category.name }
      category_names.should == %w(green)
    end
  end

  context 'when construct with :complementary option' do
    it 'passes an instance of Inferx::Category::Complementary to the block' do
      categories = described_class.new(@redis, :complementary => true)
      categories.each { |category| category.should be_an(Inferx::Category::Complementary) }
    end
  end
end
