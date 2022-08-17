# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/memo'

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

    @memo_data = MemoData.new(config)
  end

  def teardown
    drop_stmt = 'TRUNCATE TABLE memos RESTART IDENTITY;'
    @conn.exec(drop_stmt)
  end
end

class MemoStoreSimpleGetTest < Minitest::Test
  include MemoTestConfig

  def test_read_specific_memo
    expected = { id: '2', title: 'メモ2', content: 'このメモはテスト2の内容です。' }
    assert_equal expected, @memo_data.find(2)
  end

  def test_data_is_exist?
    assert_equal true, @memo_data.exist?(1)
    assert_equal false, @memo_data.exist?(100)
  end

  def test_memo_ids
    assert_equal %w[1 2], @memo_data.ids
  end

  def test_memo_ids_with_title
    expected = [
      { id: '1', title: 'メモ1' },
      { id: '2', title: 'メモ2' }
    ]
    assert_equal expected, @memo_data.ids_with_title
  end
end

class MemoStoreManipulateTest < Minitest::Test
  include MemoTestConfig
  def test_insert_specific_memo
    insert_data = { title: 'メモ3', content: 'このメモはテスト3の内容です。' }
    expected = { id: '3', title: 'メモ3', content: 'このメモはテスト3の内容です。' }
    assert_equal expected, @memo_data.insert(insert_data)
    assert_equal expected, @memo_data.find(3)
  end

  def test_update_specific_memo
    expected = { id: '1', title: 'メモ1', content: 'このメモは更新されました。' }
    @memo_data.update(1, expected)
    assert_equal expected, @memo_data.find(1)
  end

  def test_delete_specific_memo
    assert_equal 2, @memo_data.delete(2)
  end
end

class MemoStoreValidationGetTest < Minitest::Test
  include MemoTestConfig
  def test_not_exist_id
    assert_nil @memo_data.find(5)
  end
end

class MemoValidateManipulateTest < Minitest::Test
  include MemoTestConfig
  def test_insert_in_updating
    update_data = { title: 'メモ3', content: 'このデータは書き込まれません' }
    assert_nil @memo_data.update(3, update_data)
  end

  def test_null_title_in_inserting
    insert_data = { title: nil, content: 'このinsertは失敗します' }
    assert_nil @memo_data.insert(insert_data)
  end

  def test_null_title_in_updating
    update_data = { title: nil, content: 'このupdateは失敗します' }
    assert_nil @memo_data.update(1, update_data)
  end

  def test_delete_not_exist_memo
    # べき等性
    assert_equal 100, @memo_data.delete(100)
  end

  def test_data_overflow
    # タイトルは100文字まで
    test_title = []
    101.times { |i| test_title[i] = 'a' }
    insert_data = { title: test_title.join(''), content: 'このinsertは失敗します' }
    assert_nil @memo_data.insert(insert_data)
  end
end
