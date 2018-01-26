#!/bin/sh

bundle config build.nokogiri --use-system-libraries && \
bundle config --delete bin

bundle check || bundle install
