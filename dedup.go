/*
# Copyright (c) 2023 Peter Ljung <peter@uniply.eu>
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
*/

package main

import (
	"bytes"
	"crypto/sha1"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path"
	"path/filepath"
)

func help() {
	s := "Usage: go run cli/main.go <folder>\n" +
		"       go build cli/main.go\n" +
		"\n" +
		"List all files that are duplicates based on content hash\n" +
		"\n" +
		"Output as:\n" +
		"Index of duplication, filename\n"
	fmt.Printf(s)
}

func validSuffix(f string) bool {
	exts := []string{".mp3", ".mp4", ".ogg", ".flac", ".wav", ".aiff", ".mid", ".png", ".jpg", ".gif", ".bmp", ".tga",
		".jpeg", ".tif", ".tiff", ".nef", ".pdf", ".mov"}
	e := path.Ext(f)
	for _, x := range exts {
		if x == e {
			return true
		}
	}
	return false
}

// Group all files by file size recursively under path
func groupBySize(path string) (map[int64][]string, error) {
	ans := make(map[int64][]string)
	if err := filepath.WalkDir(path, func(path string, info fs.DirEntry, err error) error {
		if err == nil &&
			!info.IsDir() &&
			validSuffix(path) {
			if finfo, err := info.Info(); err == nil {
				size := finfo.Size()
				if _, ok := ans[size]; !ok {
					ans[size] = make([]string, 0)
				}
				ans[size] = append(ans[size], path)
				return nil
			} else {
				return err
			}
		} else {
			return err
		}
	}); err == nil {
		return ans, nil
	} else {
		return ans, err
	}
}

// Group paths files based on first size bytes of if size is zero the whole file
func groupByContent(paths []string, size int) map[string][]string {
	var buf []byte
	if size > 0 {
		buf = make([]byte, size)
	}
	sha := ""
	ans := make(map[string][]string)
	for _, path := range paths {
		if file, err := os.Open(path); err == nil {
			defer file.Close()
			if size == 0 {
				// Calculate SHA1 of whole file
				hash := sha1.New()
				if _, err := io.Copy(hash, file); err == nil {
					bs := hash.Sum(nil)
					sha = bytes.NewBuffer(bs[:]).String()
				} else {
					fmt.Printf("SHA1 Error: %s\n", err.Error())
				}
			} else {
				// Calculate SHA1 of first part of file
				if n, err := file.Read(buf); err == nil {
					bs := sha1.Sum(buf[:n])
					sha = bytes.NewBuffer(bs[:]).String()
				}
			}
			if len(sha) > 0 {
				if _, ok := ans[sha]; !ok {
					ans[sha] = make([]string, 0)
				}
				ans[sha] = append(ans[sha], path)
			}
		}
	}
	return ans
}

func main() {
	path := ""
	if len(os.Args) == 1 {
		help()
		os.Exit(0)
	} else if len(os.Args) == 2 {
		path = os.Args[1]
	} else {
		help()
		os.Exit(0)
	}
	// Group by file size
	sizeMap, err := groupBySize(path)
	if err != nil {
		fmt.Println(err.Error())
		os.Exit(0)
	}
	// Group by first 8192 bytes of each file
	startGs := make([][]string, 0)
	for _, g := range sizeMap {
		sg := groupByContent(g, 8192)
		for _, g := range sg {
			if len(g) > 1 {
				startGs = append(startGs, g)
			}
		}
	}
	// Group by whole file
	fileGs := make([][]string, 0)
	for _, g := range startGs {
		sg := groupByContent(g, 0)
		for _, g := range sg {
			if len(g) > 1 {
				fileGs = append(fileGs, g)
			}
		}
	}
	// Print final groups
	for i, fs := range startGs {
		for _, f := range fs {
			fmt.Printf("%d,%s\n", i, f)
		}
	}
}
