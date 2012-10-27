require 'spec_helper'
require 'inferx/categories'

describe Inferx::Categories do
  it 'includes Enumerable' do
    described_class.should be_include(Enumerable)
  end
end

describe Inferx::Categories, '#initialize' do
  before do
    @categories = described_class.new(redis_stub)
  end

  it 'sets "inferx:categories" to key attribute by default' do
    @categories.key.should == 'inferx:categories'
  end

  it 'is not manual save by default' do
    @categories.should_not be_manual
  end

  context 'with :namespace option' do
    it 'considers the value to key attribute' do
      categories = described_class.new(redis_stub, :namespace => 'example')
      categories.key.should == 'inferx:example:categories'
    end
  end

  context 'with :manual option' do
    it 'is manual save if the value is true' do
      categories = described_class.new(redis_stub, :manual => true)
      categories.should be_manual
    end

    it 'is not manual save if the value is false' do
      categories = described_class.new(redis_stub, :manual => false)
      categories.should_not be_manual
    end
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

  it 'calles Inferx::Category.new with the instance of Redis and the category name' do
    categories = described_class.new(@redis)
    Inferx::Category.should_receive(:new).with(@redis, 'red', 2, categories)
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

describe Inferx::Categories, '#inject' do
  before do
    @redis = redis_stub do |s|
      s.stub!(:hkeys => %w(red green blue))
      s.stub!(:zincrby)
      s.stub!(:hincrby)
    end

    @categories = described_class.new(@redis).filter('red', 'green')
  end

  it 'calls Redis#zincrby and Redis#hincrby for the categories' do
    @redis.tap do |s|
      s.should_receive(:zincrby).with('inferx:categories:red', 2, 'apple')
      s.should_receive(:zincrby).with('inferx:categories:red', 3, 'strawberry')
      s.should_receive(:hincrby).with('inferx:categories', 'red', 5)

      s.should_receive(:zincrby).with('inferx:categories:green', 2, 'apple')
      s.should_receive(:zincrby).with('inferx:categories:green', 3, 'strawberry')
      s.should_receive(:hincrby).with('inferx:categories', 'green', 5)

      s.should_not_receive(:zincrby).with('inferx:categories:blue', 2, 'apple')
      s.should_not_receive(:zincrby).with('inferx:categories:blue', 3, 'strawberry')
      s.should_not_receive(:hincrby).with('inferx:categories', 'blue', 5)

      s.should_receive(:save)
    end

    @categories.inject(%w(apple strawberry apple strawberry strawberry))
  end

  it 'returns an instance of Hash' do
    increases = @categories.inject(%w(apple strawberry apple strawberry strawberry))
    increases.should be_a(Hash)
  end

  it 'returns increase for each category' do
    increases = @categories.inject(%w(apple strawberry apple strawberry strawberry))
    increases.should == {'red' => 5, 'green' => 5}
  end

  context 'with empty categories' do
    it 'returns an empty hash' do
      categories = @categories.except('red', 'green')
      increases = categories.inject(%w(apple strawberry apple strawberry strawberry))
      increases.should be_empty
    end
  end

  context 'with empty words' do
    it 'returns zero fluctuation' do
      increases = @categories.inject([])
      increases.should == {'red' => 0, 'green' => 0}
    end
  end

  context 'with manual save' do
    it 'does not call Redis#save' do
      @redis.tap do |s|
        s.should_not_receive(:save)
      end

      categories = described_class.new(@redis, :manual => true)
      categories.inject(%w(apple strawberry apple strawberry strawberry))
    end
  end
end

describe Inferx::Categories, '#eject' do
  before do
    @redis = redis_stub do |s|
      s.stub!(:hkeys => %w(red green blue))

      s.stub!(:pipelined).and_return do |&block|
        block.call
        %w(3 2 0) + %w(3 2 0)
      end

      s.stub!(:zincrby)
      s.stub!(:zremrangebyscore)
      s.stub!(:hincrby)
    end

    @categories = described_class.new(@redis).filter('red', 'green')
  end

  it 'calls Redis#zincrby, Redis#zremrangebyscore and Redis#hincrby for the categories' do
    @redis.tap do |s|
      s.should_receive(:zincrby).with('inferx:categories:red', -2, 'apple')
      s.should_receive(:zincrby).with('inferx:categories:red', -3, 'strawberry')
      s.should_receive(:zremrangebyscore).with('inferx:categories:red', '-inf', 0)
      s.should_receive(:hincrby).with('inferx:categories', 'red', -5)

      s.should_receive(:zincrby).with('inferx:categories:green', -2, 'apple')
      s.should_receive(:zincrby).with('inferx:categories:green', -3, 'strawberry')
      s.should_receive(:zremrangebyscore).with('inferx:categories:green', '-inf', 0)
      s.should_receive(:hincrby).with('inferx:categories', 'green', -5)

      s.should_not_receive(:zincrby).with('inferx:categories:blue', 2, 'apple')
      s.should_not_receive(:zincrby).with('inferx:categories:blue', 3, 'strawberry')
      s.should_not_receive(:zremrangebyscore).with('inferx:categories:blue', '-inf', 0)
      s.should_not_receive(:hincrby).with('inferx:categories', 'blue', 5)

      s.should_receive(:save)
    end

    @categories.eject(%w(apple strawberry apple strawberry strawberry))
  end

  it 'returns an instance of Hash' do
    decreases = @categories.eject(%w(apple strawberry apple strawberry strawberry))
    decreases.should be_a(Hash)
  end

  it 'returns decrease for each category' do
    decreases = @categories.eject(%w(apple strawberry apple strawberry strawberry))
    decreases.should == {'red' => 5, 'green' => 5}
  end

  it 'adjusts decrease' do
    @redis.tap do |s|
      s.stub!(:pipelined).and_return do |&block|
        block.call
        %w(3 2 0) + %w(-1 -2 2)
      end

      s.should_receive(:hincrby).with('inferx:categories', 'green', -2)
    end

    decreases = @categories.eject(%w(apple strawberry apple strawberry strawberry))
    decreases.should == {'red' => 5, 'green' => 2}
  end

  context 'with empty categories' do
    it 'returns an empty hash' do
      categories = @categories.except('red', 'green')
      decreases = categories.eject(%w(apple strawberry apple strawberry strawberry))
      decreases.should be_empty
    end
  end

  context 'with empty words' do
    it 'returns zero fluctuation' do
      decreases = @categories.eject([])
      decreases.should == {'red' => 0, 'green' => 0}
    end
  end

  context 'with manual save' do
    it 'does not call Redis#save' do
      @redis.tap do |s|
        s.should_not_receive(:save)
      end

      categories = described_class.new(@redis, :manual => true)
      categories.eject(%w(apple strawberry apple strawberry strawberry))
    end
  end
end
