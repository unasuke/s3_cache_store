require "s3_cache_store/version"
require "active_support/cache"
require "aws-sdk-s3"
require "tempfile"
require "digest/sha2"

module ActiveSupport
  module Cache
    class S3CacheStore < Store
      def initialize(options = nil)
        super(options)

        @digest = ::Digest::SHA2.new()
        access_key_id = options[:access_key_id] || ENV['AWS_ACCESS_KEY_ID']
        secret_access_key = options[:secret_access_key] || ENV['AWS_SECRET_ACCESS_KEY']
        region = options[:region] || ENV['AWS_DEFAULT_REGION']
        endpoint = options[:endpoint]
        @bucket = options[:bucket]

        if @bucket.nil? || @bucket.empty?
          raise ArgumentError, "Bucket name not specified"
        end

        Aws.config.update(
            force_path_style: true
        )
        @client = Aws::S3::Client.new(
          {
            access_key_id: access_key_id,
            secret_access_key: secret_access_key,
            region: region,
            endpoint: endpoint,
            force_path_style: !!endpoint
          }
        )
      end

      def increment(name, amount = 1, options = nil)
        value = read(name, options)
        if value
          value = value.to_i + amount
          write(name, value, options)
          value
        end
      end

      def decrement(name, amount = 1, options = nil)
        value = read(name, options)
        if value
          value = value.to_i - amount
          write(name, value, options)
          value
        end
      end

      private

      def read_entry(key, **options)
        resp = @client.get_object(
          {
            bucket: @bucket,
            key: ::Digest::SHA2.hexdigest(key),
          })
        deserialize_entry(resp.body.read)
      rescue Aws::S3::Errors::NoSuchKey
        nil
      end

      def write_entry(key, entry, **options)
        binding.irb if $DEBUG
        serialized_entry = serialize_entry(entry)

        if serialized_entry.is_a?(String) || serialized_entry.is_a?(File)
          resp = @client.put_object(
            {
              bucket: @bucket,
              key: ::Digest::SHA2.hexdigest(key),
              body: serialized_entry
            })
        else
          Tempfile.open do |f|
            f.write(entry)
            f.rewind
            resp = @client.put_object(
              {
                bucket: @bucket,
                key: ::Digest::SHA2.hexdigest(key),
                body: f
              })
          end
        end
      end

      def delete_entry(key, options)
        @client.get_object({ bucket: @bucket, key: ::Digest::SHA2.hexdigest(key) })

        @client.delete_object(
          {
            bucket: @bucket,
            key: ::Digest::SHA2.hexdigest(key),
          }
        )
      rescue Aws::S3::Errors::NoSuchKey
        false
      end
    end
  end
end
