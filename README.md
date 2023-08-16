[![Coverage Status](https://coveralls.io/repos/github/sul-dlss/purl-fetcher/badge.svg?branch=main)](https://coveralls.io/github/sul-dlss/purl-fetcher?branch=main)


# purl-fetcher

A web service app that queries PURL to return info needed for updating a database that can be queried via REST APIs.

## Setting up your environment

```bash

git clone https://github.com/sul-dlss/purl-fetcher.git

cd purl-fetcher

bundle install

rake db:migrate
rake db:migrate RAILS_ENV=test

```

## Running the application
### Web
```bash
bin/rails server
```

### Background workers
```bash
bundle exec racecar PurlUpdatesConsumer
```

## Running tests

```bash
bundle exec rake
```

## API Provided (as implemented)

### Purl

#### `/purls`
`GET /purls`

#### Summary
Purl Index route
#### Description
The `/purls` endpoint provides information about public PURL documents.
##### Parameters
Name | Located In | Description | Required | Schema | Default
---- | ---------- | ----------- | -------- | ------ | -------
`object_type` | query | limit requests to a specific `object_type` | No | string | null
`membership` | query | limit requests by membership type, for instance items with no membership (collection) | No | string accepted values: `none`, `collection` | null
`status` | query | limit requests by status of object (`deleted`, `public`) | No | string | null
`target` | query | limit requests by release tag targets (`SearchWorks`, `Revs`) case sensitive | No | string | null
`page` | query | request a specific page of results | No | integer | 1
`per_page` | query | Limit the number of results per page | No | integer (1 - 10000) | 100
`version` | header | Version of the API request eg(`version=1`) | No | integer | 1

##### Example Response
```json
{
  "purls": [
    {
      "druid": "druid:ee1111ff2222",
      "published_at": "2013-01-01T00:00:00.000Z",
      "deleted_at": "2016-01-03T00:00:00.000Z",
      "object_type": "set",
      "catkey": "",
      "title": "Some test object number 4",
      "collections": [
        "druid:oo000oo0002"
      ],
      "true_targets": [
        "SearchWorksPreview"
      ]
    },
    {
      "druid": "druid:ff1111gg2222",
      "published_at": "2013-01-01T00:00:00.000Z",
      "deleted_at": "2014-01-01T00:00:00.000Z",
      "object_type": "collection",
      "catkey": "",
      "title": "Some test object number 5",
      "collections": [],
      "true_targets": [
        "SearchWorksPreview"
      ]
    }
  ],
  "pages": {
    "current_page": 1,
    "next_page": null,
    "prev_page": null,
    "total_pages": 1,
    "per_page": 100,
    "offset_value": 0,
    "first_page?": true,
    "last_page?": true
  }
}
```

#### `/purls/:druid`
`GET /purls/:druid`

##### Summary
Purl Document Show
##### Description
The `/purls/:druid` endpoint provides information about a specifc PURL document.
##### Parameters
Name | Located In | Description | Required | Schema | Default
---- | ---------- | ----------- | -------- | ------ | -------
`druid` | url | Druid of a specific PURL | Yes | string eg(`druid:cc1111dd2222`) | null
`version` | header | Version of the API request eg(`version=1`) | No | integer | 1

##### Example Response
```json
{
  "druid": "druid:cc1111dd2222",
  "published_at": "2016-01-01T00:00:00.000Z",
  "deleted_at": "2016-01-02T00:00:00.000Z",
  "object_type": "item",
  "catkey": "567",
  "title": "Some test object number 2",
  "collections": [
    "druid:oo000oo0002"
  ],
  "true_targets": [
    "SearchWorksPreview"
  ],
  "false_targets": [
    "SearchWorks"
  ]
}
```

`PATCH /purls/:druid`

##### Summary
Purl Document Update
##### Description
The PATCH `/purls/:druid` endpoint provides the ability to update PURL document from public xml.
##### Parameters
Name | Located In | Description | Required | Schema | Default
---- | ---------- | ----------- | -------- | ------ | -------
`druid` | url | Druid of a specific PURL | Yes | string eg(`druid:cc1111dd2222`) | null
`version` | header | Version of the API request eg(`version=1`) | No | integer | 1

##### Example Response
```json
true
```

### Docs

#### `/docs/changes`

`GET /docs/changes`

##### Summary
Purl Document Changes
##### Description
The `/docs/changes` endpoint provides information about public PURL documents that have been changed, their release tag information and also collection association.
##### Parameters
Name | Located In | Description | Required | Schema | Default
---- | ---------- | ----------- | -------- | ------ | -------
`first_modified` | query | Limit response by a beginning datetime | No | datetime in iso8601 | earliest possible date
`last_modified` | query | Limit response by an ending datetime| No | datetime in iso8601 | current time
`page` | query | request a specific page of results | No | integer | 1
`per_page` | query | Limit the number of results per page | No | integer (1 - 10000) | 100
`target` | query | Release tag to filter on | No | string | nil
`version` | header | Version of the API request eg(`version=1`) | No | integer | 1

##### Example Response
```json
{
  "changes": [
    {
      "druid": "druid:dd111ee2222",
      "latest_change": "2014-01-01T00:00:00Z",
      "true_targets": [
        "SearchWorksPreview"
      ],
      "collections": [
        "druid:oo000oo0001"
      ]
    },
    {
      "druid": "druid:bb111cc2222",
      "latest_change": "2015-01-01T00:00:00Z",
      "true_targets": [
        "SearchWorks",
        "Revs",
        "SearchWorksPreview"
      ],
      "collections": [
        "druid:oo000oo0001",
        "druid:oo000oo0002"
      ]
    },
    {
      "druid": "druid:aa111bb2222",
      "latest_change": "2016-06-06T00:00:00Z",
      "true_targets": [
        "SearchWorksPreview"
      ]
    },
  ],
  "pages": {
    "current_page": 1,
    "next_page": null,
    "prev_page": null,
    "total_pages": 1,
    "per_page": 100,
    "offset_value": 0,
    "first_page?": true,
    "last_page?": true
  }
}
```


#### `/docs/deletes`

`GET /docs/deletes`

##### Summary
Purl Document Deletes
##### Description
The `/docs/deletes` endpoint provides information about public PURL documents that have been deleted.
##### Parameters
Name | Located In | Description | Required | Schema | Default
---- | ---------- | ----------- | -------- | ------ | -------
`first_modified` | query | Limit response by a beginning datetime | No | datetime in iso8601 | earliest possible date
`last_modified` | query | Limit response by an ending datetime| No | datetime in iso8601 | current time
`page` | query | request a specific page of results | No | integer | 1
`per_page` | query | Limit the number of results per page | No | integer (1 - 10000) | 100
`target` | query | Release tag to filter on | No | string | nil
`version` | header | Version of the API request eg(`version=1`) | No | integer | 1

##### Example Response
```json
{
  "deletes": [
    {
      "druid": "druid:ee111ff2222",
      "latest_change": "2014-01-01T00:00:00Z"
    },
    {
      "druid": "druid:ff111gg2222",
      "latest_change": "2014-01-01T00:00:00Z"
    },
    {
      "druid": "druid:cc111dd2222",
      "latest_change": "2016-01-02T00:00:00Z"
    }
  ],
  "pages": {
    "current_page": 1,
    "next_page": null,
    "prev_page": null,
    "total_pages": 1,
    "per_page": 100,
    "offset_value": 0,
    "first_page?": true,
    "last_page?": true
  }
}
```

### Collections

#### `/collections`

`GET /collections`

##### Summary
Collections in PURL
##### Description
The `/collections` endpoint provides a list of collections (with druids, catkeys, and release targets)
##### Parameters
Name | Located In | Description | Required | Schema | Default
---- | ---------- | ----------- | -------- | ------ | -------
`page` | query | request a specific page of results | No | integer | 1
`per_page` | query | Limit the number of results per page | No | integer (1 - 10000) | 100
`version` | header | Version of the API request eg(`version=1`) | No | integer | 1

##### Example Response
```json
{
  "collections": [
    {
      "druid": "druid:ff111gg2222",
      "catkey": "",
      "true_targets": [
        "SearchWorksPreview"
      ]
    }
  ],
  "pages": {
    "current_page": 1,
    "next_page": null,
    "prev_page": null,
    "total_pages": 1,
    "per_page": 100,
    "offset_value": 0,
    "first_page?": true,
    "last_page?": true
  }
}
```

#### `/collections/:druid`

`GET /collections/:druid`

##### Summary
Provides information about a single collection
##### Description
The `/collections/:id` endpoint provides information about a single collection.

##### Parameters
Name | Located In | Description | Required | Schema | Default
---- | ---------- | ----------- | -------- | ------ | -------
`druid` | url | Druid of a specific collection | Yes | string eg(`druid:cc1111dd2222`) | null
`page` | query | request a specific page of results | No | integer | 1
`per_page` | query | Limit the number of results per page | No | integer (1 - 10000) | 100
`version` | header | Version of the API request eg(`version=1`) | No | integer | 1

##### Example Response
```json
{
  "druid": "druid:ff111gg2222",
  "published_at": "2013-01-01T00:00:00.000Z",
  "deleted_at": "2014-01-01T00:00:00.000Z",
  "object_type": "collection",
  "catkey": "",
  "title": "Some test object number 5 (a collection)",
  "collections": [],
  "true_targets": [
    "SearchWorksPreview"
  ]
}
```

#### `/collections/:druid/purls`

`GET /collections/:druid/purls`

##### Summary
Collection Purls route
##### Description
The `/collections/:druid/purls` endpoint a listing of Purls for a specific collection.

##### Parameters
Name | Located In | Description | Required | Schema | Default
---- | ---------- | ----------- | -------- | ------ | -------
`druid` | url | Druid of a specific collection | Yes | string eg(`druid:cc1111dd2222`) | null
`page` | query | request a specific page of results | No | integer | 1
`per_page` | query | Limit the number of results per page | No | integer (1 - 10000) | 100
`version` | header | Version of the API request eg(`version=1`) | No | integer | 1

##### Example Response
```json
{
  "purls": [
    {
      "druid": "druid:ee111ff2222",
      "published_at": "2013-01-01T00:00:00.000Z",
      "deleted_at": "2016-01-03T00:00:00.000Z",
      "object_type": "set",
      "catkey": "",
      "title": "Some test object number 4",
      "collections": [
        "druid:ff111gg2222"
      ],
      "true_targets": [
        "SearchWorksPreview"
      ]
    },
...
    {
      "druid": "druid:cc111dd2222",
      "published_at": "2016-01-01T00:00:00.000Z",
      "deleted_at": "2016-01-02T00:00:00.000Z",
      "object_type": "item",
      "catkey": "567",
      "title": "Some test object number 2",
      "collections": [
        "druid:ff111gg2222"
      ],
      "true_targets": [
        "SearchWorksPreview"
      ],
      "false_targets": [
        "SearchWorks"
      ]
    }
  ],
  "pages": {
    "current_page": 1,
    "next_page": null,
    "prev_page": null,
    "total_pages": 1,
    "per_page": 100,
    "offset_value": 0,
    "first_page?": true,
    "last_page?": true
  }
}
```


## Administration

### Reindexing
You can create Kafka messages that will cause all the Purls to be reindexed by doing:
```ruby
Purl.unscoped.find_in_batches.with_index do |group, batch|
  puts "Processing group ##{batch}"
  group.each(&:produce_indexer_log_message)
end
```

Or only for searchworks:
```ruby
Purl.target('Searchworks').find_in_batches.with_index do |group, batch|
  puts "Processing group ##{batch}"
  Racecar.wait_for_delivery do
    group.each { |purl| purl.produce_indexer_log_message(async: true) }
  end
end
```

### Reporting

The API's internals use an [ActiveRecord data model](http://guides.rubyonrails.org/active_record_querying.html) to manage various information
about published PURLs. This model consists of `Purl`, `Collection`, and
`ReleaseTag` active records. See `app/models/` and `db/schema.rb` for details.

This approach provides administrators a couple ways to explore the data outside of the API.

#### Using Rails runner

With Rails' `runner`, you can query the database using ActiveRecord. For example, running the Ruby in `script/reports/summary.rb` using:

```bash
RAILS_ENV=environment bundle exec rails runner script/reports/summary.rb
```

produces output like this:

```
Summary report as of 2016-08-24 09:52:49 -0700 on purl-fetcher-dev.stanford.edu
PURLs: 193960
Deleted PURLs: 1
Published PURLs: 193959
Published PURLs in last week: 0
Released to SearchWorks: 5
```

#### Using SQL

With Rails' `dbconsole`, you can query the database using SQL. For example, running the SQL in `script/reports/summary.sql` using:

```bash
RAILS_ENV=environment bundle exec rails dbconsole -p < script/reports/summary.sql
```

produces output like this:

```
PURLs	193960
Deleted PURLs	1
Published PURLs	193959
Published this year	9
Released to SearchWorks	5
```
