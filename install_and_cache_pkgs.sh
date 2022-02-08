#!/bin/bash

# Fail on any error.
set -e

# Directory that holds the cached packages.
cache_dir=$1

# List of the packages to use.
packages="${@:2}"

package_count=$(echo $packages | wc -w)
echo "Clean installing and caching $package_count package(s)."
echo "Package list:"
for package in $packages; do
  echo "- $package"
done

echo -n "Updating APT package list..."
sudo apt-get update > /dev/null
echo "done."

manifest=
echo "Clean installing and caching $(echo $packages | wc -w) packages..."
for package in $packages; do
  cache_filepath=$cache_dir/$package.tar.gz

  echo "- $package"
  echo -n "  Determine dependencies..."
  dependencies=$(apt-get install xvfb --print-uris | sed -n "s@'.*/\([^_]\+\)_.*\.deb' .*@\1@p")
  echo "done."

  echo -n "  Installing..."
  sudo apt-get --yes install $package > /dev/null
  echo "done."

  echo -n "  Caching to $cache_filepath..."
  # Pipe all package files (no folders) to Tar.
  dpkg -L $package |
    while IFS= read -r f; do     
      if test -f $f; then echo ${f:1}; fi;  #${f:1} removes the leading slash that Tar disallows
    done | 
    xargs tar -czf $cache_filepath -C /    
  echo "done."
  
  echo -n "  Extending manifest..."
  manifest=$manifest$package:$(dpkg -s $package | grep Version | awk '{print $2}'),
  echo "done."
  
  echo "  Caching $(echo $dependencies | wc -w) dependencies..."
  for dependency in $dependencies; do 
    cache_filepath=$cache_dir/$dependency.tar.gz
   
    echo -n "    Caching to $cache_filepath..."
    # Pipe all package files (no folders) to Tar.
    dpkg -L $dependency |
      while IFS= read -r f; do     
        if test -f $f; then echo ${f:1}; fi;  #${f:1} removes the leading slash that Tar disallows
      done | 
      xargs tar -czf $cache_filepath -C /   
    echo "done."
  
    echo -n "    Extending manifest..."
    manifest=$manifest$dependency:$(dpkg -s $dependency | grep Version | awk '{print $2}'),
    echo "done."  
  done
done

manifest_filepath="$cache_dir/manifest.log"
echo -n "Writing package manifest to $manifest_filepath..."
# Remove trailing comma.
echo ${manifest:0:-1} > $manifest_filepath
echo "done."
