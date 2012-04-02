require 'spec_helper'
require 'inferx/adapter'

describe Inferx::Adapter, '#initialize' do
  it 'sets the instance of Redis to @redis' do
    redis = redis_stub
    adapter = described_class.new(redis)
    adapter.instance_eval { @redis }.should == redis
  end

  context 'with a namespace' do
    it 'sets the namespace to @namespace' do
      adapter = described_class.new(redis_stub, 'example')
      adapter.instance_eval { @namespace }.should == 'example'
    end
  end
end

describe Inferx::Adapter, '#categories_key' do
  it "calls #{described_class}#make_category_key" do
    adapter = described_class.new(redis_stub)
    adapter.should_receive(:make_categories_key)
    adapter.categories_key
  end

  it "calls #{described_class}#make_category_key once in same instance" do
    adapter = described_class.new(redis_stub)
    adapter.should_receive(:make_categories_key).and_return('inferx:categories')
    adapter.categories_key
    adapter.categories_key
  end
end

describe Inferx::Adapter, '#make_categories_key' do
  it 'returns the key for access to categories' do
    adapter = described_class.new(redis_stub)
    adapter.categories_key.should == 'inferx:categories'
  end

  context 'with a namespace' do
    it 'returns the key included the namespace' do
      adapter = described_class.new(redis_stub, 'example')
      adapter.categories_key.should == 'inferx:example:categories'
    end
  end
end

describe Inferx::Adapter, '#make_category_key' do
  it 'returns the key for access to to scores stored each by word' do
    adapter = described_class.new(redis_stub)
    adapter.make_category_key(:red).should == 'inferx:categories:red'
  end

  context 'with a namespace' do
    it 'returns the key included the namespace' do
      adapter = described_class.new(redis_stub, 'example')
      adapter.make_category_key(:red).should == 'inferx:example:categories:red'
    end
  end
end

describe Inferx::Adapter, '#spawn' do
  it 'calls constructor of the class with the instance variables and the arguments' do
    redis = redis_stub
    adapter = described_class.new(redis, 'example')
    klass = mock.tap { |m| m.should_receive(:new).with(redis, 'arg1', 'arg2', 'example') }
    adapter.spawn(klass, 'arg1', 'arg2')
  end

  it 'returns an instance of the class' do
    adapter = described_class.new(redis_stub)
    klass = stub.tap { |s| s.stub!(:new).and_return('klass') }
    adapter.spawn(klass).should == 'klass'
  end
end