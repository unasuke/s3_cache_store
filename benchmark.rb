# frozen_string_literal: true

# Usage:
#   export AWS_ACCESS_KEY_ID=xxxxxxx ...
#   export REDIS_URL=rediss://:xxxxxx@xxxx.com:6379/0
#   export AWS_S3_GENERAL_BUCKET=general-bucket-name
#   export AWS_S3_DIRECTORY_BUCKET=directory-bucket-name
#   bundle exec ruby benchmark.rb | tee benchmark.txt
require "active_support"
require "active_support/cache/redis_cache_store"
require "active_support/cache/s3_cache_store"
require "redis"
require "redis-clustering"

COUNT = 1000
KEYS = COUNT.times.map { "{benchmark}:#{SecureRandom.hex(16)}" }

puts "Generated #{COUNT} keys"

# @param [ActiveSupport::Cache::Store] store
def bench(store, subject)
  puts "Start #{subject} benchmark"

  start = Time.now
  KEYS.each { |key| store.write(key, key) }
  duration = Time.now - start
  puts "#{subject} duration: #{duration} sec (#{duration / COUNT} s/key write)"

  start = Time.now
  KEYS.each { |key| store.read(key) }
  duration = Time.now - start
  puts "#{subject} duration: #{duration} sec (#{duration / COUNT} s/key read)"

  start = Time.now
  KEYS.each { |key| store.delete(key) }
  duration = Time.now - start
  puts "#{subject} duration: #{duration} sec (#{duration / COUNT} s/key delete)"
end

def bench_redis_cache_store
  redis = Redis::Cluster.new(nodes: [ENV["REDIS_URL"]])
  store = ActiveSupport::Cache::RedisCacheStore.new(redis: redis)
  bench(store, store.class.name)
end

def bench_s3_cache_store
  store = ActiveSupport::Cache::S3CacheStore.new(bucket: ENV["AWS_S3_GENERAL_BUCKET"], prefix: "benchmark/")
  bench(store, store.class.name + " (general)")
end

def bench_s3_express_cache_store
  store = ActiveSupport::Cache::S3CacheStore.new(bucket: ENV["AWS_S3_DIRECTORY_BUCKET"], prefix: "benchmark/")
  bench(store, store.class.name + " (express)")
end

bench_redis_cache_store
bench_s3_cache_store
bench_s3_express_cache_store
