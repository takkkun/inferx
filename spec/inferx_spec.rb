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

describe Inferx, ' by default' do
  before do
    storage_stub
  end

  it 'the categories is empty' do
    classifier = described_class.new
    classifier.categories.should be_empty
  end

  it 'the manual option is false' do
    classifier = described_class.new
    classifier.should_not be_manual
  end
end

describe Inferx, '#initialize' do
  before do
    storage_stub(:categories => sample_categories)
  end

  it 'sets the categories' do
    classifier = described_class.new
    classifier.categories.should be_include(:red)
    classifier.categories.should be_include(:green)
    classifier.categories.should be_include(:blue)
  end

  it 'sets the manual option' do
    classifier = described_class.new(:manual => true)
    classifier.should be_manual
    classifier = described_class.new(:manual => false)
    classifier.should_not be_manual
  end
end

describe Inferx, '#add' do
  before do
    storage_stub(:categories => sample_categories)
  end

  it 'adds a category' do
    classifier = described_class.new
    classifier.add(:cyan, :magenta)
    classifier.categories.should be_include(:cyan)
    classifier.categories.should be_include(:magenta)
  end

  it 'sets an empty hash to the frequency of the added category' do
    classifier = described_class.new
    classifier.add(:cyan)
    classifier.frequency(:cyan).should be_empty
  end

  it 'does not add an existing category already' do
    classifier = described_class.new
    original_size = classifier.categories.size
    classifier.add(:red)
    classifier.categories.should have(original_size).items
  end

  it 'saves to the storage if a category added and the manual option is false' do
    classifier = described_class.new(:manual => false)
    classifier.should_receive(:save)
    classifier.add(:cyan)
  end

  it 'does not save if a category did not add' do
    classifier = described_class.new(:manual => false)
    classifier.should_not_receive(:save)
    classifier.add(:red)
  end

  it 'does not save if the manual option is true' do
    classifier = described_class.new(:manual => true)
    classifier.should_not_receive(:save)
    classifier.add(:cyan)
  end
end

describe Inferx, '#remove' do
  before do
    storage_stub(:categories => sample_categories)
  end

  it 'removes a category' do
    classifier = described_class.new
    classifier.remove(:red, :green)
    classifier.categories.should_not be_include(:red)
    classifier.categories.should_not be_include(:green)
  end

  it 'saves to the storage if a category removed and the manual option is false' do
    classifier = described_class.new(:manual => false)
    classifier.should_receive(:save)
    classifier.remove(:red)
  end

  it 'does not save if a category did not remove' do
    classifier = described_class.new(:manual => false)
    classifier.should_not_receive(:save)
    classifier.remove(:cyan)
  end

  it 'does not save if the manual option is true' do
    classifier = described_class.new(:manual => true)
    classifier.should_not_receive(:save)
    classifier.remove(:red)
  end
end

describe Inferx, '#train' do
  before do
    storage_stub(:categories => sample_categories)
  end

  it 'updates the frequency of the category' do
    classifier = described_class.new
    classifier.train(:red, 'apple' => 2, 'strawberry' => 3)
    classifier.frequency(:red).should == {'apple' => 4, 'strawberry' => 3}
  end

  it 'saves to the storage if the frequency of the category updated and the manual option is false' do
    classifier = described_class.new(:manual => false)
    classifier.should_receive(:save)
    classifier.train(:red, 'apple' => 2, 'strawberry' => 3)
  end

  it 'does not save if the manual option is true' do
    classifier = described_class.new(:manual => true)
    classifier.should_not_receive(:save)
    classifier.train(:red, 'apple' => 2, 'strawberry' => 3)
  end

  it 'raises MissingCategory if the category does not exist' do
    classifier = described_class.new
    lambda { classifier.train(:cyan, 'sky' => 4) }.should raise_error(Inferx::MissingCategory)
  end
end

describe Inferx, '#untrain' do
  before do
    storage_stub(:categories => sample_categories)
  end

  it 'updates the frequency of the category' do
    classifier = described_class.new
    classifier.untrain(:red, 'apple' => 1)
    classifier.frequency(:red).should == {'apple' => 1}
  end

  it 'saves to the storage if the frequency of the category updated and the manual option is false' do
    classifier = described_class.new(:manual => false)
    classifier.should_receive(:save)
    classifier.untrain(:red, 'apple' => 1)
  end

  it 'does not save if the frequency of the category did not update' do
    classifier = described_class.new(:manual => false)
    classifier.should_not_receive(:save)
    classifier.untrain(:red, 'strawberry' => 3)
  end

  it 'does not save if the manual option is true' do
    classifier = described_class.new(:manual => true)
    classifier.should_not_receive(:save)
    classifier.untrain(:red, 'apple' => 1)
  end

  it 'raises MissingCategory if the category does not exist' do
    classifier = described_class.new
    lambda { classifier.untrain(:cyan, 'sky' => 4) }.should raise_error(Inferx::MissingCategory)
  end
end

describe Inferx, '#classifications' do
  before do
    storage_stub(:categories => sample_categories)
    @classifier = described_class.new
  end

  it 'returns an expected value' do
    @classifier.classifications(%w(apple)).should == {
      :red   =>  0.0,
      :green => -2.995732273553991,
      :blue  => -3.4011973816621555
    }
  end
end

describe Inferx, '#classify' do
  before do
    storage_stub(:categories => sample_categories)
    @classifier = described_class.new
  end

  it 'returns an expected value' do
    @classifier.classify(%w(apple)).should == :red
  end
end

describe Inferx, '#save' do
  before do
    storage_stub(:categories => sample_categories)
    @classifier = described_class.new
  end

  it 'calls Inferx::Storage#save' do
    @classifier.instance_eval do
      @storage.should_receive(:save).with(sample_categories)
    end

    @classifier.save
  end
end
