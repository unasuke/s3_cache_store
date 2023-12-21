source "https://rubygems.org"

# Specify your gem's dependencies in s3_cache_store.gemspec
gemspec

# https://github.com/rails/rails/pull/45370
if RUBY_VERSION < "3"
  gem "minitest", ">= 5.15.0", "< 5.16"
else
  gem "minitest", ">= 5.15.0"
end

# for development
gem "rake", "~> 13.0"
gem "standard", "~> 1.3"

# for test
gem "msgpack"
gem "dalli"

# for benchmark
gem "redis"
gem "redis-clustering"
