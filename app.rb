require "sinatra"
require 'sinatra/reloader' if development?
require 'twilio-ruby'
require 'httparty'
require 'json'
require 'giphy'
require 'faraday'
require 'open_weather'
require 'linkedin'

enable :sessions

configure :development do
	require 'dotenv'
	Dotenv.load
	require 'did_you_mean'
	require 'better_errors'
	use BetterErrors::Middleware
	BetterErrors.application_root = __dir__
end

# global variables
greetings = ["Hello!", "Hi!", "Hey!", "What's up!", "Good to see you!", "Hey there!"]
$funny_response = ["funny right?", "Glad it makes you laugh!", "It's my pleasure to bring you joy!", "You can ask for 'joke' again and I'll tell you another one.", "I'm funny and attractive, right?"]
code = "meruinyou"

# / page and about page are the same
get "/" do
	redirect "/about"
end

# /about page
get '/about' do
	# visiting times
	session["visits"] ||= 0 # Set the session to 0 if it hasn't been set before
  session["visits"] = session["visits"] + 1  # adds one to the current value (increments)
	visit_num = "You have visited #{session["visits"].to_s} times as of "
	# app description with functionality
	app_description = "My app helps you manage your connections."
	# current visiting time
	time = Time.now
	time_str = time.strftime("%A %B %d, %Y %H:%M")
	# greeting
	greeting = ""
	# if no name inputted, general greeting
	if session[:first_name].nil?
		greeting += greetings.sample + "<br/>
		I'm your personal bot.<br/>
		Nice to meet you!"
	# if has name inputted, greeting with name and number
	else
		greeting += greetings.sample + " Welcome back, " + session[:first_name] + session[:number] + "!"
	end
	# display greeting, app description, visit time and current time
	greeting + "<br/>" + app_description + "<br/>" + visit_num + time_str
end

# signup with the secret code
get '/signup' do
	if params[:code].nil? or params[:code] != code
		403
	else
		erb :"signup"
	end
end

# check signup
post "/signup" do
	if params["code"].nil? || params["code"] != code
		403
	elsif params['first_name'].nil? || params['number'].nil?
		"Sorry.You haven't provided all the required information"
	else
		#session['first_name'] = params['first_name']
		#session['number'] = params['number']
		client = Twilio::REST::Client.new ENV["TWILIO_ACCOUNT_SID"], ENV["TWILIO_AUTH_TOKEN"]
		message = "Hi" + params[:first_name] + ", welcome to Walker! I can respond to who, what, where, when and why. If you're stuck, type help."
		client.api.account.messages.create(
			from: ENV["TWILIO_FROM"],
			to: params[:number],
			body: message
		)
		return "Thank you for signing up! You will receive a text message in a few minutes from the bot."
	end
end

# parameters for signup: first name and number
get '/signup/:first_name/:number' do
	session[:first_name] = params[:first_name]
	session[:number] = params[:number]
	"Hi there, #{ params[:first_name]}.<br/>
	Your number is #{ params[:number]}"
	#Your number is #{ params[:number]}"
end

# conversation page
get '/test/conversation' do
	# check if the user input text (Body) and number (From). If not, remind
	if params[:Body].nil? && params[:From].nil?
		return '"Body" and "From" are not populated. <br/>
		Please send some message and your phone number to me.'
	elsif params[:Body].nil?
		return '"Body" is not populated. <br/>
		Please send some message to me.'
	elsif params[:From].nil?
		return '"From" is not populated. <br/>
		Please send your phone number to me.'
	# If already input text and number, respond according to their input
	else
		determine_response params[:Body]
	end
end

get '/html' do
	erb :"signup"
end

get "/test/sms" do
	client = Twilio::REST::Client.new ENV["TWILIO_ACCOUNT_SID"], ENV["TWILIO_AUTH_TOKEN"]

	message = "This is Ruwen's first chatbot."

	# This will send a message from any end point
	client.api.account.messages.create(
		from: ENV["TWILIO_FROM"],
		to: ENV["TEST_NUMBER"],
		body: message
	)
end

