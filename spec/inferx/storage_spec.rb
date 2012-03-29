require 'spec_helper'
require 'inferx/storage'

describe Inferx::Storage, '#initialize' do
  it 'passes the options to Redis.new' do
    Redis.should_receive(:new).with(:db => 1)
    described_class.new(:db => 1)
  end

  it 'sets "inferx" to the namespace attribute' do
    storage = described_class.new
    storage.namespace.should == 'inferx'
  end

  context 'with a namespace' do
    it 'sets "inferx" and the namespace to the namespace attribute' do
      storage = described_class.new(:namespace => 'example')
      storage.namespace.should == 'inferx:example'
    end
  end
end

describe Inferx::Storage, '#load' do
  it 'loads categories' do
    storage = described_class.new.tap do |s|
      s.stub!(:categories).and_return([:red, :green, :blue])
      s.stub!(:get).with(:red  ).and_return('apple'   => 2)
      s.stub!(:get).with(:green).and_return('grasses' => 2)
      s.stub!(:get).with(:blue ).and_return('sea'     => 3)
    end

    storage.load.should == sample_categories
  end
end

describe Inferx::Storage, '#save' do
  it 'saves the categories' do
    redis_stub do |s|
      s.should_receive(:multi).and_return { |&block| block.call }

      s.should_receive(:del).with(
        'inferx:categories',
        'inferx:categories:red',
        'inferx:categories:green',
        'inferx:categories:blue'
      )
    end

    storage = described_class.new.tap do |s|
      s.stub!(:categories).and_return([:red, :green, :blue])
      s.stub!(:set).with(:red,   'apple'   => 2)
      s.stub!(:set).with(:green, 'grasses' => 2)
      s.stub!(:set).with(:blue,  'sea'     => 3)
    end

    storage.save(sample_categories)
  end
end

describe Inferx::Storage, '#categories' do
  def setup(key, value)
    redis_stub { |s| s.stub!(:smembers).with(key).and_return(value) }
  end

  it 'returns categories if the categories is defined' do
    setup('inferx:categories', %w(red green blue))
    storage = described_class.new
    storage.categories.should == [:red, :green, :blue]
  end

  it 'returns an empty array if the categories is not defined' do
    setup('inferx:categories', nil)
    storage = described_class.new
    storage.categories.should be_empty
  end
end

describe Inferx::Storage, '#get' do
  def setup(key, value)
    redis_stub { |s| s.stub!(:hgetall).with(key).and_return(value) }
  end

  it 'returns a frequency if the category is found' do
    setup('inferx:categories:red', 'apple' => '2')
    storage = described_class.new
    storage.get(:red).should == {'apple' => 2}
  end

  it 'returns an empty array if the category is not found' do
    setup('inferx:categories:red', {})
    storage = described_class.new
    storage.get(:red).should be_empty
  end

  it 'converts count of words to Integer' do
    setup('inferx:categories:red', 'apple' => '2')
    storage = described_class.new
    storage.get(:red)['apple'].should be_an(Integer)
  end
end

describe Inferx::Storage, '#set' do
  def setup(categories_key, categories_value, category_key, category_value)
    redis_stub do |s|
      s.should_receive(:sadd).with(categories_key, categories_value)
      s.should_receive(:mapped_hmset).with(category_key, category_value)
    end
  end

  it 'sets the category to the categories, and the frequency to the category' do
    setup('inferx:categories', :red, 'inferx:categories:red', 'apple' => 2)
    storage = described_class.new
    storage.set(:red, 'apple' => 2)
  end
end
