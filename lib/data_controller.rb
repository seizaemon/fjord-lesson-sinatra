# frozen_string_literal: true

require 'pg'
require 'logger'

class MemoData
  attr_reader :conn, :logger

  def initialize(config)
    @conn = PG.connect(**config)
    @conn.prepare('select_memo', 'SELECT id, title, content FROM memos WHERE id = $1 ;')
    @conn.prepare('insert', 'INSERT INTO memos (title, content) VALUES ($1, $2) ;')
    @conn.prepare('delete', 'DELETE FROM memos WHERE id = $1 ;')
    @conn.prepare('update', 'UPDATE memos SET title = $1, content = $2 WHERE id = $3 ;')

    @logger = Logger.new($stderr)
  end

  def find(id)
    res = @conn.exec_prepared('select_memo', [id])
    if res.cmd_tuples.zero?
      @logger.info("memo_id: #{id} is not found.")
      nil
    else
      @logger.info("memo_id: #{id} is found.")
      { id: res[0]['id'], title: res[0]['title'], content: res[0]['content'] }
    end
  end

  def insert(memo_data)
    content_stmt = 'SELECT id, title, content FROM memos WHERE id = LASTVAL();'
    begin
      @conn.transaction do |conn|
        conn.exec_prepared('insert', [memo_data[:title], memo_data[:content]])
        # LASTVALから値をとるため、トランザクション内で実施
        res_inserted = conn.exec(content_stmt)
        result = { id: res_inserted[0]['id'], title: res_inserted[0]['title'], content: res_inserted[0]['content'] }
        @logger.info("Data inserted: #{result}")
        result
      end
    rescue PG::Error => e
      @logger.error("#{e.class}: #{e.message}")
      nil
    end
  end

  def delete(id)
    @conn.transaction do |conn|
      conn.exec_prepared('delete', [id])
    end
    @logger.info("memo_id: #{id} is deleted.")
    id
  end

  def update(id, memo_data)
    return nil if find(id).nil?

    begin
      @conn.transaction do |conn|
        conn.exec_prepared('update', [memo_data[:title], memo_data[:content], id])
      end
      result = find(id)
      @logger.info("Data updated: #{result}")
      result
    rescue PG::Error => e
      @logger.error("#{e.class}: #{e.message}")
      nil
    end
  end

  def exist?(id)
    !find(id).nil?
  end

  def ids
    find_stmt = 'SELECT id FROM memos ORDER BY id ;'
    res = @conn.exec(find_stmt)
    res.map { |row| row['id'] }
  end

  def ids_with_title
    find_stmt = 'SELECT id, title FROM memos ORDER BY id;'
    res = @conn.exec(find_stmt)
    res.map { |row| { id: row['id'], title: row['title'] } }
  end
end
