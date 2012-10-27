def redis_stub
  stub.tap do |s|
    s.stub!(:pipelined).and_return { |&block| block.call }
    s.stub!(:save)
    yield s if block_given?
    Redis.stub!(:new => s) if defined? Redis
  end
end

def categories_stub
  stub.tap do |s|
    s.stub!(:key => 'inferx:categories')
    yield s if block_given?
  end
end
