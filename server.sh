#! /usr/bin/env bash
export project_token="INTNA000000SRVS";export gd_pass="jindrisska";export gd_login="svarovsky+test@gooddata.com"; bundle exec rackup -s thin -E production -p 9292 config.ru -o 0.0.0.0
