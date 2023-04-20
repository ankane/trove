# stdlib
require "digest/md5"
require "uri"
require "yaml"

# modules
require_relative "trove/utils"
require_relative "trove/version"

module Trove
  # storage
  module Storage
    autoload :S3, "trove/storage/s3"
  end

  # methods
  class << self
    # TODO use flock to prevent multiple concurrent downloads
    def pull(filename = nil, version: nil)
      if filename
        pull_file(filename, version: version)
      else
        raise ArgumentError, "Specify filename for version" if version

        (config["files"] || []).each do |file|
          pull_file(file["name"], version: file["version"], all: true)
        end
      end
    end

    # could use upload_file method for multipart uploads over a certain size
    # but multipart uploads have extra cost and cleanup, so keep it simple for now
    def push(filename)
      src = resolve_path(filename)
      raise "File not found" unless File.exist?(src)

      info = storage.info(filename)
      upload = info.nil?
      unless upload
        version = info[:version]
        if modified?(src, info)
          upload = true
        else
          stream.puts "Already up-to-date"
        end
      end

      if upload
        stream.puts "Pushing #{filename}..." unless stream.tty?
        resp = storage.upload(src, filename) do |current_size, total_size|
          Utils.progress(stream, filename, current_size, total_size)
        end
        version = resp[:version]
      end

      if vcs?
        # add files to yaml if needed
        files = (config["files"] ||= [])

        # find file
        file = files.find { |f| f["name"] == filename }
        unless file
          file = {"name" => filename}
          files << file
        end

        # update version
        file["version"] = version

        File.write(".trove.yml", config.to_yaml.sub(/\A---\n/, ""))
      end

      {
        version: version
      }
    end

    def delete(filename)
      storage.delete(filename)
    end

    def list
      storage.list
    end

    def versions(filename)
      storage.versions(filename)
    end

    private

    def pull_file(filename, version: nil, all: false)
      dest = resolve_path(filename)

      if !version
        file = (config["files"] || []).find { |f| f["name"] == filename }
        version = file["version"] if file
      end

      download = !File.exist?(dest)
      unless download
        info = storage.info(filename, version: version)
        if info.nil? || modified?(dest, info)
          download = true
        else
          stream.puts "Already up-to-date" unless all
        end
      end

      if download
        stream.puts "Pulling #{filename}..." unless stream.tty?
        storage.download(filename, dest, version: version) do |current_size, total_size|
          Utils.progress(stream, filename, current_size, total_size)
        end
      end

      download
    end

    def modified?(src, info)
      Digest::MD5.file(src).hexdigest != info[:md5]
    end

    def config
      @config ||= begin
        config = YAML.load_file(config_path)
        raise "Empty config" unless config.is_a?(Hash)
        config
      end
    end

    def config_path
      @config_path ||= search_tree(".trove.yml")
    end

    def config_dir
      File.dirname(config_path)
    end

    def search_tree(file)
      path = Dir.pwd
      # prevent infinite loop
      20.times do
        absolute_file = File.join(path, file)
        return absolute_file if File.exist?(absolute_file)
        path = File.dirname(path)
        break if path == "/"
      end
      raise "Config not found"
    end

    def resolve_path(filename)
      File.join(config_dir, root, filename)
    end

    def root
      @root ||= config["root"] || "trove"
    end

    def storage
      @storage ||= begin
        storage_url = config["storage"] || ENV.fetch("TROVE_STORAGE_URL", nil)
        raise "Missing storage" unless storage_url

        uri =
          begin
            URI.parse(storage_url)
          rescue URI::InvalidURIError
            raise "Invalid storage"
          end

        case uri.scheme
        when "s3"
          Storage::S3.new(
            bucket: uri.host,
            prefix: uri.path[1..]
          )
        else
          raise "Invalid storage provider: #{uri.scheme}"
        end
      end
    end

    def vcs?
      config.key?("vcs") ? config["vcs"] : true
    end

    def stream
      $stderr
    end
  end
end
