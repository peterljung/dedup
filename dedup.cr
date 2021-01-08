#
# Copyright (c) 2021 Peter Ljung <peter@uniply.eu>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#

require "digest"

class Dedup
  def initialize(included_file_ext : Array(String))
    @included_file_ext = included_file_ext
  end

  def skip_folder?(path)
    false
  end

  def skip_file?(ext)
    !@included_file_ext.includes?(ext)
  end

  def valid?(path)
    File.exists?(path)
  end

  # Get all files as a hash size as key and list of files as value
  def get_files_with_sizes(path)
    file_size = {} of UInt64 => Array(String)
    file_stats = {} of String => UInt32
    Dir.glob("#{path}/**/*").each do |path|
      if File.directory?(path)
        if skip_folder?(path)
          # TODO: How to prune everything below folder
        end
      elsif valid?(path)
        ext = File.extname(path).delete(".").downcase
        # collect file stats
        if file_stats[ext]?
          file_stats[ext] += 1
        else
          file_stats[ext] = 1
        end
        # collect files in size order
        unless skip_file?(ext)
          size = File.size(path)
          unless file_size[size]?
            file_size[size] = [] of String
          end
          file_size[size] << path
        end
      end
    end
    {file_size, file_stats}
  end

  # Return groups of paths that share same MD5 hash of first N bytes in file
  def group_files_on_start(paths, size = 4096)
    ans = paths.group_by { |p|
      minsize = Math.min(File.size(p), size)
      f = File.open(p)
      Digest::MD5.hexdigest(f.read_string(minsize))
    }
    ans.values.select { |g| g.size > 1 }
  end

  # Return groups of paths that share same SHA256 hash
  def group_files_on_hash(paths)
    ans = paths.group_by { |p|
      Digest::SHA1.hexdigest(File.read(p))
    }
    ans.values.select { |g| g.size > 1 }
  end

  # Do dedup analysis
  def dedup(path, debug = false)
    files_w_size, file_stats = get_files_with_sizes(path)
    # Skip empty files
    files_w_size.delete(0)
    # Skip files with unique sizes
    files_w_size.select! { |size, files| files.size > 1 }
    # Select files with same size and hash of first part (4K) of file same
    file_start_dups = files_w_size.values.map { |g| group_files_on_start(g) }.flat_map(&.itself)
    # Group groups of files with same size in a hash with same SHA256
    file_hash_dups = file_start_dups.map { |g| group_files_on_hash(g) }.flat_map(&.itself)
    if debug
      puts "Total number of analyzed files: #{file_stats.values.reduce { |acc, v| acc + v }}"
      puts "Number of files that share size with at least another file: #{files_w_size.values.flatten.size}"
      puts "Number of files that share size and file start with at least one other file: #{file_start_dups.flatten.size}"
      puts "Number for files that share size and SHA256 hash with at least one other file: #{file_hash_dups.flatten.size}"
    end
    {file_hash_dups, file_stats}
  end
end

unless ARGV.size == 1 || ARGV.size == 2 && ARGV.includes?("-debug")
  puts
  puts "Usage: crystal run dedup.cr -- folder [-debug]"
  puts
  puts "List all files that are duplicates based on content hash"
  puts
  puts "Output as:"
  puts "Index of duplication, filename"
  puts
  puts "Combine with other UNIX tools:"
  puts
  puts "crystal run dedup.cr -- folder > duplicates.txt"
  puts "cat duplicates.txt | grep \"latest_upload\" | sort"
  puts "cat duplicates.txt | grep \"latest_upload\" | cut -d',' -f 1 | wc -l"
  puts "cat duplicates.txt | grep \"latest_upload\" | cut -d',' -f 1 | uniq | wc -l"
  puts "cat duplicates.txt | grep \"latest_upload\" | cut -d',' -f 2 | xargs -n 1 -I {} mv {} ./duplicates"
  puts
  exit
end

# Configure as needed ...
debug = ARGV.includes?("-debug")
included_file_exts = ["mp3", "mp4", "ogg", "flac", "wav", "aiff", "mid", "png", "jpg", "gif", "bmp", "tga", "jpeg", "tif", "tiff", "nef", "pdf", "mov"]

# Perform dedup analysis
dedup = Dedup.new(included_file_exts)
dups, fstats = dedup.dedup(ARGV[0], debug)

if debug
  uncovered_exts = fstats.select { |ext, _|
    dedup.skip_file?(ext)
  }
  unless uncovered_exts.empty?
    puts "Detected file extensions currently not covered:"
    uncovered_exts.each { |ext, n|
      puts "#{ext}, #{n.to_s} files"
    }
  end
end

# Output all duplicate files as
# dup index, file path
dups.each_with_index { |g, i|
  g.each { |f|
    puts "#{i.to_s},#{f.to_s}"
  }
}
