module Trove
  module Utils
    # TODO improve performance
    def self.human_size(size)
      if size < 2**10
        units = "B"
      elsif size < 2**20
        size /= (2**10).to_f
        units = "KB"
      elsif size < 2**30
        size /= (2**20).to_f
        units = "MB"
      else
        size /= (2**30).to_f
        units = "GB"
      end

      round = size < 9.95 ? 1 : 0
      "#{size.round(round)}#{units}"
    end

    def self.progress(stream, filename, current_size, total_size)
      return unless stream.tty?

      width = 50
      progress = (100.0 * current_size / total_size).floor
      completed = (width / 100.0 * progress).round
      remaining = width - completed
      stream.print "\r#{filename} [#{"=" * completed}#{" " * remaining}] %3s%% %11s " % [progress, "#{Utils.human_size(current_size)}/#{Utils.human_size(total_size)}"]
      stream.print "\n" if current_size == total_size
    end
  end
end
