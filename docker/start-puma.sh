#!/bin/sh

bundle exec puma -C config/puma/development_puma.rb
echo "Puma started!"
