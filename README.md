[![CI](https://github.com/sul-dlss/purl-fetcher/actions/workflows/ruby.yml/badge.svg)](https://github.com/sul-dlss/purl-fetcher/actions/workflows/ruby.yml)

# purl-fetcher

An HTTP API for querying and updating [PURL](https://github.com/sul-dlss/purl)s. See the [API section](#api) below for docs.

## Requirements

1. Ruby (3.2 or greater)
2. [bundler](http://bundler.io/) gem
3. [Apache Kafka](http://kafka.apache.org/) (0.10 or greater), or [Docker](https://www.docker.com/)

## Installation

Clone the repository:

```bash
git clone https://github.com/sul-dlss/purl-fetcher.git
cd purl-fetcher
```

Install dependencies:

```bash
bundle install
```

Set up the database:

```
rake db:migrate
```

## Developing

The API communicates with a Kafka broker to dispatch and process updates asynchronously. You can run a Kafka broker locally, or use the provided `docker-compose` configuration:

```bash
docker-compose up
```

Then, in a separate terminal, start a development API server:

```bash
bin/rails server
```

Finally, in another terminal, you can run the Kafka consumer to process updates from the Kafka broker:

```bash
bundle exec racecar PurlUpdatesConsumer
```

### Making requests

You can make requests to the API using `curl` or a similar tool. To add an object to the database, you can first download its public Cocina JSON from production PURL:

```bash
curl https://purl.stanford.edu/bb112zx3193.json > bb112zx3193.json
```

Then, you can use the `POST /purls/:druid` endpoint to add the object to the database:

```bash
curl -X POST -H "Content-Type: application/json" -d @bb112zx3193.json http://localhost:3000/purls/bb112zx3193
```

After the object has been added, it will show up in the list of changes:

```bash
curl http://localhost:3000/docs/changes
```

## Testing

The full test suite (with RuboCop style enforcement) can be run with the default rake task:

```bash
rake
```

The tests can be run without RuboCop style enforcement:

```bash
rake spec
```

The RuboCop style enforcement can be run without running the tests:

```bash
rake rubocop
```

## API

### Purls

#### GET `/purls/:druid`

`GET /purls/:druid`

##### Summary

Display a single purl

##### Description

The GET `/purls/:druid` endpoint provides the ability to display a PURL document. This endpoint is used by [purl](https://github.com/sul-dlss/purl/) to know if an item should be in the sitemap

##### Parameters

| Name      | Located In | Description                                | Required | Schema                          | Default |
| --------- | ---------- | ------------------------------------------ | -------- | ------------------------------- | ------- |
| `druid`   | url        | Druid of a specific PURL                   | Yes      | string eg(`druid:cc1111dd2222`) | null    |
| `version` | header     | Version of the API request eg(`version=1`) | No       | integer                         | 1       |

##### Example Response

```json
{
  "druid": "druid:dd111ee2222",
  "latest_change": "2014-01-01T00:00:00Z",
  "true_targets": ["PURL sitemap"],
  "collections": ["druid:oo000oo0001"]
}
```

#### POST `/purls/:druid`

`POST /purls/:druid`

##### Summary

Purl Document Update

##### Description

The POST `/purls/:druid` endpoint provides the ability to create or update a PURL document from public Cocina JSON. This endpoint is used by [dor-services-app](https://github.com/sul-dlss/dor-services-app/) as part of SDR workflows.

##### Parameters

| Name      | Located In | Description                                | Required | Schema                          | Default |
| --------- | ---------- | ------------------------------------------ | -------- | ------------------------------- | ------- |
| `druid`   | url        | Druid of a specific PURL                   | Yes      | string eg(`druid:cc1111dd2222`) | null    |
| `version` | header     | Version of the API request eg(`version=1`) | No       | integer                         | 1       |

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

The `/docs/changes` endpoint provides information about public PURL documents that have been changed, their release tag information and also collection association. This endpoint can be queried using [purl_fetcher-client](https://github.com/sul-dlss/purl_fetcher-client).

##### Parameters

| Name             | Located In | Description                                | Required | Schema              | Default                |
| ---------------- | ---------- | ------------------------------------------ | -------- | ------------------- | ---------------------- |
| `first_modified` | query      | Limit response by a beginning datetime     | No       | datetime in iso8601 | earliest possible date |
| `last_modified`  | query      | Limit response by an ending datetime       | No       | datetime in iso8601 | current time           |
| `page`           | query      | request a specific page of results         | No       | integer             | 1                      |
| `per_page`       | query      | Limit the number of results per page       | No       | integer (1 - 10000) | 100                    |
| `target`         | query      | Release tag to filter on                   | No       | string              | nil                    |
| `version`        | header     | Version of the API request eg(`version=1`) | No       | integer             | 1                      |

##### Example Response

```json
{
  "changes": [
    {
      "druid": "druid:dd111ee2222",
      "latest_change": "2014-01-01T00:00:00Z",
      "true_targets": ["SearchWorksPreview"],
      "collections": ["druid:oo000oo0001"]
    },
    {
      "druid": "druid:bb111cc2222",
      "latest_change": "2015-01-01T00:00:00Z",
      "true_targets": ["SearchWorks", "Revs", "SearchWorksPreview"],
      "collections": ["druid:oo000oo0001", "druid:oo000oo0002"]
    },
    {
      "druid": "druid:aa111bb2222",
      "latest_change": "2016-06-06T00:00:00Z",
      "true_targets": ["SearchWorksPreview"]
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

#### `/docs/deletes`

`GET /docs/deletes`

##### Summary

Purl Document Deletes

##### Description

The `/docs/deletes` endpoint provides information about public PURL documents that have been deleted. This endpoint can be queried using [purl_fetcher-client](https://github.com/sul-dlss/purl_fetcher-client).

##### Parameters

| Name             | Located In | Description                                | Required | Schema              | Default                |
| ---------------- | ---------- | ------------------------------------------ | -------- | ------------------- | ---------------------- |
| `first_modified` | query      | Limit response by a beginning datetime     | No       | datetime in iso8601 | earliest possible date |
| `last_modified`  | query      | Limit response by an ending datetime       | No       | datetime in iso8601 | current time           |
| `page`           | query      | request a specific page of results         | No       | integer             | 1                      |
| `per_page`       | query      | Limit the number of results per page       | No       | integer (1 - 10000) | 100                    |
| `target`         | query      | Release tag to filter on                   | No       | string              | nil                    |
| `version`        | header     | Version of the API request eg(`version=1`) | No       | integer             | 1                      |

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

#### `/collections/:druid/purls`

`GET /collections/:druid/purls`

##### Summary

Collection Purls route

##### Description

The `/collections/:druid/purls` endpoint a listing of Purls for a specific collection. This endpoint is used by the [Exhibits](https://github.com/sul-dlss/exhibits) application.

##### Parameters

| Name       | Located In | Description                                | Required | Schema                          | Default |
| ---------- | ---------- | ------------------------------------------ | -------- | ------------------------------- | ------- |
| `druid`    | url        | Druid of a specific collection             | Yes      | string eg(`druid:cc1111dd2222`) | null    |
| `page`     | query      | request a specific page of results         | No       | integer                         | 1       |
| `per_page` | query      | Limit the number of results per page       | No       | integer (1 - 10000)             | 100     |
| `version`  | header     | Version of the API request eg(`version=1`) | No       | integer                         | 1       |

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

### Released items

#### `/released/:tag`

`GET /released/:tag`

##### Parameters

| Name       | Located In | Description                                | Required | Schema                          | Default |
| ---------- | ---------- | ------------------------------------------ | -------- | ------------------------------- | ------- |
| `tag`    | url        | Tag to search for             | Yes      | string eg(`PURL%20sitemap`) | null    |


##### Summary

List the PURLs that should display on the sitemap.

##### Description

This is used by the PURL application to generate a sitemap

##### Example Response

```json
[
    {
      "druid": "druid:ee111ff2222",
      "updated_at": "2016-01-03T00:00:00.000Z",
    },
...
    {
      "druid": "druid:cc111dd2222",
      "updated_at": "2016-01-02T00:00:00.000Z",
    }
]
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
