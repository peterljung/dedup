#!/usr/bin/env ruby

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

require 'digest'
require 'fileutils'

class Dedup

  def initialize(included_file_ext)
    @included_file_ext = included_file_ext
  end

  def skip_folder?(path)
    false
  end
  
  def skip_file?(ext)
    not @included_file_ext.include?(ext)
  end
  
  def valid?(path)
    File.exists?(path)
  end
  
  # Get all files as a hash size as key and list of files as value
  def get_files_with_sizes(path)
    file_size = {}
    file_stats = {}
    Dir.glob("#{path}/**/*").each do |path|
      if File.directory?(path)
        if skip_folder?(path)
          # TODO: How to prune everything below folder
        end
      elsif valid?(path)
        ext = File.extname(path).delete(".").downcase
        # collect file stats
        if file_stats[ext]
          file_stats[ext] += 1
        else
          file_stats[ext] = 1
        end
        # collect files in size order
        unless skip_file?(ext)
          size = File.size(path)
          unless file_size[size]
            file_size[size] = []
          end
          file_size[size] << path
        end
      end
    end
    [file_size, file_stats]
  end
  
  # Return groups of paths that share same MD5 hash of first N bytes in file
  def group_files_on_start(paths, size=4096)
    ans = paths.group_by { |p| 
      File.open(p) do |f|
        Digest::SHA1.hexdigest(f.read(size))
      end
    }
    ans.values.select { |g| g.size > 1 }
  end
  
  # Return groups of paths that share same SHA256 hash
  def group_files_on_hash(paths)
    ans = paths.group_by { |p| Digest::SHA1.file(p).to_s }
    ans.values.select { |g| g.size > 1 }
  end

  # De-duplicate set of identical files using UNIX hard links
  def dedup(paths)
    if (paths.size > 1)
      f, fs = paths[0], paths[1..]
      # Make sure files has same content
      differ = fs.any? { |p| !FileUtils.compare_file(f, p) }
      unless differ
        fs.each do |p|
          # And not already linked file
          unless File.identical?(f, p)
            tmp = p + ".dedup"
            File.rename(p, tmp)
            File.link(f, p)
            File.unlink(tmp)
          end
        end
      end
    end
  end

  # Do dedup analysis
  def find_duplicates(path, debug = false)
    # pathname = Pathname.new(path)
    files_w_size, file_stats = get_files_with_sizes(path)
    # Skip empty files
    files_w_size.delete(0)
    # Skip files with unique sizes
    files_w_size.select! { |size, files| files.size > 1 }
    # Select files with same size and hash of first part (4K) of file same
    file_start_dups = files_w_size.values.map { |g| group_files_on_start(g) }.flatten(1)
    # Group groups of files with same size in a hash with same SHA256
    file_hash_dups = file_start_dups.map { |g| group_files_on_hash(g) }.flatten(1)
    if debug then
      puts "Total number of analyzed files: " + file_stats.values.reduce(:+).to_s
      puts "Number of files that share size with at least another file: " + files_w_size.values.flatten.size.to_s
      puts "Number of files that share size and file start with at least one other file: " + file_start_dups.flatten.size.to_s
      puts "Number for files that share size and hash (SHA1) with at least one other file: " + file_hash_dups.flatten.size.to_s
    end
    [file_hash_dups, file_stats]
  end

end

if ARGV.size == 0
  puts
  puts "Usage: ./dedup.rb folder [-debug] [-dedup]"
  puts
  puts "List all files that are duplicates based on content hash"
  puts
  puts "    -debug  shows files with extensions not supported by this program"
  puts "    -dedup  performs deduplication (i.e. hard links) of all found duplicate files"
  puts
  puts "Output as:"
  puts "Index of duplication, filename"
  puts
  puts "Combine with other UNIX tools:"
  puts
  puts "./dedup.rb -- folder > duplicates.txt"
  puts "cat duplicates.txt | grep \"latest_upload\" | sort"
  puts "cat duplicates.txt | grep \"latest_upload\" | cut -d',' -f 1 | wc -l"
  puts "cat duplicates.txt | grep \"latest_upload\" | cut -d',' -f 1 | uniq | wc -l"
  puts "cat duplicates.txt | grep \"latest_upload\" | cut -d',' -f 2 | xargs -n 1 -I {} mv {} ./duplicates"
  puts
  exit
end

# Configure as needed ...
debug = ARGV.include?("-debug")
dodedup = ARGV.include?("-dedup")
folder = ARGV[0]

included_file_exts = ["mp3", "mp4", "ogg", "flac", "wav", "aiff", "mid", "png", "jpg", "gif", "bmp", "tga", "jpeg", "tif",
                      "tiff", "nef", "pdf", "mov", "psd", "heic"]

unless File.directory?(folder)
  puts "Given folder is not valid"
  exit
end

# Perform dedup analysis
dedup = Dedup.new(included_file_exts)
dups, fstats = dedup.find_duplicates(folder, debug)

if debug then
  uncovered_exts = fstats.select { |ext, _| 
    dedup.skip_file?(ext) 
  }
  unless uncovered_exts.empty? then
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
  dedup.dedup(g) if dodedup
}