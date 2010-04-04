# When we create our Rackup file, we'll already be requiring RubyGems and Sinatra, 
# use 'unless defined?' so we don't require the gems again if they've already been loaded.
require 'rubygems' unless defined? ::RubyGems
require 'sinatra' unless defined? ::Sinatra
require 'rack' # more on the decision to include this below
require 'dm-core'
require 'dm-timestamps'
require 'haml'
require 'sass'
require 'httparty'
require 'ruby-debug'

# If you want changes to your application to appear in development mode without having to 
# restart the application, you need something that will reload your app automatically. 
# There are solutions out there (like Shotgun) but these are very slow. It's far quicker 
# to use this method to reload your app. However, it's not foolproof: sometimes, things
# will get screwy. When that happens, just restart your application manually.
configure :development do
  Sinatra::Application.reset!
  use Rack::Reloader
  
  # the first time you run this, you'll need to create the database:
  #  cd db
  #  sqlite3 bottles.sqlite3
  #  (to exit from the sqlite3 command line, use: .exit)
  DataMapper.setup(:default, "sqlite3://#{Dir.pwd}/db/bottles.sqlite3")  
end

configure :production do
  # this will be dependent on your hosting setup
  require '/var/apps/bottles/shared/config/production.rb'
end

# This is such a simple application that we likely don't need a separate file for models and classes, 
# but it keeps things clean.  We'll also dump an addition to Ruby's Array class in here.
require 'classes'

# DataMapper's automatic upgrading is not without its issues, which is not that surprising
# given what it attempts to do. Don't rely on it to always do what you expect - use
# auto_migrate! to ensure your database schema is updated correct. HOWEVER, note that 
# auto_migrate! will destroy the data in your database, so you should never use it in a 
# production environment (this may be a surprise to Rails users).  I tend to use auto_migrate! 
# as I build the app and make major db changes, but once I have things pretty stable
# I switch to auto_upgrade!.
DataMapper.auto_upgrade!
#DataMapper.auto_migrate!

enable :sessions

get '/' do
  haml :index
end

get '/style.css' do
  response['Content-Type'] = 'text/css; charset=utf-8'
  sass :style
end

post '/sing' do
  screen_name = params[:screen_name]
  if screen_name && screen_name != ""
    @info = Twitter.get('/1/users/show.json', :query => { :screen_name => screen_name })
    if @info['error']
      redirect "/?failure=There was an error retrieving your account information. Twitter says: #{@info['error']}."
    else
      # Since we've now successfully retrieved information on a user account, we'll either look up or save this user in our
      # database.
      person = Person.first(:screen_name => screen_name)
      unless person
        person = Person.new(
          :screen_name => screen_name, 
          :name => @info['name'], 
          :joined_twitter_at => DateTime.parse(@info['created_at'])
        )
      end
      # These attributes can change over time
      person.followers_count, person.statuses_count, person.profile_image_url = @info['followers_count'], @info['statuses_count'], @info['profile_image_url']
      person.save
      
      redirect '/song/'
      
    end    
  else
    redirect "/?failure=Please enter a Twitter username to start the valuation process."
  end
end

not_found do
  haml :'404'
end

helpers do  
  def twitter_link(person)
    "<a href='http://twitter.com/#{person.screen_name}' target='_'>#{person.name}</a>"
  end
end