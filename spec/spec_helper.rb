def redis_stub
  stub.tap do |s|
    s.stub!(:pipelined).and_return { |&block| block.call }
    s.stub!(:save)
    yield s if block_given?
    Redis.stub!(:new => s) if defined? Redis
  end
end
