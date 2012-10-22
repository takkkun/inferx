require 'inferx/complementary/category'

describe Inferx::Complementary::Category, '#train' do
  it 'calls Redis#zincrby and Redis#hincrby for other categories' do
    redis = redis_stub do |s|
      s.stub!(:hkeys).and_return(%w(red green blue))
      s.should_receive(:zincrby).with('inferx:categories:green', 2, 'apple')
      s.should_receive(:zincrby).with('inferx:categories:green', 3, 'strawberry')
      s.should_receive(:hincrby).with('inferx:categories', 'green', 5)
      s.should_receive(:zincrby).with('inferx:categories:blue', 2, 'apple')
      s.should_receive(:zincrby).with('inferx:categories:blue', 3, 'strawberry')
      s.should_receive(:hincrby).with('inferx:categories', 'blue', 5)
      s.should_receive(:save)
    end

    category = described_class.new(redis, 'red', 2)
    category.train(%w(apple strawberry apple strawberry strawberry))
  end

  context 'with no update' do
    it 'does not call Redis#hincrby' do
      redis = redis_stub do |s|
        s.should_not_receive(:hincrby)
        s.should_not_receive(:save)
      end

      category = described_class.new(redis, 'red', 2)
      category.train([])
    end
  end

  context 'with manual save' do
    it 'does not call Redis#save' do
      redis = redis_stub do |s|
        s.stub!(:hkeys).and_return(%w(red green blue))
        s.stub!(:zincrby)
        s.stub!(:hincrby)
        s.should_not_receive(:save)
      end

      category = described_class.new(redis, 'red', 2, :manual => true)
      category.train(%w(apple strawberry apple strawberry strawberry))
    end
  end
end

describe Inferx::Complementary::Category, '#untrain' do
  it 'calls Redis#zincrby, Redis#zremrangebyscore and Redis#hincrby for other categories' do
    redis = redis_stub do |s|
      s.stub!(:hkeys).and_return(%w(red green blue))

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

    category = described_class.new(redis, 'red', 2)
    category.untrain(%w(apple strawberry apple strawberry strawberry))
  end

  context 'with no update' do
    it 'does not call Redis#zremrangebyscore and Redis#hincrby' do
      redis = redis_stub do |s|
        s.stub!(:hkeys).and_return(%w(red green blue))

        s.stub!(:pipelined).and_return do |&block|
          block.call
          %w(-3 -2 2 -3 -2 2)
        end

        s.stub!(:zincrby)
        s.stub!(:zremrangebyscore)
        s.should_not_receive(:hincrby)
        s.should_not_receive(:save)
      end

      category = described_class.new(redis, 'red', 2)
      category.untrain([])
    end
  end

  context 'with manual save' do
    it 'does not call Redis#save' do
      redis = redis_stub do |s|
        s.stub!(:hkeys).and_return(%w(red green blue))

        s.stub!(:pipelined).and_return do |&block|
          block.call
          %w(1 1 0 2 -1 1)
        end

        s.stub!(:zincrby)
        s.stub!(:zremrangebyscore)
        s.stub!(:hincrby)
        s.should_not_receive(:save)
      end

      category = described_class.new(redis, 'red', 2, :manual => true)
      category.untrain(%w(apple strawberry apple strawberry strawberry))
    end
  end
end
