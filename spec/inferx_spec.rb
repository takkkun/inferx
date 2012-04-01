require 'spec_helper'
require 'inferx'

describe Inferx do
  it 'is an instance of Class' do
    described_class.should be_an_instance_of(Class)
  end

  it 'has VERSION constant' do
    described_class.should be_const_defined(:VERSION)
  end
end

describe Inferx, '#initialize' do
  it "calls #{described_class}::Categories.new with a connection of Redis and the namespace option" do
    redis = redis_stub
    Inferx::Categories.should_receive(:new).with(redis, 'example')
    described_class.new(:namespace => 'example')
  end

  it "sets an instance of #{described_class}::Categories to the categories attribute" do
    redis_stub
    inferx = described_class.new
    inferx.categories.should be_an(Inferx::Categories)
  end
end

describe Inferx, ' classifying' do
  before do
    redis_stub do |s|
      s.stub!(:smembers).and_return(%w(red green blue))

      s.stub!(:zrevrangebyscore).with('inferx:categories:red', '+inf', 2, :withscores => true).and_return(%w(apple 2))
      s.stub!(:get).with('inferx:categories:red:size').and_return('2')

      s.stub!(:zrevrangebyscore).with('inferx:categories:green', '+inf', 2, :withscores => true).and_return(%w(grasses 2))
      s.stub!(:get).with('inferx:categories:green:size').and_return('2')
      s.stub!(:zscore).with('inferx:categories:green', 'apple').and_return(nil)

      s.stub!(:zrevrangebyscore).with('inferx:categories:blue', '+inf', 2, :withscores => true).and_return(%w(sea 2))
      s.stub!(:get).with('inferx:categories:blue:size').and_return('3')
      s.stub!(:zscore).with('inferx:categories:blue', 'apple').and_return(nil)
    end
  end

  it 'returns an expected classifications' do
    inferx = described_class.new

    inferx.classifications(%w(apple)).should == {
      :red   =>  0.0,
      :green => -2.995732273553991,
      :blue  => -3.4011973816621555
    }
  end

  it 'returns a negative infinity number if the score is zero' do
    Redis.new.tap do |s|
      s.stub!(:get).with('inferx:categories:blue:size').and_return(nil)
      s.should_not_receive(:zscore).with('inferx:categories:blue', 'apple')
    end

    inferx = described_class.new

    inferx.classifications(%w(apple)).should == {
      :red   =>  0.0,
      :green => -2.995732273553991,
      :blue  => -Float::INFINITY
    }
  end

  it 'returns a category name got by classification' do
    inferx = described_class.new
    inferx.classify(%w(apple)).should == :red
  end
end
