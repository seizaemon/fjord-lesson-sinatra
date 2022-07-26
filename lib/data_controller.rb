# frozen_string_literal: true

require 'pstore'

class MemoData
  def initialize
    data_file_path = ENV['MEMO_APP_STORE'] || "#{__dir__}/../data/memo_data"
    @store = PStore.new(data_file_path)
    @store.ultra_safe = true
  end

  def find(id)
    @store.transaction(read_only: true) do
      @store.fetch(id, nil)
    end
  end

  def insert(memo_data)
    insert_id = next_id
    # 重複防止
    return nil if exist?(insert_id)

    @store.transaction do
      @store[insert_id] = memo_data
      @store.commit
    end
    { id: insert_id, title: memo_data[:title], content: memo_data[:content] }
  end

  def delete(id)
    @store.transaction do
      @store.delete(id)
      @store.commit
    end
  end

  def update(id, memo_data)
    # データのバリデーション（idチェック）
    return nil unless exist?(id)

    data = { title: memo_data[:title], content: memo_data[:content] }
    @store.transaction do
      @store[id] = data
      @store.commit
    end
    data
  end

  def exist?(id)
    @store.transaction(read_only: true) do
      @store.fetch(id, false) ? true : false
    end
  end

  def next_id
    @store.transaction(read_only: true) do
      @store.roots.max ? @store.roots.max + 1 : 1
    end
  end

  def ids
    @store.transaction(read_only: true) do
      @store.roots.sort
    end
  end

  def ids_with_title
    result = []
    @store.transaction(read_only: true) do
      @store.roots.sort.each { |id| result.push({ id:, title: @store[id][:title] }) }
    end
    result
  end
end
