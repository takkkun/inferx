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
  it "calls #{described_class}::Categories.new with a connection of Redis and the options" do
    redis = redis_stub
    Inferx::Categories.should_receive(:new).with(redis, :namespace => 'example', :manual => true)
    described_class.new(:namespace => 'example', :manual => true)
  end

  it "sets an instance of #{described_class}::Categories to the categories attribute" do
    redis_stub
    inferx = described_class.new
    inferx.categories.should be_an(Inferx::Categories)
  end
end

describe Inferx, '#score' do
  before do
    @inferx = described_class.new
  end

  it "calls #{described_class}::Categories#size, #{described_class}::Category#all and #{described_class}::Category#scores" do
    category = mock.tap do |m|
      m.should_receive(:size).and_return(5)
      m.should_receive(:all).with(:rank => 500).and_return('apple' => 2)
      m.should_receive(:scores).with(%w(apple), 'apple' => 2).and_return([2])
    end

    @inferx.score(category, %w(apple))
  end

  it 'returns an expected score' do
    {
      [%w(apple), 2, [2]]   =>  0.0,
      [%w(apple), 2, [nil]] => -2.995732273553991,
      [%w(apple), 3, [nil]] => -3.4011973816621555
    }.each do |args, expected|
      words, size, scores = args

      category = stub.tap do |s|
        s.stub!(:size).and_return(size)
        s.stub!(:scores).and_return(scores)
        s.stub!(:all)
      end

      @inferx.score(category, words).should == expected
    end
  end

  it 'returns a negative infinity number if the category does not have words' do
    category = stub.tap do |s|
      s.stub!(:size).and_return(0)
    end

    score = @inferx.score(category, %w(apple))
    score.should be_infinite
    score.should < 0
  end
end

describe Inferx, '#classifications' do
  before do
    categories = [:red, :green, :blue].map do |category_name|
      stub.tap { |s| s.stub!(:name).and_return(category_name) }
    end

    @inferx = described_class.new.tap do |s|
      s.instance_eval { @categories = categories }
      s.stub!(:score).and_return { |category, words| "score of #{category.name}" }
    end
  end

  it "calls #{described_class}#score" do
    @inferx.tap do |m|
      m.should_receive(:score).with(@inferx.categories[0], %w(apple))
      m.should_receive(:score).with(@inferx.categories[1], %w(apple))
      m.should_receive(:score).with(@inferx.categories[2], %w(apple))
    end

    @inferx.classifications(%w(apple))
  end

  it 'calls uniq method of the words' do
    words = %w(apple).tap do |m|
      m.should_receive(:uniq).and_return(m)
    end

    @inferx.classifications(words)
  end

  it 'returns the scores to key the category name' do
    @inferx.classifications(%w(apple)).should == {
      :red   => 'score of red',
      :green => 'score of green',
      :blue  => 'score of blue'
    }
  end
end

describe Inferx, '#classify' do
  before do
    @inferx = described_class.new.tap do |s|
      s.stub!(:classifications).and_return(:red => -2, :green => -1, :blue => -3)
    end
  end

  it "calls #{described_class}#classifications" do
    @inferx.tap do |m|
      m.should_receive(:classifications).with(%w(apple)).and_return(:red => -2)
    end

    @inferx.classify(%w(apple))
  end

  it 'returns the most high-scoring category' do
    @inferx.classify(%w(apple)).should == :green
  end

  it 'returns nil if the categories is nothing' do
    @inferx.tap do |s|
      s.stub!(:classifications).and_return({})
    end

    @inferx.classify(%w(apple)).should be_nil
  end
end
