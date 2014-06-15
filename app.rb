##
# Copyright 2012 Evernote Corporation. All rights reserved.
##

require 'sinatra'
require 'sinatra/activerecord'
enable :sessions

##
# databases
##
set :database, "sqlite3:ZAlarm.db"

class Alarm < ActiveRecord::Base
end

# Load our dependencies and configuration settings
$LOAD_PATH.push(File.expand_path(File.dirname(__FILE__)))
require "evernote_config.rb"

##
# Verify that you have obtained an Evernote API key
##
before do
  if OAUTH_CONSUMER_KEY.empty? || OAUTH_CONSUMER_SECRET.empty?
    halt '<span style="color:red">Before using this sample code you must edit evernote_config.rb and replace OAUTH_CONSUMER_KEY and OAUTH_CONSUMER_SECRET with the values that you received from Evernote. If you do not have an API key, you can request one from <a href="http://dev.evernote.com/documentation/cloud/">dev.evernote.com/documentation/cloud/</a>.</span>'
  end
end

helpers do
  def auth_token
    session[:access_token].token if session[:access_token]
  end

  def client
    @client ||= EvernoteOAuth::Client.new(token: auth_token, consumer_key:OAUTH_CONSUMER_KEY, consumer_secret:OAUTH_CONSUMER_SECRET, sandbox: SANDBOX)
  end

  def user_store
    @user_store ||= client.user_store
  end

  def note_store
    @note_store ||= client.note_store
  end

  def en_user
    user_store.getUser(auth_token)
  end

  def notebooks
    @notebooks ||= note_store.listNotebooks(auth_token)
  end

  def total_note_count
    filter = Evernote::EDAM::NoteStore::NoteFilter.new
    counts = note_store.findNoteCounts(auth_token, filter, false)
    notebooks.inject(0) do |total_count, notebook|
      total_count + (counts.notebookCounts[notebook.guid] || 0)
    end
  end

  def make_note(note_store, note_title, note_body, timestamp, parent_notebook=nil)

    n_body = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
    n_body += "<!DOCTYPE en-note SYSTEM \"http://xml.evernote.com/pub/enml2.dtd\">"
    n_body += "<en-note>#{note_body}</en-note>"

    ## Create note object
    our_note = Evernote::EDAM::Type::Note.new
    our_note.title = note_title
    our_note.content = n_body

    ## with reminder
    our_note.attributes = Evernote::EDAM::Type::NoteAttributes.new
    our_note.attributes.reminderTime = timestamp * 1000

    ## parent_notebook is optional; if omitted, default notebook is used
    if parent_notebook && parent_notebook.guid
      our_note.notebookGuid = parent_notebook.guid
    end

    ## Attempt to create note in Evernote account
    begin
      note = note_store.createNote(our_note)
    rescue Evernote::EDAM::Error::EDAMUserException => edue
      ## Something was wrong with the note data
      ## See EDAMErrorCode enumeration for error code explanation
      ## http://dev.evernote.com/documentation/reference/Errors.html#Enum_EDAMErrorCode
      puts "EDAMUserException: #{edue}"
    rescue Evernote::EDAM::Error::EDAMNotFoundException => ednfe
      ## Parent Notebook GUID doesn't correspond to an actual notebook
      puts "EDAMNotFoundException: Invalid parent notebook GUID"
    end

    ## Return created note object
    note

  end
end

##
# Index page
##
get '/' do
  erb :index
end

##
# Reset the session
##
get '/reset' do
  session.clear
  redirect '/'
end

##
# Obtain temporary credentials
##
get '/requesttoken' do
  callback_url = request.url.chomp("requesttoken").concat("callback")
  begin
    session[:request_token] = client.request_token(:oauth_callback => callback_url)
    redirect '/authorize'
  rescue => e
    @last_error = "Error obtaining temporary credentials: #{e.message}"
    erb :error
  end
end

##
# Redirect the user to Evernote for authoriation
##
get '/authorize' do
  if session[:request_token]
    redirect session[:request_token].authorize_url
  else
    # You shouldn't be invoking this if you don't have a request token
    @last_error = "Request token not set."
    erb :error
  end
end

##
# Receive callback from the Evernote authorization page
##
get '/callback' do
  unless params['oauth_verifier'] || session['request_token']
    @last_error = "Content owner did not authorize the temporary credentials"
    halt erb :error
  end
  session[:oauth_verifier] = params['oauth_verifier']
  begin
    session[:access_token] = session[:request_token].get_access_token(:oauth_verifier => session[:oauth_verifier])
    redirect '/list'
  rescue => e
    @last_error = 'Error extracting access token'
    erb :error
  end
