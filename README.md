# File duplicate detector

## Overview

This project contains a simple script to help identify duplicate files based on file content rather than file name.

The tool take a single folder and determine duplicates as output.

## Install and usage

There are two version of this tool.

* One in plain [Ruby](https://www.ruby-lang.org/en/)
* One in compiled [Crystal](https://crystal-lang.org/)

The compiled version in Crystal is a bit faster than the Ruby version.

In the future there is an opportunity to adapt the Crystal version to a parallel version to make use of all CPU cores. But as of version 0.35, Crystal still only support [concurrency](https://crystal-lang.org/reference/guides/concurrency.html) and not true parallelism.

### Run ruby version

Use ruby 2.3 or later

    ./dedup.rb <folder> [-debug]

### Run crystal version

Build and run using crystal 30.1 or later

    crystal run dedup.cr -- <folder> [-debug]

Build release and then run executable

    crystal build dedup.cr --release --no-debug
    ./dedup <folder> [-debug]

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

Crystal version is roughly 70 times faster than the ruby version.

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

### Runtime issues

If you have problem like

	Unhandled exception: Error opening file '...' with mode 'r': Too many open files (Errno)	
	Failed to raise an exception: END_OF_STACK
	[0xce853fd8706] __crystal_sigfault_handler +39750
	...

It actually is a stack limitation issue.

Raise the stack limitation in `login.conf` if needed.

In `login.conf` for your `user` running the script:

	user:\
		:stacksize-cur=32M:
