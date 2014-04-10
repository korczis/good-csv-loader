# good-csv-loader

## Prerequisites

* Ruby
* Rubygems
* Bundler

## Getting started 

Getting started is quite simple, see following steps.

### Clone sources

```
git clone https://github.com/korczis/good-csv-loader.git
cd good-csv-loader
```

### Install required gems

```
bundle install
```

### Run sinatra web server

```
bundle exec rackup -s thin -E production -p 9292 config.ru

load http://localhost:9292/index.html in your browser

call send_hello() in your browser console
```

