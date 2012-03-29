What is inferx
==============

It is Naive Bayes classifier, and the training data persisted by Redis.

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

    inferx.train(:red, {
      'he'    => 1',
      'buy'   => 1,
      'apple' => 2,
      'its'   => 1,
      'fresh' => 1
    })

    inferx.train(:green, 'grasses' => 2, ...)
    inferx.train(:blue, 'sea' => 3, ...)

    puts inferx.classify('apple' => 1, ...) # => red

Contributing
------------

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
