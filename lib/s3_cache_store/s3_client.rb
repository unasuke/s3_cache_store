# frozen_string_literal: true

require "s3_cache_store/version"
require "aws-sdk-s3"

module S3CacheStore
  class S3Client
    attr_reader :bucket

    def initialize(bucket:, region: ENV["AWS_REGION"] || ENV["AWS_DEFAULT_REGION"])
      @bucket = bucket

      if @bucket.nil? || @bucket.empty?
        raise ArgumentError, "Bucket name not specified"
      end

      @client = Aws::S3::Client.new(region: region)
    end

    def read_object(key)
      return unless exists_object?(key)

      @client.get_object(bucket: bucket, key: key).body.read
    end

    def write_object(key, payload)
      if payload.is_a?(String) || payload.is_a?(File)
        @client.put_object(bucket: bucket, key: key, body: payload)
      else
        Tempfile.open do |f|
          f.write(payload)
          f.rewind
          @client.put_object(bucket: bucket, key: key, body: f)
        end
      end
      true
    end

    def delete_object(key)
      @client.delete_object(bucket: bucket, key: key) if exists_object?(key)
      true
    rescue => e
      # Just in case the error was caused by another process deleting the file first.
      raise e if exists_object?(key)

      false
    end

    def exists_object?(key)
      @client.head_object(bucket: bucket, key: key)
      true
    rescue Aws::S3::Errors::NoSuchKey, Aws::S3::Errors::NotFound
      false
    end

    def clear(prefix = "")
      @client.list_objects_v2(bucket: bucket, prefix: prefix).contents.each do |object|
        @client.delete_object(bucket: bucket, key: object.key)
      end
    end

    def list_objects(prefix)
      @client.list_objects_v2(bucket: bucket, prefix: prefix).contents
    end
  end
end
