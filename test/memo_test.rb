# frozen_string_literal: true

# モジュールの読み込み時に環境変数が解決されるからこの位置に書く
require_relative '../memoApp'
require 'minitest/autorun'
require 'rack/test'

class MemoCommonTest < Minitest::Test
  include Rack::Test::Methods

  # Rack::Testで使用するdefaultのホスト
  BASE_URL = 'http://example.org'

  def common_test
    assert_equal last_response.headers['Content-Type'], 'text/html;charset=utf-8'
    assert_equal last_response.headers['X-XSS-Protection'], '1; mode=block'
  end
end

module MemoTestConfig
  def setup
    config = {
      host: 'database', dbname: 'memo_db',
      user: 'postgres', password: 'fjord',
      port: 5432
    }
    inputs = [
      { title: 'メモ1', content: 'このメモはテスト1の内容です。' },
      { title: 'メモ2', content: 'このメモはテスト2の内容です。' }
    ]
    drop_stmt = 'TRUNCATE TABLE memos RESTART IDENTITY;'
    insert_stmt = 'INSERT INTO memos (title, content) VALUES ($1, $2);'

    @conn = PG.connect(**config)
    @conn.exec(drop_stmt)

    @conn.prepare('insert', insert_stmt)
    @conn.transaction do |c|
      inputs.each do |input|
        c.exec_prepared('insert', [input[:title], input[:content]])
      end
    end

    @memo_data = Memo.new(config)
  end

  def teardown
    drop_stmt = 'TRUNCATE TABLE memos RESTART IDENTITY;'
    @conn.exec(drop_stmt)
  end
end

class MemoAppCreateTest < MemoCommonTest
  include MemoTestConfig

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
      { title: 'test3', content: 'test_content' },
      'CONTENT_TYPE' => 'application/x-www-form-urlencoded'
    )
    common_test
    assert_equal last_response.status, 302
    assert_equal last_response.location, "#{BASE_URL}/memos/3"

    get '/memos/3'
    assert last_response.ok?
  end

  def test_get_notfound
    get '/unknown_place'
    common_test
    assert last_response.not_found?
  end
end

class MemoAppUpdateDeleteTest < MemoCommonTest
  include MemoTestConfig

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
end

class MemoAppXSSTest < MemoCommonTest
  include MemoTestConfig

  def app
    Sinatra::Application
  end

  def test_xss_post
    post(
      '/memos',
      { title: '<b>テスト</b>', content: "<script>alert('XSS')</script>" },
      'CONTENT_TYPE' => 'application/x-www-form-urlencoded'
    )
    assert_match last_response.body, '&lt;b&gt;テスト&lt;/b&gt;'
    assert_match last_response.body, '&lt;script&gt;alert(&#039;XSS&#039;)&lt;/script&gt;'
  end

  def test_xss_patch
    patch(
      '/memos/1',
      { title: '<b>テスト</b>', content: "<script>alert('XSS')</script>" },
      'CONTENT_TYPE' => 'application/x-www-form-urlencoded'
    )
    assert_match last_response.body, '&lt;b&gt;テスト&lt;/b&gt;'
    assert_match last_response.body, '&lt;script&gt;alert(&#039;XSS&#039;)&lt;/script&gt;'
  end
end
