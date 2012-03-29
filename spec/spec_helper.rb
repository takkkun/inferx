def sample_categories
  {
    :red   => {'apple'   => 2},
    :green => {'grasses' => 2},
    :blue  => {'sea'     => 3}
  }
end

def storage_stub(options = {})
  storage = stub.tap do |s|
    s.stub!(:load).and_return(options[:categories] || {})
    s.stub!(:save)
  end

  Inferx::Storage.stub!(:new).and_return(storage)
end

def redis_stub
  redis = stub
  yield redis if block_given?
  Redis.stub!(:new).and_return(redis)
end
