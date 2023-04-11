require "thor"

module Trove
  class CLI < Thor
    include Thor::Actions

    desc "init", "Initialize a project"
    def init
      create_file "trove/.keep", ""

      if File.exist?(".gitignore")
        contents = <<~EOS

          # Ignore Trove storage
          /trove/*
          !/trove/.keep
        EOS
        unless File.read(".gitignore").include?(contents)
          append_to_file(".gitignore", contents)
        end
      else
        say "Check in trove/.keep and ignore trove/*"
      end

      create_file ".trove.yml", <<~EOS
        storage: s3://my-bucket/trove
      EOS
    end

    desc "push FILENAME", "Push a file"
    def push(filename)
      Trove.push(filename)
    end

    desc "pull [FILENAME]", "Pull files"
    option :version
    def pull(filename = nil)
      Trove.pull(filename, version: options[:version])
    end

    desc "delete FILENAME", "Delete a file"
    def delete(filename = nil)
      Trove.delete(filename)
    end

    desc "list", "List files"
    def list
      say table(
        Trove.list,
        [:filename, :size, :updated_at]
      )
    end

    desc "version", "Show the current version"
    def version
      say Trove::VERSION
    end

    desc "versions FILENAME", "List versions"
    def versions(filename)
      say table(
        Trove.versions(filename),
        [:version, :size, :updated_at]
      )
    end

    private

    def table(data, columns)
      columns.each do |c|
        if c == :size
          data.each { |r| r[c] = Utils.human_size(r[c]) }
        elsif c == :updated_at
          data.each { |r| r[c] = "#{time_ago(r[c])} ago" }
        elsif c == :version
          data.each { |r| r[c] ||= "<none>" }
        end
      end
      column_names = columns.map { |c| c.to_s.sub(/_at\z/, "").upcase }
      widths = columns.map.with_index { |c, i| [column_names[i].size, data.map { |r| r[c].to_s.size }.max || 0].max }

      output = String.new("")
      str = widths.map { |w| "%-#{w}s" }.join("     ") + "\n"
      output << str % column_names
      data.each do |row|
        output << str % columns.map { |c| row[c] }
      end
      output
    end

    def time_ago(time)
      diff = (Time.now - time).round

      if diff < 60
        pluralize(diff, "second")
      elsif diff < 60 * 60
        pluralize((diff / 60.0).floor, "minute")
      elsif diff < 60 * 60 * 24
        pluralize((diff / (60.0 * 60)).floor, "hour")
      else
        pluralize((diff / (60.0 * 60 * 24)).floor, "day")
      end
    end

    def pluralize(value, str)
      "#{value} #{value == 1 ? str : "#{str}s"}"
    end

    def self.exit_on_failure?
      true
    end
  end
end
