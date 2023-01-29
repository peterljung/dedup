# File duplicate detector

## Overview

This project contains a simple script to help identify duplicate files based on file content rather than file name.

The tool take a single folder and determine duplicates as output.

## Install and usage

There are three version of this tool.

* One in plain [Ruby](https://www.ruby-lang.org/en/)
* One in compiled [Crystal](https://crystal-lang.org/)
* One in [Go](https://go.dev/)

The compiled version in Crystal is quite a bit faster than the Ruby version.

The go version is also fast.

In the future there is an opportunity to adapt the Crystal version to a parallel version to make use of all CPU cores. But as of version 1.7, Crystal still only support [concurrency](https://crystal-lang.org/reference/guides/concurrency.html) and not true parallelism.

### Run ruby version

Use ruby 2.3 or later

    ./dedup.rb <folder> [-debug] [-dedup]

### Run crystal version

Build and run using crystal 1.4 or later

    crystal run dedup.cr -- <folder> [-debug] [-dedup]

Build release and then run executable

    crystal build dedup.cr --release --no-debug
    ./dedup <folder> [-debug] [-dedup]

### Run go version

Build and run using go 1.17 or later

    go run dedup.go <folder>

Build release and then run executable

    go build dedup.go
    ./dedup <folder>

### Performance

The compiled Crystal version seems quite a lot faster compared with the Ruby version.

	time ./dedup.rb /home/share/photos -debug 
	Total number of analyzed files: 70033
	Number of files that share size with at least another file: 19065
	Number of files that share size and file start with at least one other file: 16545
	Number for files that share size and hash (SHA1) with at least one other file: 16536
	Detected file extensions currently not covered:
	, 51 files
	xmp, 895 files
	...
	rb, 1 files
	0,/home/share/photos/Foto 2009/FotoD80 2009/090107_hus_hackspett_mm/DSC_0021.NEF
	0,/home/share/photos/Foto 2009/FotoD80 2009/090401_vinterfjäll/DSC_0021.NEF
	0,/home/share/photos/Foto 2009/FotoD80 2009/Ny m090324_Husstatus_Alicia/DSC_0021.NEF
	0,/home/share/photos/Foto 2008 och tidigare/Foto_D80_2008/081027_allmän_höst/DSC_0021.NEF
	0,/home/share/photos/Lightroom_back_up/081027_allmän_höst/DSC_0021.NEF
	...
	7301,/home/share/photos/Foto_2020/2020_iPhone1_2/IMG_4180 2.JPG
	7301,/home/share/photos/Foto_2020/2020_iPhone1_2/IMG_4180 3.JPG
	7301,/home/share/photos/Foto_2020/2020_iPhone1_2/IMG_4180.JPG
	   36m09.42s real    15m38.62s user     7m48.83s system

Crystal version is roughly 70 times faster than the Ruby version.

	time ./dedup /home/share/photos -debug 
	Total number of analyzed files: 70033
	Number of files that share size with at least another file: 19065
	Number of files that share size and file start with at least one other file: 16545
	Number for files that share size and SHA256 hash with at least one other file: 16536
	Detected file extensions currently not covered:
	, 51 files
	xmp, 895 files
	...
	rb, 1 files
	0,/home/share/photos/Foto 2009/FotoD80 2009/090107_hus_hackspett_mm/DSC_0021.NEF
	0,/home/share/photos/Foto 2009/FotoD80 2009/090401_vinterfjäll/DSC_0021.NEF
	0,/home/share/photos/Foto 2009/FotoD80 2009/Ny m090324_Husstatus_Alicia/DSC_0021.NEF
	0,/home/share/photos/Foto 2008 och tidigare/Foto_D80_2008/081027_allmän_höst/DSC_0021.NEF
	0,/home/share/photos/Lightroom_back_up/081027_allmän_höst/DSC_0021.NEF
	...
	7301,/home/share/photos/Foto_2020/2020_iPhone1_2/IMG_4180 2.JPG
	7301,/home/share/photos/Foto_2020/2020_iPhone1_2/IMG_4180 3.JPG
	7301,/home/share/photos/Foto_2020/2020_iPhone1_2/IMG_4180.JPG
	    0m43.59s real     0m14.33s user     0m20.46s system

Both version produce the same result.

### Deduplication

It is possible to add `-dedup` flag to command to de-duplicate identical copies of files.

This feature make use of UNIX hard links and is only useful on UNIX file systems with hard link support.

File names that previously pointed to multiple copies of files with same content, will after deduplication, point to a single file (with a single i-node nunber). The required space is also reduced to a single file.

To check the result after deduplication `ls` and `du` can be used.

	ls -lRi <folder>
	du -h <folder>

The `-i` flag will print i-node numbers for each file. Disk usage command will give the resulting space used by folder.

Do some tests on a copy of a folder BEFORE you use this on you complete photo catalog to make sure the tool does what you expect.

### Process duplicates

You can make a simple script that process the output

For instance this script (`process.rb`) filters out the first occurance of each file group

	#!/usr/bin/env ruby
		
	prev = -1
	ARGF.each do |l|
		cur = l.split(",")[0].to_i
		if cur != prev
			prev = cur
		else
			puts l
		end
	end

### Runtime issues

If you have problem like the following in the compiled Crystal version.

	Unhandled exception: Error opening file '...' with mode 'r': Too many open files (Errno)	
	Failed to raise an exception: END_OF_STACK
	[0xce853fd8706] __crystal_sigfault_handler +39750
	...

It actually is a stack limitation issue. You may need to raise the stack limitation of your OS.

On e.g. OpenBSD change stack limitation in [login.conf](https://man.openbsd.org/login.conf.5).

If your user is associted with the `staff` login class, change stack limitation in `login.conf` as follows.

	staff:\
		:stacksize-cur=32M:

You can check your login class via `userinfo <user>`.

	$ userinfo peter
	login	peter
	passwd	*
	uid	1000
	groups	peter wheel
	change	NEVER
	class	staff
	...
