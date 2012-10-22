require 'spec_helper'
require 'inferx/complementary/categories'

describe Inferx::Complementary::Categories do
  it 'inherits Inferx::Categories' do
    described_class.superclass.should == Inferx::Categories
  end
end

describe Inferx::Complementary::Categories, '#spawn_category' do
  before do
    @categories = described_class.new(redis_stub).tap do |s|
      s.stub!(:spawn => 'category')
    end
  end

  it 'calls #spawn with Inferx::Complementary::Category, the categories and the arguments' do
    @categories.should_receive(:spawn).with(Inferx::Complementary::Category, @categories, 'arg1', 'arg2')
    @categories.spawn_category('arg1', 'arg2')
  end

  it 'returns the return value from #spawn' do
    @categories.spawn_category('arg1', 'arg2').should == 'category'
  end
end
