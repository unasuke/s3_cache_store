require_relative "test_helper"
require "aws-sdk-s3"
require "securerandom"
require "active_support/testing/method_call_assertions"
require "active_support"
require "active_support/time"
require_relative "behaviors"

class S3CacheStoreTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::MethodCallAssertions

  ActiveSupport::Cache.format_version = 7.1

  def lookup_store(options = {})
    bucket = options.delete(:bucket) { @bucket }
    region = options.delete(:region) { @region }
    prefix = options.delete(:prefix) { @prefix }
    ActiveSupport::Cache.lookup_store(:s3_cache_store, bucket: bucket, prefix: prefix, region: region, **options)
  end

  def setup
    @bucket = ENV["AWS_S3_BUCKET"]
    @region = ENV["AWS_REGION"] || ENV["AWS_DEFAULT_REGION"] || "ap-northeast-1"
    @prefix = "s3_cache_store_test/"
    @cache = lookup_store(expires_in: 60, bucket: @bucket, prefix: @prefix, region: @region)

    @buffer = StringIO.new
    @cache.logger = ActiveSupport::Logger.new(@buffer)
  end

  def teardown
    @cache.clear
  end

  include CacheStoreBehavior
  include CacheStoreVersionBehavior
  include CacheStoreCoderBehavior
  include CacheStoreCompressionBehavior
  include CacheStoreSerializerBehavior
  include CacheStoreFormatVersionBehavior
  include CacheDeleteMatchedBehavior
  include CacheIncrementDecrementBehavior
  # include CacheInstrumentationBehavior # TODO: test_fetch_multi_instrumentation_order_of_operations
  # include CacheLoggingBehavior # TODO: test_delete_logging, test_exist_logging
end
