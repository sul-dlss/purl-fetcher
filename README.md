[![Build Status](https://travis-ci.org/sul-dlss/purl-fetcher.png?branch=master)](https://travis-ci.org/sul-dlss/purl-fetcher) [![Coverage Status](https://coveralls.io/repos/github/sul-dlss/purl-fetcher/badge.svg?branch=master)](https://coveralls.io/github/sul-dlss/purl-fetcher?branch=master)


# purl-fetcher

A web service app that queries PURL to return info needed for indexing or other purposes.

## Setting up your environment

```bash

git clone https://github.com/sul-dlss/purl-fetcher.git

cd purl-fetcher

bundle install
rake purlfetcher:config

# Edit config/database.yml file

rake db:migrate
rake db:migrate RAILS_ENV=test

```

## Running the application

```bash
rails server
```

## Logging

There are three log files:

* `indexing.log` - items that are being indexed (added or deleted)
* `[environment].log` - Rails logger
* `access.log` and `error.log` from Apache - traffic to the HTTP APIs

## Running tests

### To run the tests

```bash
bundle exec rake
```

This command will run all of the tests, run rubocop and generate new documentation.

## Generate documentation

To generate documentation into the "doc" folder:

```bash
yard
```

To keep a local server running with up to date code documentation that you can view in your browser:

```bash
yard server --reload
```
