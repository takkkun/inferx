What is inferx
==============

It is Naive Bayes classifier, and the training data is kept always by Redis.

Installation
------------

Add this line to your application's Gemfile:

    gem 'inferx'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install inferx

Usage
-----

    require 'inferx'

    inferx = Inferx.new
    inferx.add(:red, :green, :blue)

    inferx.train(:red, %w(
      he
      buy
      apple
      its
      apple
      fresh
    ))

    inferx.train(:green, %w(grasses ...))
    inferx.train(:blue, %w(sea ...))

    puts inferx.classify(%w(apple ...)) # => red

Contributing
------------

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
