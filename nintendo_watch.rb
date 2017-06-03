#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

# My Nintendo Switch の入荷を監視するスクリプト

require 'nokogiri'
require 'capybara'
require 'capybara/poltergeist'
require 'uri'
require "mail"
require "yaml"

CONFIG_FILE = 'config.yaml'
WATCH_URL = 'https://store.nintendo.co.jp/customize.html'
MAIL_SUBJECT = 'NINTENDO SWITCH 入荷情報'
MAIL_BODY = '入荷！'


def init(user, pass)
  ENV['QT_QPA_PLATFORM'] = 'offscreen'
  ENV['QT_QPA_FONTDIR'] = '/usr/share/fonts/truetype'

  Capybara.default_selector = :xpath
  Capybara.register_driver :poltergeist do |app|
    Capybara::Poltergeist::Driver.new(
      app,
      { :js_errors => false,
        :cookies => true,
        :window_size => [1280, 1024],
        :timeout => 10, # sec
        :phantomjs_options => [
          '--ignore-ssl-errors=true',
          '--ssl-protocol=any',
          '--web-security=false',
        ]
      }
    )
  end

  Mail.defaults do
    delivery_method(
      :smtp,
      {
        :address              => 'smtp.gmail.com',
        :port                 => 587,
        :user_name            => user,
        :password             => pass,
        :authentication       => :login,
        :enable_starttls_auto => true
      }
    )
  end
end

def send_mail(from, to, message)
  mail = Mail.new(:charset => 'UTF-8') do
    from(from)
    to(to)
    subject(MAIL_SUBJECT)
    body(message)
  end

  mail.content_transfer_encoding = '8bit'
  mail.deliver
end

def check_sodout(session)
  begin
    session.visit(WATCH_URL)
    doc = Nokogiri::HTML.parse(session.html)
    target_node = doc.search("//p[text()='Nintendo Switch™']/..")
    if (target_node.search("//p[text()='SOLD OUTa']").length == 0) then
      return true
    end
  rescue
    #
  end

  return false
end

config = YAML.load_file(CONFIG_FILE)

init(config['user'], config['pass'])

session = Capybara::Session.new(:poltergeist)

loop do
  is_available = check_sodout(session)

  if (is_available) then
    send_mail(config['user'], config['address'], MAIL_BODY)
  end
  sleep(60)
end
