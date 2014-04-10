#! /usr/bin/env bash
export project_token=;export gd_pass=;export gd_login=""; bundle exec rackup -s thin -E production -p 9292 config.ru
