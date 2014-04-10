#! /usr/bin/env bash
bundle exec rackup -s thin -E production -p 9292 config.ru

