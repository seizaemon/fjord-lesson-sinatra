# frozen_string_literal: true

ENV['MEMO_APP_STORE'] = "#{__dir__}/test_memo_data"
require 'minitest/autorun'
require 'pstore'
require_relative '../lib/data_controller'

class MemoStoreSimpleTest < Minitest::Test
  def setup
    @data_file_path = "#{__dir__}/test_memo_data"
    inputs = [
      { id: 1, title: 'メモ1', content: 'このメモはテスト1の内容です。' },
      { id: 3, title: 'メモ3', content: 'このメモはテスト3の内容です。' }
    ]
    data = PStore.new(@data_file_path)
    data.transaction do
      inputs.each do |input|
        data[input[:id]] = { title: input[:title], content: input[:content] }
      end
      data.commit
    end

    @memo_data = MemoData.new
  end

  def test_read_specific_memo
    expected = { title: 'メモ3', content: 'このメモはテスト3の内容です。' }
    assert_equal expected, @memo_data.find(3)
  end

  def test_insert_specific_memo
    expected = { id: 4, title: 'メモ4', content: 'このメモはテスト4の内容です。' }
    assert_equal expected, @memo_data.insert(expected)
    assert_equal expected, @memo_data.find(4)
  end

  def test_delete_specific_memo
    insert_data = { title: 'メモ4', content: 'このメモはテスト4の内容です。' }
    @memo_data.insert(insert_data)
    @memo_data.delete(4)
    assert_nil @memo_data.find(4)
  end

  def test_update_specific_memo
    expected = { title: 'メモ1', content: 'このメモは更新されました。' }
    @memo_data.update(1, expected)
    assert_equal expected, @memo_data.find(1)
  end

  def test_data_is_exist?
    assert_equal true, @memo_data.exist?(1)
    assert_equal false, @memo_data.exist?(100)
  end

  def test_next_id
    assert_equal 4, @memo_data.next_id
  end

  def test_memo_ids
    assert_equal [1, 3], @memo_data.ids
  end

  def test_memo_ids_with_title
    expected = [
      { id: 1, title: 'メモ1' },
      { id: 3, title: 'メモ3' }
    ]
    assert_equal expected, @memo_data.ids_with_title
  end

  def teardown
    File.delete(@data_file_path) if File.exist?(@data_file_path)
  end
end

class MemoStoreValidationTest < Minitest::Test
  def setup
    @data_file_path = "#{__dir__}/test_memo_data"
    ENV['MEMO_APP_STORE'] = @data_file_path
    inputs = [
      { id: 1, title: 'メモ1', content: 'このメモはテスト1の内容です。' },
      { id: 3, title: 'メモ3', content: 'このメモはテスト3の内容です。' }
    ]
    db = PStore.new(@data_file_path)
    db.transaction do
      inputs.each do |input|
        db[input[:id]] = { title: input[:title], content: input[:content] }
      end
      db.commit
    end

    @memo_data = MemoData.new
  end

  def test_insert_in_updating
    update_data = { title: 'メモ2', content: 'このデータは書き込まれません' }
    assert_nil @memo_data.update(2, update_data)
  end

  def teardown
    File.delete(@data_file_path)
  end
end
