require 'spec_helper'
require 'inferx/category/complementary'

describe Inferx::Category::Complementary, '#ready_to_inject' do
  it 'calls #inject with the words to inject block' do
    category = described_class.new(redis_stub, 'red', 2, categories_stub)
    category.should_receive(:inject).with(%w(word1 word2 word3))

    category.ready_to_inject do |inject|
      inject[%w(word1)]
      inject[%w(word2)]
      inject[%w(word3)]
    end
  end
end

describe Inferx::Category::Complementary, '#ready_to_eject' do
  it 'calls #eject with the words to eject block' do
    category = described_class.new(redis_stub, 'red', 2, categories_stub)
    category.should_receive(:eject).with(%w(word1 word2 word3))

    category.ready_to_eject do |eject|
      eject[%w(word1)]
      eject[%w(word2)]
      eject[%w(word3)]
    end
  end
end

describe Inferx::Category::Complementary, '#train' do
  it 'calls Redis#zincrby and Redis#hincrby for other categories' do
    redis = redis_stub do |s|
      s.stub!(:hkeys => %w(red green blue))
      s.should_receive(:zincrby).with('inferx:categories:green', 2, 'apple')
      s.should_receive(:zincrby).with('inferx:categories:green', 3, 'strawberry')
      s.should_receive(:hincrby).with('inferx:categories', 'green', 5)
      s.should_receive(:zincrby).with('inferx:categories:blue', 2, 'apple')
      s.should_receive(:zincrby).with('inferx:categories:blue', 3, 'strawberry')
      s.should_receive(:hincrby).with('inferx:categories', 'blue', 5)
      s.should_receive(:save)
    end

    category = described_class.new(redis, 'red', 2, categories_stub)
    category.train(%w(apple strawberry apple strawberry strawberry))
  end

  context 'with no update' do
    it 'does not call Redis#hincrby' do
      redis = redis_stub do |s|
        s.should_not_receive(:hincrby)
        s.should_not_receive(:save)
      end

      category = described_class.new(redis, 'red', 2, categories_stub)
      category.train([])
    end
  end

  context 'with manual save' do
    it 'does not call Redis#save' do
      redis = redis_stub do |s|
        s.stub!(:hkeys => %w(red green blue))
        s.stub!(:zincrby)
        s.stub!(:hincrby)
        s.should_not_receive(:save)
      end

      category = described_class.new(redis, 'red', 2, categories_stub, :manual => true)
      category.train(%w(apple strawberry apple strawberry strawberry))
    end
  end
end

describe Inferx::Category::Complementary, '#untrain' do
  it 'calls Redis#zincrby, Redis#zremrangebyscore and Redis#hincrby for other categories' do
    redis = redis_stub do |s|
      s.stub!(:hkeys => %w(red green blue))

      s.stub!(:pipelined).and_return do |&block|
        block.call
        %w(1 1 0 2 -1 1)
      end

      s.should_receive(:zincrby).with('inferx:categories:green', -2, 'apple')
      s.should_receive(:zincrby).with('inferx:categories:green', -3, 'strawberry')
      s.should_receive(:zremrangebyscore).with('inferx:categories:green', '-inf', 0)
      s.should_receive(:zincrby).with('inferx:categories:blue', -2, 'apple')
      s.should_receive(:zincrby).with('inferx:categories:blue', -3, 'strawberry')
      s.should_receive(:zremrangebyscore).with('inferx:categories:blue', '-inf', 0)
      s.should_receive(:hincrby).with('inferx:categories', 'green', -5)
      s.should_receive(:hincrby).with('inferx:categories', 'blue', -4)
      s.should_receive(:save)
    end

    category = described_class.new(redis, 'red', 2, categories_stub)
    category.untrain(%w(apple strawberry apple strawberry strawberry))
  end

  context 'with no update' do
    it 'does not call Redis#zremrangebyscore and Redis#hincrby' do
      redis = redis_stub do |s|
        s.stub!(:hkeys => %w(red green blue))

        s.stub!(:pipelined).and_return do |&block|
          block.call
          %w(-3 -2 2 -3 -2 2)
        end

        s.stub!(:zincrby)
        s.stub!(:zremrangebyscore)
        s.should_not_receive(:hincrby)
        s.should_not_receive(:save)
      end

      category = described_class.new(redis, 'red', 2, categories_stub)
      category.untrain([])
    end
  end

  context 'with manual save' do
    it 'does not call Redis#save' do
      redis = redis_stub do |s|
        s.stub!(:hkeys => %w(red green blue))

        s.stub!(:pipelined).and_return do |&block|
          block.call
          %w(1 1 0 2 -1 1)
        end

        s.stub!(:zincrby)
        s.stub!(:zremrangebyscore)
        s.stub!(:hincrby)
        s.should_not_receive(:save)
      end

      category = described_class.new(redis, 'red', 2, categories_stub, :manual => true)
      category.untrain(%w(apple strawberry apple strawberry strawberry))
    end
  end
end