get "/sms/incoming" do
	session[:counter] ||= 0

	sender = params[:From] || ""
	body = params[:Body] || ""
	message = determine_response body
	media = nil

	#if session[:counter] == 0
		#message = "Hello, thanks for the new message."
		#media = "https://media.giphy.com/media/RIYgiYTCmostbz0wNx/giphy.gif"
	#else
		#message = "Hello, thanks for the message number #{session[:counter]}"
		#media = nil
	#end

	twiml = Twilio::TwiML::MessagingResponse.new do |r|
		r.message do |m|
			m.body( message )
			unless media.nil?
				m.media( media )
			end
		end
	end

	session[:counter] += 1

	content_type 'text/xml'
	twiml.to_s

end

get "/callback" do
	client = LinkedIn::Client.new(ENV['LINKEDIN_API_KEY'], ENV['LINKEDIN_API_SECRET'])
	client.authorize_from_access(ENV['LINKEDIN_TOKEN'])
	client.connections
	#client.authorize_from_request(params[:code], :redirect_uri => 'https://git.heroku.com/fathomless-lake-42472.git/callback')
end

def determine_media_response body
	q = body.to_s.downcase.strip
	Giphy::Configuration.configure do |config|
		config.api_key = ENV["GIPHY_API_KEY"]
	end
	if q == "surprise"
		giphy_search = "hello"
	else
		giphy_search = nil
	end
	unless giphy_search.nil?
		results = Giphy.search( giphy_search, { limit: 25 } )
		unless results.empty?
			gif = results.sample.fixed_width_downsampled_image.url.to_s
			return gif
		end
	end
	nil
end

error 403 do
	"Access Forbidden"
end


def determine_response body
	#normalize and clean the string of params
	body = body.downcase.strip
	#responses
	response = " "
	# response to hi
	if body == "hi"
		response += "Hi! I'm Networker. I can help you manage your connections on LinkedIn."
	# response to who
	elsif body == "who"
		response += "I'm a MeBot.If you are interested in me, you can learn more by asking me for 'fact'."
	# response to what or help
	elsif body == "what" || body == "help"
		response += "I can be used to ask basic things about you."
	# response to where
	elsif body == "where"
		response += "I'm in Pittsburgh."
	# response to when
	elsif body == "when"
		response += "I was made in Spring 2020."
	# response to why
	elsif body == "why"
		response += "I was made for a class project in Programming for Online Prototyping."
	# response to joke
	elsif body == "joke"
		array_of_lines = IO.readlines("jokes.txt")
		response += array_of_lines.sample
	# response to fact
	elsif body == "fact"
		array_of_lines = IO.readlines("facts.txt")
		response += array_of_lines.sample + "<br> [ask for 'fact' again to know more.]"
	# response to haha or lol
	elsif body == "haha" or body == "lol"
		response += $funny_response.sample
	elsif body == "surprise"
		response = determine_media_response body
	elsif body == "weather"
		options = { units: "metric", APPID: ENV["OPENWEATHER_API_KEY"] }
		response = OpenWeather::Current.city("Pittsburgh, PA", options)
		temp = response['main']['temp']
		desc = response['weather'][0]['description']
		response = "The weather is currently #{desc} with a temperature of #{temp} degrees."
	else
		message = "Sorry, your input cannot be understood by the bot."
		response = send_to_slack message
	end
	response
end

def send_to_slack message
	slack_webhook = ENV['SLACK_WEBHOOK']

  formatted_message = "*Recently Received:*\n"
  formatted_message += "#{message} "

  HTTParty.post slack_webhook, body: {text: formatted_message.to_s, username: "Ruinme", channel: "#ruinbot"}.to_json, headers: {'content-type' => 'application/json'}
end


get "/test/deckofcards/randomcard" do
	response = HTTParty.get("https://deckofcardsapi.com/api/deck/new/shuffle/?deck_count=1")
	puts response.body

	deck_id = response["deck_id"]
	puts "Deck id is #{deck_id}"

	random_card_url = "https://deckofcardsapi.com/api/deck/#{deck_id}/draw/?count=2"
	response = HTTParty.get(random_card_url)
	puts response.body
	#response["cards"].to_json
	response_str = "You have drawn "
	response["cards"].each do |card|
		suit = card["suit"]
		val = card["value"]
		response_str = response_str + "the #{val} of #{suit}, "
	end
	response_str
end

get "/test/jobs/skills" do
	response = HTTParty.get("")
end
