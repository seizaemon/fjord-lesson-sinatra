# frozen_string_literal: true

# モジュールの読み込み時に環境変数が解決されるからこの位置に書く
ENV['MEMO_APP_STORE'] = "#{__dir__}/test_app_data"
require_relative '../memo'
require 'minitest/autorun'
require 'rack/test'
require 'tmpdir'

class MemoCommonTest < Minitest::Test
  include Rack::Test::Methods

  # Rack::Testで使用するdefaultのホスト
  BASE_URL = 'http://example.org'

  def common_test
    assert_equal last_response.headers['Content-Type'], 'text/html;charset=utf-8'
    assert_equal last_response.headers['X-XSS-Protection'], '1; mode=block'
  end
end

class MemoAppCreateTest < MemoCommonTest
  def setup
    @data_file_path = "#{__dir__}/test_app_data"
    inputs = [
      { id: 1, title: 'メモ1', content: 'このメモはテスト1の内容です。' }
    ]
    data = PStore.new(@data_file_path)
    data.transaction do
      inputs.each do |input|
        data[input[:id]] = { title: input[:title], content: input[:content] }
      end
      data.commit
    end
  end

  def app
    Sinatra::Application
  end

  def test_root
    get '/'
    common_test
    assert last_response.ok?
  end

  def test_create_and_get
    post(
      '/memos',
      { title: 'test2', content: 'test_content' },
      'CONTENT_TYPE' => 'application/x-www-form-urlencoded'
    )
    common_test
    assert_equal last_response.status, 302
    assert_equal last_response.location, "#{BASE_URL}/memos/2"

    get '/memos/2'
    assert last_response.ok?
  end

  def test_get_notfound
    get '/unknown_place'
    common_test
    assert last_response.not_found?
  end

  def teardown
    File.delete("#{__dir__}/test_app_data")
  end
end

class MemoAppUpdateDeleteTest < MemoCommonTest
  def setup
    @data_file_path = "#{__dir__}/test_app_data"
    inputs = [
      { id: 1, title: 'メモ1', content: 'このメモはテスト1の内容です。' },
      { id: 2, title: 'メモ2', content: 'このメモはテスト2の内容です。' }
    ]
    data = PStore.new(@data_file_path)
    data.transaction do
      inputs.each do |input|
        data[input[:id]] = { title: input[:title], content: input[:content] }
      end
      data.commit
    end
  end

  def app
    Sinatra::Application
  end

  def test_update_and_get
    patch(
      '/memos/1',
      { title: 'test1', content: 'test_content_modified' },
      'CONTENT_TYPE' => 'application/x-www-form-urlencoded'
    )
    common_test
    # 302で更新したメモの内容にリダイレクト
    assert_equal last_response.status, 302
    assert_equal last_response.location, "#{BASE_URL}/memos/1"
  end

  def test_delete_and_notfound
    delete '/memos/2'
    # 302でルートにリダイレクト
    common_test
    assert_equal last_response.status, 302
    assert_equal last_response.location, "#{BASE_URL}/"

    get '/memos/2'
    assert last_response.status, 404
  end

  def teardown
    File.delete("#{__dir__}/test_app_data")
  end
end
