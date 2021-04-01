# frozen_string_literal: true

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"

  git_source(:github) { |repo| "https://github.com/#{repo}.git" }

  # Activate the gem you are reporting the issue against.
  gem "activesupport", "6.1.3.1"
  gem "redis"
  gem "s3_cache_store", path: '../'
  gem "aws-sdk-s3"
end

require "active_support"
require "active_support/core_ext/object/blank"
require "minitest/autorun"
require "active_support/cache/s3_cache_store"
require "aws-sdk-s3"
require "securerandom"

REDIS = "redis_bench_#{SecureRandom.alphanumeric(8)}"
MINIO = "minio_bench_#{SecureRandom.alphanumeric(8)}"
BUCKET = "test-bench-bucket"
COUNT = 1000

def setup
  system("docker run --rm -p 6379:6379 --detach --name #{REDIS} redis:6.2.1")
  system("docker run --rm -p 9000:9000 --detach --name #{MINIO} minio/minio server /data")
  client = Aws::S3::Client.new({
    access_key_id: 'minioadmin',
    secret_access_key: 'minioadmin',
    region: 'us-east-1',
    endpoint: 'http://127.0.0.1:9000',
    force_path_style: true,
  })
  client.create_bucket(bucket: BUCKET)
end

def bench_redis_cache_store
  store = ActiveSupport::Cache::RedisCacheStore.new({
    url: 'redis://localhost:6379'
  })
  redis_start = Time.now
  (1..COUNT).each do |e|
    store.write(e, e)
    store.read(e)
  end
  redis_duration = Time.now - redis_start
  puts "RedisCacheStore duration: #{redis_duration} sec (#{redis_duration / COUNT} s/key rw)"
end

def bench_s3_cache_store
  store = ActiveSupport::Cache::S3CacheStore.new({
    access_key_id: 'minioadmin',
    secret_access_key: 'minioadmin',
    region: 'us-east-1',
    endpoint: 'http://127.0.0.1:9000',
    force_path_style: true,
    bucket: BUCKET
  })
  s3_start = Time.now
  (1..COUNT).each do |e|
    store.write(e, e)
    store.read(e)
  end
  s3_duration = Time.now - s3_start
  puts "S3CacheStore duration: #{s3_duration} sec (#{s3_duration / COUNT} s/key rw)"
end

def teardown
  system("docker stop #{REDIS}")
  system("docker stop #{MINIO}")
end

begin
  setup()

  puts "\n\n===== start benchmark =========="
  bench_redis_cache_store()
  bench_s3_cache_store()
  puts "===== end benchmark ============\n\n"
ensure
  teardown()
end

