
require 'sinatra'
require 'dm-core'
require 'dm-migrations'


configure :development do
  DataMapper.setup(
    :default,
    "sqlite3://#{Dir.pwd}/login.db"
  )
  #set :port, 4040
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
end


def save
    @userData = Users.get(session[:username])
    @userData.total_win = session[:acc_win] + session[:curr_win]
    @userData.total_loss = session[:acc_loss] + session[:curr_loss]
    @userData.save
end

def try_login
    
    username = params[:username].nil? ? session[:temp_user] : params[:username]
    password = params[:password].nil? ? session[:temp_pass] : params[:password]
    session[:temp_user] = ""
    session[:temp_pass] = ""
    
    if !session[:username].nil?
        if !session[:username].empty?
            puts session[:username]
            session[:temp_user] = username
            session[:temp_pass] = password
            save
            logout
            try_login
        else
            login username, password
        end
    else
        login username, password
    end
    
    
    
end

def login(username, password)
    if username.empty? or password.empty?
        @header = "Please enter User ID and Password to logon."
        session[:logged] = false
        erb :login
    else
        @userData = Users.get(username)
        if @userData.nil?
            @header = "User not found. Please enter correct User ID and Password."
            session[:logged] = false
            erb :login
        elsif  @userData.password != password
            @header = "Incorrect Password. Please enter correct User ID and Password."
            session[:logged] = false
            erb :login
        else
            session[:logged] = true
            session[:name] = @userData.name
            session[:username] = username
            session[:password] = password
            @userData.total_win = 0 if @userData.total_win.nil?
            @userData.total_loss = 0 if @userData.total_loss.nil?
            session[:acc_win] = @userData.total_win
            session[:acc_loss] = @userData.total_loss
            session[:curr_win] = 0
            session[:curr_loss] = 0
            redirect to '/betting'
         end
    end
end

def logout
    session[:logged] = false
    session[:username] = ""
    session[:password] = ""
    session[:name] = ""
    session[:acc_win] = 0
    session[:acc_loss] = 0
    session[:curr_win] = 0
    session[:curr_loss] = 0
end

get ['/', '/home'], :layout=>:mylayout  do
    if session[:logged] == true
        redirect to '/betting'
    else
        @header = "Please Logon"
        erb :login
    end
    
end

post '/' do
    redirect to '/'
end

post '/login' do
    if session[:logged] == true
        redirect to '/betting'
    else
        try_login
    end
    
end

get '/login' do
    if session[:logged] == true
        redirect to '/betting'
    else
        redirect to '/'
    end
end

post '/confirm' do
    if session[:logged] == true
        if session[:curr_win] - session[:curr_loss] > 0
            @confirm = "Looks like you are winning, Champion."
        elsif session[:curr_win] - session[:curr_loss] < 0
            @confirm = "Don't Worry! You can make up the money you lost."
        else
            @confirm = "You are breaking even right now."
        end
        erb :confirm
    else
        redirect to '/'
    end
    
end

get '/betting' do
    if session[:logged] == true
        @vanish = ""
        if !session[:params].nil?
            if !session[:params].empty?
                params = session[:params]
                session.delete(:params)
            end
        end    
        if params.nil?

            @message = "If your number comes up on my die, I'll triple your money. Come on, try me! <br> Choose a number on the dice"
            @roll = "roll0"

        elsif params[:bet_money].empty? and params[:dice].empty?

            @message = "Ooooh! Want to win some money without putting any! Smart move!<br>Guess what? Someone is smarter than you!<br>"
            @roll = "roll0"
        
        else

            bet_money = params[:bet_money].to_i
            dice = params[:dice].to_i

            if bet_money <= 0

                @roll = "roll0"
                @message = "Don't be a miser! Put some real money! <br><br>"

            elsif dice <= 0 or dice >= 6

                @roll = "roll0"
                @message = "Did you really think that number would come up on a die? Seriously? <br><br>"

            else
                if params[:bet] == 0
                    params[:bet] = 1
                    @vanish = "opacity"
                    roll = rand(6) + 1
                    
                    case roll
                        when 1
                            @roll = "roll1"
                        when 2
                            @roll = "roll2"
                        when 3
                            @roll = "roll3"
                        when 4
                            @roll = "roll4"
                        when 5
                            @roll = "roll5"
                        when 6
                            @roll = "roll6"
                        else
                            @roll = "roll0"
                    end
                    
                    if dice == roll
                        session[:curr_win] += 3*bet_money
                        @message = "Woohoo! The dice landed on #{roll}, you win #{3*bet_money} chips! <br><br>"
                    else
                        session[:curr_loss] += bet_money
                        @message = "Uh oh! The dice landed on #{roll}, you lost #{bet_money} chips! <br><br>"
                    end
                else
                    @message = "If your number comes up on my die, I'll triple your money. Come on, try me! <br> Choose a number on the dice"
                    @roll = "roll0"
                end
            end
        
        end
        erb :visit
        
    else
        redirect to '/'
    end
end

post '/betting' do
    
end

post '/bet' do
    if session[:logged] == true
        params[:bet] = 0
        session[:params] = params
        redirect to '/betting'
    else
        redirect to '/'
    end
end

post '/save' do
    if session[:logged] == true
        save
        logout
        redirect to '/'
    else
        redirect to '/'
    end
end

post '/cancel' do
    if session[:logged] == true
        redirect to '/betting'
    else
        redirect to '/'
    end
end

post '/signup' do
    if session[:logged] == true
        redirect to '/betting'
    else
        @header = "Enter User Details"
        erb :signup
    end
end

post '/adduser' do
    if session[:logged] == true
        redirect to '/betting'
    else
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
                session[:temp_user] = username
                session[:temp_pass] = password
                try_login
            end
        end
        erb :signup
    end
    
end