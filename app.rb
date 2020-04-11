require "sinatra"
require 'sinatra/reloader' if development?

enable :sessions

# global variables
greetings = ["Hello!", "Hi!", "Hey!", "What's up!", "Good to see you!", "Hey there!"]
$funny_response = ["funny right?", "Glad it makes you laugh!", "It's my pleasure to bring you joy!", "You can ask for 'joke' again and I'll tell you another one.", "I'm funny and attractive, right?"]
$code = "meruinyou"

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
	if params[:code].nil? or params[:code] != $code
		403
	else
		erb :"signup"
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

# to do
get '/incoming/sms' do
	403
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
	end
	response
end
