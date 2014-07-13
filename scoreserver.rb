#!/usr/bin/ruby
require 'rubygems'
require 'sinatra'
require 'securerandom'

SCORESERVER_VERSION = "0.0.2"

begin
  require './config.rb'
rescue Exception => e
  # create default config.rb
  open('./config.rb', "w+") {|f|
    f.puts <<-"EOS"
COOKIE_SECRET   = "#{SecureRandom.hex(20)}"
ADMIN_PASS_SHA1 = "08a567fa1a826eeb981c6762a40576f14d724849" #ctfadmin
STYLE_SHEET = "/style.css"
HTML_TITLE = "scoreserver.rb CTF"
    EOS
    f.flush
  }
  require './config.rb'
end

require './tables.rb'
require './signup.rb'
require './login.rb'
require './ranking.rb'
require './announcements.rb'
require './admin.rb'

require 'pp'


use Rack::Session::Cookie,
  :expire_after => 3600,
  :secret => COOKIE_SECRET 

helpers do
  include Rack::Utils
  alias_method :h, :escape_html

  def footer_contents
    return <<-"EOS"
      <div id="footer_item">Generated by <a href="http://github.com/yoggy/ctf-scoreserver">scoreserver.rb</a> (#{SCORESERVER_VERSION})</div>
      <div id="footer_item">Powerd by <a href="http://www.ruby-lang.org/">Ruby</a> and <a href="http://www.sinatrarb.com/">Sinatra</a></div>
      <div id="footer_item">Designed and Developed by yoggy :: team t-dori</div>
    EOS
  end
end


#
# scoreserver main methods
#
helpers do
  def get_score
    u = User.find(get_uid)
    as = u.answers
    return 0 if as.nil?

    total = 0
    as.each{|a|
      total += a.challenge.point if a.challenge
    }
    total
  end

  def get_clear_status(cid)
    uid = session['uid']

    a = Answer.find_by_user_id_and_challenge_id(uid, cid)

    not a.nil?
  end
end

get '/answer' do 
  redirect '/challenge'
end

get '/answer/*' do 
  redirect '/challenge'
end

post '/answer/:cid' do |cid|
  login_block do
    c = Challenge.find(cid)

    if c == nil || c.status != "show" || params['answer'].nil?
      redirect '/challenge'
    else
      pp cid
      pp c
      @cid = cid
      if params['answer'].downcase == c.answer.chomp.downcase
        if Answer.find_by_challenge_id_and_user_id(cid, get_uid).nil?
          a = Answer.new
          a.challenge_id = cid
          a.user_id      = get_uid
          a.save
        end

        erb :answer_correct, :layout => false
      else 
        erb :answer_wrong, :layout => false
      end
    end
  end
end

get '/challenge/:cid' do |cid|
  login_block do
    c = Challenge.find_by_id(cid)

    if c == nil || c.status != "show"
      redirect "/challenge"
    else
      @id       = c.id
      @point    = c.point
      @abstract = c.abstract
      @clear_status   = get_clear_status(c.id) ? "clear" : ""
      @detail   = c.detail

      erb :challenge_detail
    end
  end
end

get '/challenge' do
  login_block do
    cs = Challenge.find(:all, :order => 'id')

    @challenges = []
    if cs
      cs.each do |c|
        next if c.status == "hide"

        v = {}
        v['id']           = c.id
        v['point']        = c.point
        v['clear_status'] = get_clear_status(c.id) ? "clear" : ""
        
        if c.status == "pending"
          v['abstract'] = "........"
        else
          v['abstract'] = "<a href=\"challenge/#{c.id}\">#{h(c.abstract)}</a>"
        end


        @challenges << v
      end
    end
    
    erb :challenge_main
  end
end

#
# index
#
get '/?' do
  session_clear

  limit = 5
  @announcements = Announcement.where("show = 1").order("id desc").order("time desc").limit(limit)

  erb :index
end

