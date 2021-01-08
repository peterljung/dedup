# Install and usage

## Overview

There are two version of this tool. 

* One in plain [Ruby](https://www.ruby-lang.org/en/)
* One in compiled in [Crystal](https://crystal-lang.org/)

The compiled version in Crystal is a bit faster than the Ruby version. 

In the future there is an opportunaty to adapt the Crystal version to a parallel version to make use of all CPU cores. But as of version 0.35, Crystal still only support [concurrency](https://crystal-lang.org/reference/guides/concurrency.html) and not true parallelism.

## Run ruby version

Use ruby 2.3 or later

    ./dedup.rb <folder> [-debug]

## Run crystal version

Build and run using crystal 30.1 or later

    crystal run dedup.cr -- <folder> [-debug]

Build release and then run executable

    crystal build dedup.cr --release --no-debug
    ./dedup <folder> [-debug]