end


##
# Access the user's Evernote account and display account data
##
get '/list' do
  begin
    # Get notebooks
    session[:notebooks] = notebooks.map(&:name)
    # Get username
    session[:username] = en_user.username
    # Get total note count
    session[:total_notes] = total_note_count
    erb :index
  rescue => e
    @last_error = "Error listing notebooks: #{e.message}"
    erb :error
  end
end

##
# Create new note
##
get '/createnote' do
  timestamp = Time.now.to_i
  if params[:timestamp] != nil
    timestamp = params[:timestamp].to_i
  end
  make_note(note_store, "test", "hello, world!",timestamp)
  erb :index
end

##
# show alarms
##
get '/alarms' do
  @alarms = Alarm.order('created_at DESC')
  erb :alarms
end

get '/alarms/new' do
  @title = 'New Alarm'
  @alarm = Alarm.new
  erb :alarms_new
end

post '/alarms' do
  @alarm = Alarm.new(params[:alarm])
  if @alarm.save
    redirect "/alarms/#{@alarm.id}"
  else
    erb :alarms_new
  end
end

get '/alarms/:id' do
  @alarm = Alarm.find(params[:id])
  @title = @alarm.title
  erb :alarms_show
end

get '/alarms/:id/edit' do
  @alarm = Alarm.find(params[:id])
  erb :alarms_edit
end

put '/alarms/:id' do
  @alarm = Alarm.find(params[:id])
  if @alarm.update_attributes(params[:alarm])
    redirect "/alarms/#{@alarm.id}"
  else
    erb :alarms_edit
  end
end

__END__

@@ index
<html>
<head>
  <title>Evernote Ruby Example App</title>
</head>
<body>
  <a href="/requesttoken">Click here</a> to authenticate this application using OAuth.
  <% if session[:notebooks] %>
  <hr />
  <h3>The current user is <%= session[:username] %> and there are <%= session[:total_notes] %> notes in their account</h3>
  <br />
  <h3>Here are the notebooks in this account:</h3>
  <ul>
    <% session[:notebooks].each do |notebook| %>
    <li><%= notebook %></li>
    <% end %>
  </ul>
  <% end %>
</body>
</html>

@@ error
<html>
<head>
  <title>Evernote Ruby Example App &mdash; Error</title>
</head>
<body>
  <p>An error occurred: <%= @last_error %></p>
  <p>Please <a href="/reset">start over</a>.</p>
</body>
</html>

@@ alarms
<html>
<head>
  <title>Your alarms</title>
</head>
<body>
  <ul>
<% @alarms.each do |alarm| %>
  <li>
    <h2><%= alarm.title %></h2>
    <li><%= alarm.created_at %></li>
  </li>
<% end %>
</ul>
</body>
</html>

@@ alarms_new
<html>
<head>
  <title>New Alarm</title>
</head>
<body>
  <h1>New Alarm</h1>
  <form action="/alarms" method="post">
    <label for="alarm_title">Title:</label><br />
    <input id="alarm_title" name="alarm[title]" type="text" value="<%= @alarm.title %>" />
    <br />

    <label for="alarm_alarm_time">Alarm Time:</label><br />
    <input id="alarm_alarm_time" name="alarm[alarm_time]" type="datetime" />
    <br />

    <input type="submit" value="Create Alarm" />
  </form>
</body>
</html>

@@ alarms_edit
<html>
<head>
  <title>Edit Alarm</title>
</head>
<body>
  <h1>Edit Alarm</h1>
  <form action="/alarms/<%= @alarm.id%>" method="post">
    <input type="hidden" name="_method" value="put" />

    <label for="alarm_title">Title:</label><br />
    <input id="alarm_title" name="alarm[title]" type="text" value="<%= @alarm.title %>" />
    <br />

    <label for="alarm_alarm_time">Alarm Time:</label><br />
    <input id="alarm_alarm_time" name="alarm[alarm_time]" type="datetime"  value="<%= @alarm.alarm_time %>"/>
    <br />

    <input type="submit" value="Edit Alarm" />
  </form>
</body>
</html>

@@ alarms_show
<html>
<head>
  <title>Show Alarm</title>
</head>
<body>
  <h2><%= @alarm.title %> <%= @alarm.alarm_time %></h2>
</body>
</html>
