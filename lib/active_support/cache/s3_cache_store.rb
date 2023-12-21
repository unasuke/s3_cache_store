# frozen_string_literal: true

require "s3_cache_store/s3_client"
require "active_support"
require "aws-sdk-s3"
require "pathname"
require "tempfile"
require "uri"
require "digest/sha2"

module ActiveSupport
  module Cache
    # = \S3 \Cache \Store
    #
    # A cache store implementation which stores everything on the Amazon S3 Bucket.
    class S3CacheStore < Store
      attr_reader :s3_client

      OBJECT_KEY_MAX_SIZE = 900 # max is 1024, plus some room

      def initialize(bucket:, region: ENV["AWS_REGION"] || ENV["AWS_DEFAULT_REGION"], prefix: "", **options)
        super(options)
        @s3_client = ::S3CacheStore::S3Client.new(bucket: bucket, region: region)
        @prefix = prefix.is_a?(Pathname) ? prefix : Pathname(prefix)
      end

      def increment(name, amount = 1, options = nil)
        current = read(name, options)
        value = (current&.to_i || 0) + amount
        write(name, value, options)
        value
      end

      def decrement(name, amount = 1, options = nil)
        current = read(name, options)
        value = (current&.to_i || 0) - amount
        write(name, value, options)
        value
      end

      def clear(options = nil)
        s3_client.clear(@prefix.to_s) if @prefix
      end

      def delete_matched(matcher, options = nil)
        options = merged_options(options)
        matcher = key_matcher(matcher, options)

        instrument(:delete_matched, matcher.inspect) do
          s3_client.list_objects(@prefix.to_s).each do |object|
            s3_client.delete_object(object.key) if object.key.match(matcher)
          end
        end
      end

      private

      def read_entry(key, **)
        payload = s3_client.read_object(object_key(key))
        return unless payload

        entry = deserialize_entry(payload)
        entry if entry.is_a?(Cache::Entry)
      end

      def write_entry(key, entry, **options)
        return false if options[:unless_exist] && s3_client.exists_object?(object_key(key))

        payload = serialize_entry(entry, **options)
        s3_client.write_object(object_key(key), payload)
      end

      def delete_entry(key, **)
        if s3_client.exists_object?(object_key(key))
          s3_client.delete_object(object_key(key))
          true
        else
          false
        end
      end

      def object_key(key)
        filename = ::URI.encode_www_form_component(key).gsub("%2F", "/")
        result = @prefix.join(filename).to_s

        if result.size > OBJECT_KEY_MAX_SIZE
          return object_key(::Digest::SHA2.hexdigest(key))
        end

        result
      end
    end
  end
end
