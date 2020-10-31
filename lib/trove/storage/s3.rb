require "aws-sdk-s3"
require "fileutils"

module Trove
  module Storage
    class S3
      attr_reader :bucket, :prefix

      def initialize(bucket:, prefix: nil)
        @bucket = bucket
        @prefix = prefix
      end

      def download(filename, dest, version: nil)
        current_size = 0
        total_size = nil

        # TODO better path
        tmp = "#{Dir.tmpdir}/trove-#{Time.now.to_f}"
        begin
          File.open(tmp, "wb") do |file|
            options = {bucket: bucket, key: key(filename)}
            options[:version_id] = version if version
            client.get_object(**options) do |chunk, headers|
              file.write(chunk)

              current_size += chunk.bytesize
              total_size ||= headers["content-length"].to_i
              yield current_size, total_size
            end
          end
          FileUtils.mv(tmp, dest)
        ensure
          # delete file if interrupted
          File.unlink(tmp) if File.exist?(tmp)
        end
      rescue Aws::S3::Errors::ServiceError
        raise "File not found"
      end

      def upload(src, filename, &block)
        on_chunk_sent = lambda do |_, current_size, total_size|
          block.call(current_size, total_size)
        end
        resp = nil
        File.open(src, "rb") do |file|
          resp = client.put_object(bucket: bucket, key: key(filename), body: file, on_chunk_sent: on_chunk_sent)
        end
        {version: resp.version_id}
      end

      # etag isn't always MD5, but low likelihood of match if not
      # could alternatively add sha256 to metadata
      def info(filename, version: nil)
        options = {bucket: bucket, key: key(filename)}
        options[:version_id] = version if version
        resp = client.head_object(**options)
        {
          version: resp.version_id,
          md5: resp.etag.gsub('"', "")
        }
      rescue Aws::S3::Errors::ServiceError
        nil
      end

      def delete(filename, version: nil)
        options = {bucket: bucket, key: key(filename)}
        options[:version_id] = version if version
        client.delete_object(**options)
        true
      rescue Aws::S3::Errors::ServiceError
        false
      end

      def list
        files = []
        options = {bucket: bucket}
        options[:prefix] = prefix if prefix
        client.list_objects_v2(**options).each do |response|
          response.contents.each do |object|
            filename = prefix ? object.key[(prefix.size + 1)..-1] : object.key
            files << {
              filename: filename,
              size: object.size,
              updated_at: object.last_modified
            }
          end
        end
        files
      end

      def versions(filename)
        versions = []
        object_key = key(filename)
        client.list_object_versions(bucket: bucket, prefix: object_key).each do |response|
          response.versions.each do |version|
            next if version.key != object_key

            versions << {
              version: version.version_id == "null" ? nil : version.version_id,
              size: version.size,
              updated_at: version.last_modified
            }
          end
        end
        versions
      end

      private

      def client
        @client ||= Aws::S3::Client.new
      end

      def key(filename)
        prefix ? "#{prefix}/#{filename}" : filename
      end
    end
  end
end
