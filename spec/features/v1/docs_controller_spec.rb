require 'rails_helper'

describe(V1::DocsController, integration: true, type: :request) do
  let(:pagination_response) do
    {
      current_page: 1,
      next_page: nil,
      prev_page: nil,
      total_pages: 1,
      per_page: 100,
      offset_value: 0,
      first_page?: true,
      last_page?: true
    }
  end

  it "tests the docs changes API call for all time" do
    get changes_docs_path
    expect(response).to be_successful
    results = JSON.parse(response.body).with_indifferent_access
    expected_results = { changes:
      [
        hash_including(druid: "druid:dd111ee2222", latest_change: "2014-01-01T00:00:00Z", true_targets: ["SearchWorksPreview", "ContentSearch"], collections: ["druid:ff111gg2222"]),
        hash_including(druid: "druid:bb111cc2222", catkey: 'catkey111', latest_change: "2015-01-01T00:00:00Z", true_targets: ["SearchWorks", "Revs", "SearchWorksPreview", "ContentSearch"], collections: ["druid:ff111gg2222"]),
        hash_including(druid: "druid:aa111bb2222", latest_change: "2016-06-06T00:00:00Z", true_targets: ["SearchWorksPreview", "ContentSearch"], collections: ["druid:gg111hh2222"]),
        hash_including(druid: "druid:gg111hh2222", latest_change: "2016-06-08T00:00:00Z", true_targets: ["SearchWorksPreview", "ContentSearch"]),
        hash_including(druid: "druid:hh111ii2222", latest_change: "2016-06-09T00:00:00Z", true_targets: ["SearchWorksPreview", "ContentSearch"])
      ],
      pages: pagination_response,
      range: hash_including('first_modified', 'last_modified')
    }
    expect(results).to include(expected_results)
  end

  it "test the docs changes API call for a specified time period" do
    Purl.find_by_druid('druid:dd111ee2222').update_column(:updated_at, Time.zone.parse('2014/01/01').iso8601)
    get changes_docs_path(first_modified: Time.zone.parse('2013/12/31').iso8601, last_modified: Time.zone.parse('2014/01/02').iso8601)
    expect(response).to be_successful
    results = JSON.parse(response.body).with_indifferent_access
    expected_results = { changes:
      [
        hash_including(druid: "druid:dd111ee2222", latest_change: "2014-01-01T00:00:00Z", true_targets: ["SearchWorksPreview", "ContentSearch"], collections: ["druid:ff111gg2222"])
      ], pages: pagination_response,
      range: hash_including('first_modified', 'last_modified')
    }
    expect(results).to include(expected_results)
  end

  it "test the docs deletes API call for all time" do
    get deletes_docs_path
    expect(response).to be_successful
    results = JSON.parse(response.body).with_indifferent_access
    expected_results = { deletes:
      [
        hash_including(druid: "druid:ff111gg2222", latest_change: "2014-01-01T00:00:00Z"),
        hash_including(druid: "druid:cc111dd2222", latest_change: "2016-01-02T00:00:00Z"),
        hash_including(druid: "druid:ee111ff2222", latest_change: "2016-01-03T00:00:00Z")
      ], pages: pagination_response,
      range: hash_including('first_modified', 'last_modified')
    }
    expect(results).to include(expected_results)
  end

  it "test the docs deletes API call for a specified time period" do
    get deletes_docs_path(first_modified: Time.zone.parse('2015/12/31').iso8601, last_modified: Time.zone.parse('2016/01/03').iso8601)
    expect(response).to be_successful
    results = JSON.parse(response.body).with_indifferent_access
    expected_results = { deletes:
      [
        hash_including(druid: "druid:cc111dd2222", latest_change: "2016-01-02T00:00:00Z"),
        hash_including(druid: "druid:ee111ff2222", latest_change: "2016-01-03T00:00:00Z")
      ], pages: pagination_response,
      range: hash_including('first_modified', 'last_modified')
    }
    expect(results).to include(expected_results)
  end
end
