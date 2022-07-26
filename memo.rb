# frozen_string_literal: true

require 'bundler/setup'
require 'sinatra'
require 'sinatra/reloader'
require 'haml'
require 'sassc'
require 'pathname'
require_relative 'lib/data_controller'

# sinatra config
configure do
  set :haml, format: :html5, escape_filter_interpolations: true

  enable :sessions
  # Rack::Overrideを使うとformでもPATCH, DELETEにルーティングできる
  enable :method_override
  set :show_exceptions, :after_handler
  set :memo_data, MemoData.new
end

helpers do
  def memo_ids
    settings.memo_data.ids
  end

  def memo_ids_with_title
    settings.memo_data.ids_with_title
  end

  def select_memo(id)
    settings.memo_data.find(id)
  end

  def create_memo(data)
    settings.memo_data.insert(data)
  end

  def delete_memo(id)
    settings.memo_data.delete(id)
  end

  def update_memo(id, data)
    settings.memo_data.update(id, data)
  end

  def memo_exist?(id)
    settings.memo_data.exist?(id)
  end

  def escaped(text)
    Rack::Utils.escape_html(text)
  end
end

# 共通のsass
get '/style.css' do
  sass :'sass/style'
end

# トップページ（メモ一覧を兼ねる）
get '/' do
  haml :index, locals: { titles: memo_ids_with_title, page_title: 'トップ' }
end

# 新規メモ保存
post '/memos' do
  response = create_memo({ title: params['title'], content: params['content'] })
  redirect to("/memos/#{response[:id]}")
end

# 新規メモ作成画面
get '/memos/new' do
  haml :edit, locals: { id: nil, page_title: 'メモ 新規作成' }
end

# 特定メモの存在確認フィルタ
before '/memos/:memo_id' do
  pass if params['memo_id'] == 'new'
  # memo_idのバリデーション
  pass if memo_exist?(params['memo_id'].to_i)
end

# 特定のメモ内容表示
get '/memos/:memo_id' do
  memo = select_memo(params['memo_id'].to_i)
  raise Sinatra::NotFound if memo.nil?

  haml :memo, locals: {
    id: escaped(params['memo_id']),
    title: escaped(memo[:title]),
    content: escaped(memo[:content]),
    page_title: escaped("メモ #{params['memo_id']}")
  }
end

# 編集画面
get '/memos/:memo_id/edit' do
  memo = select_memo(params['memo_id'].to_i)
  haml :edit, locals: {
    id: escaped(params['memo_id']),
    title: escaped(memo[:title]),
    content: escaped(memo[:content]),
    page_title: escaped("メモを編集 #{params['memo_id']}")
  }
end

# 特定のメモの内容編集
patch '/memos/:memo_id' do
  update_memo(
    params['memo_id'].to_i,
    { title: params[:title], content: params[:content] }
  )
  # PRG
  redirect to("/memos/#{params['memo_id']}")
end

delete '/memos/:memo_id' do
  delete_memo(params['memo_id'].to_i)
  redirect to('/')
end

# エラー画面
not_found do
  err_msg = 'ページが見つかりません'
  haml :error, locals: { error_msg: escaped(err_msg), page_title: 'page not found' }
end

error do
  err_msg = '何らかのエラーが発生しました。'
  haml :error, locals: { error_msg: escaped(err_msg), page_title: 'error' }
end
