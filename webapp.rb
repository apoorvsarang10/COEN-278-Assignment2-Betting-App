
require 'sinatra'
require 'dm-core'
require 'dm-migrations'


configure :development do
  DataMapper.setup(
    :default,
    "sqlite3://#{Dir.pwd}/login.db"
  )
end

configure :production do
  DataMapper.setup(
    :default,
    ENV['DATABASE_URL']
  )
end

class Users
  
    include DataMapper::Resource
    property :user_id, String, key: true
    property :password, String
    property :name, String
    property :total_win, Integer
    property :total_loss, Integer
    
end

# if not db not exist, create it 
Users.auto_migrate! unless DataMapper.repository(:default).adapter.storage_exists?('users')

configure do
  enable :sessions
  set :username, ""
  set :password, ""
  set :name, ""
  set :acc_win, 0
  set :acc_loss, 0
  set :curr_win, 0
  set :curr_loss, 0
end

$temp_user = ""
$temp_pass = ""

def save
    @userData = Users.get(settings.username)
    @userData.total_win = settings.acc_win + settings.curr_win
    @userData.total_loss = settings.acc_loss + settings.curr_loss
    @userData.save
end

def try_login
    
    @failed = 0
    username = params[:username].nil? ? $temp_user : params[:username]
    password = params[:password].nil? ? $temp_pass : params[:password]
    $temp_user = ""
    $temp_pass = ""
    if !settings.username.empty?
        $temp_user = username
        $temp_pass = password
        save
        logout
        try_login
    else
        if username.empty? or password.empty?
            @header = "Please enter User ID and Password to logon."
            session[:logged] = false
            erb :login
        else
            @userData = Users.get(username)
            if @userData.nil? or @userData.password != password
                @header = "User not found. Please enter correct User ID and Password."
                session[:logged] = false
                erb :login
            else
                session[:logged] = true
                settings.username = username
                settings.password = password
                settings.name = @userData.name
                @userData.total_win = 0 if @userData.total_win.nil?
                @userData.total_loss = 0 if @userData.total_loss.nil?
                settings.acc_win = @userData.total_win
                settings.acc_loss = @userData.total_loss
                redirect to '/betting'
            end
        end
    end
    
end

def logout
    session[:logged] = false
    settings.username = ""
    settings.password = ""
    settings.name = ""
    settings.acc_win = 0
    settings.acc_loss = 0
    settings.curr_win = 0
    settings.curr_loss = 0
end

get ['/', '/home'], :layout=>:mylayout  do
    @header = "Please Logon"
    erb :login
end

get '/login' do
    try_login
end

post '/confirm' do
    if settings.curr_win - settings.curr_loss > 0
        @confirm = "Looks like you are winning, Champion."
    elsif settings.curr_win - settings.curr_loss < 0
        @confirm = "Don't Worry! You can make up the money you lost."
    else
        @confirm = "You are breaking even right now."
    end
    erb :confirm
end

get '/betting' do
    if session[:logged] == true
        @message = "If your number comes up on my die, I'll triple your money. \n Come on, try me!"
        erb :visit
    else
        redirect to '/'
    end
end

post '/bet' do
    bet_money = params[:bet_money].to_i
    dice = params[:dice].to_i
    puts bet_money
    if bet_money <= 0
        
        @message = "Don't be a miser! Put some real money!"
    
    elsif dice <= 0 or dice > 6
    
        @message = "Did you really think that number would come up on a die? Seriously?"
    
    else
        roll = rand(6) + 1
        if dice == roll
            settings.curr_win += 3*bet_money
            @message = "Woohoo! The dice landed on #{roll}, you win #{3*bet_money} chips!"
        else
            settings.curr_loss += bet_money
            @message = "Uh oh! The dice landed on #{roll}, you lost #{bet_money} chips!"
        end
    
    
    end
    erb :visit
    
end

post '/save' do
    save
    logout
    redirect to '/'
end

post '/cancel' do
    redirect to '/betting'
end

get '/signup' do
    @header = "Enter User Details"
    erb :signup
end

get '/adduser' do

    username = params[:username]
    password = params[:password]
    fullname = params[:fullname]
    if username.empty?
        @header = "Username can not be empty!"
        erb :signup
    elsif password.empty?
        @header = "Password can not be empty!"
        erb :signup
    elsif fullname.empty?
        @header = "Name can not be empty!"
        erb :signup
    else
        @userData = Users.get(username)
        if !@userData.nil?
            @header = "Username already exists!"
            erb :signup
        else
            @user = Users.new
            @user.user_id = username
            @user.password = password
            @user.name = fullname
            @user.total_win = 0
            @user.total_loss = 0
            @user.save
            $temp_user = username
            $temp_pass = password
            try_login
        end
    end
    erb :signup
end