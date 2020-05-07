require "sinatra"
require 'sinatra/reloader' if development?
require 'twilio-ruby'
require 'httparty'
require 'json'
require 'giphy'
require 'faraday'
require 'linkedin-v2'
require "careerjet/api_client"
require 'hashie'
require 'multi_json'
require 'oauth'
require 'emoji'
require 'sentimental'

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
$greetings = ["Hello!", "Hi!", "Hey!", "What's up!", "Good to see you!", "Hey there!"]
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
		greeting += $greetings.sample + "<br/>
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
		message = "#{first_greeting} #{params[:first_name]}. I'm a super funny guy. I can help you succeed in job hunting. If you want to know more, reply 'what'!"
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
	session["last_intent"] ||= nil

	sender = params[:From] || ""
	body = params[:Body] || ""
	message = determine_response body, sender
	media = determine_media_response body

	#if session[:counter] == 1
		#media = "https://media.giphy.com/media/RIYgiYTCmostbz0wNx/giphy.gif"
	#else
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

	LinkedIn.configure do |config|
		config.client_id     = ENV["LINKEDIN_API_KEY"]
		config.client_secret = ENV["LINKEDIN_API_SECRET"]
		config.redirect_uri  = "https://fathomless-lake-42472.herokuapp.com/callback"
	end

	api = LinkedIn::API.new(ENV['LINKEDIN_TOKEN'])
	linkedin = JSON.parse(api.profile(:url => 'https://www.linkedin.com/in/kl-larson/').to_json)
  puts linkedin
	"#{linkedin}"
end
	#api = LinkedIn::API.new(ENV['LINKEDIN_TOKEN'])
	#me = api.profile


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


def determine_response body, sender
	#keywords
	greeting_kwd = ['hi', 'hello', 'hey']
	who_kwd = ['who']
	what_kwd = ['what', 'features', 'functions', 'actions', 'help']
	where_kwd = ['where']
	when_kwd = ['when', 'time']
	why_kwd = ['why']
	joke_kwd = ['joke']
	fact_kwd = ['fact']
	funny_kwd = ['lol', 'haha', 'hh']

	#normalize and clean the string of params
	body = body.downcase.strip

	#responses
	response = " "
	# response to hi
	if include_keywords body, greeting_kwd
		send_sms_to sender, general_greeting
		sleep(1)
		response += "You can reply help to check what I can do for you."
	# response to who
	elsif include_keywords body, who_kwd
		smirk = emoji "smirk"
		response += "I'm Walker! I'm smart #{smirk} and know
all of the skills and jobs in the world."
	# response to what or help
	elsif include_keywords body, what_kwd
		confused = emoji "confused"
		send_sms_to sender, "Do you feel confused #{confused}?"
		sleep(2)
		send_sms_to sender, "There are so many jobs."
		sleep(2)
		send_sms_to sender, "They require the same skills but have different titles!"
		sleep(2)
		send_sms_to sender, "Then how can you know what title to search?"
		sleep(2)
		send_sms_to sender, "Well, I can help you to find similar job titles and skills to search more jobs!"
		sleep(2)
		response += "Reply 'help' when you are ready to start new journey!"
	# response to where
	elsif include_keywords body, where_kwd
		laughing = emoji "laughing"
		response += "I'm always on the way to help you! #{laughing}"
	# response to when
	elsif include_keywords body, when_kwd
		send_sms_to sender, "I was born in 2020."
		sleep(2)
		pouting_cat_face = emoji "pouting_cat_face"
		response += "But my mind is as mature as a 40-year-old #{pouting_cat_face}!"
	# response to why
	elsif include_keywords body, why_kwd
		person_raising_both_hands_in_celebration = emoji "person_raising_both_hands_in_celebration"
		response += "#{person_raising_both_hands_in_celebration}I was made to help you succeed in career shift and job hunting."
	# response to joke
	elsif include_keywords body, joke_kwd
		array_of_lines = IO.readlines("jokes.txt")
		response += array_of_lines.sample
	# response to fact
	elsif include_keywords body, fact_kwd
		array_of_lines = IO.readlines("facts.txt")
		response += array_of_lines.sample + "<br> [ask for 'fact' again to know more.]"
	# response to haha or lol
	elsif include_keywords body, funny_kwd
		response += $funny_response.sample
	elsif body == "surprise"
		response = determine_media_response body
	elsif body == "job"
		session["last_intent"] = "ask_job"
		response += "What job are you interested in?"
	elsif session["last_intent"] == "ask_job"
		related_jobs = related_jobs body
		send_sms_to sender, "Here are some similar jobs:
#{related_jobs}"
		sleep (3)
		send_sms_to sender, "Don't forget to searh them! They all require similar skills!"
		sleep (3)
		response += "Reply 'job' to search other jobs.
Or reply 'start' to see what others you can do."
	#elsif session["last_session"] == "related_job" && body == "skill"
	elsif body == "skill"
		session["last_intent"] = "ask_skill"
		response += "Tell me one skill you have~"
	elsif session["last_intent"] == 'ask_skill'
		related_skills = related_skills body
		send_sms_to sender, "Here are some similar skills:
#{related_skills}"
		sleep (3)
		send_sms_to sender, "See! You already have all the skills above! You can get jobs which require them."
		sleep (3)
		response += "Reply 'skill' to search other skills.
Or reply 'start' to see what others you can do."
	elsif body == "skilljob"
		session["last_intent"] = "ask_skilljob"
		response += "Tell me one skill you have~"
	elsif session["last_intent"] = "ask_skilljob"
		related_jobs = skills_jobs body
		send_sms_to sender, "Here are some jobs related to the skill:
#{related_jobs}"
		sleep (3)
		send_sms_to sender, "You can apply for the jobs above since you already have the skill required!"
		sleep (3)
		response += "Reply 'skilljob' to continue.
Or reply 'start' to see what others you can do."
	elsif body == "jobskill"
		session["last_intent"] = "ask_jobskill"
		response += "What job are you interested in?"
	elsif session["last_intent"] = "ask_jobskill"
		related_skills = jobs_skills body
		send_sms_to sender, "Here are some skills related to the job:
#{related_skills}"
		sleep (3)
		send_sms_to sender, "You can check what are the skills you don't have for the job and try to improve them!"
		sleep (3)
		response += "Reply 'jobskill' to continue.
Or reply 'start' to see what others you can do."
	else
		face_with_no_good_gesture = emoji "face_with_no_good_gesture"
		expressionless = emoji "expressionless"
		dizzy_face = emoji "dizzy_face"
		misunderstanding = ["Maybe I know it. #{expressionless}But I just don't want to reply.", "Fine.#{dizzy_face} I admit that I don't know this one.", "I know jobs but I am not an #{face_with_no_good_gesture}encyclopedia..."]
		response += misunderstanding.sample
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

get "/test/jobs-skills" do
	skills_jobs "biking"
end

def related_jobs body
	id = HTTParty.get("http://api.dataatwork.org/v1/jobs/normalize?job_title=#{body}")[0]['uuid']
	related_jobs = HTTParty.get("http://api.dataatwork.org/v1/jobs/#{id}/related_jobs")["related_job_titles"]
	jobs = ""
	related_jobs.each do |related_job|
		title = related_job['title']
		jobs = jobs + title + ', '
	end
	"#{jobs[0...-2]}"
end

def related_skills body
	id = HTTParty.get("http://api.dataatwork.org/v1/skills/normalize?skill_name=#{body}")[0]['uuid']
	related_skills = HTTParty.get("http://api.dataatwork.org/v1/skills/#{id}/related_skills")["skills"]
	skills = ""
	related_skills.each do |related_skill|
		skill_name = related_skill['skill_name']
		skills = skills + skill_name + ', '
	end
	"#{skills[0...-2]}"
end

def jobs_skills body
	id = HTTParty.get("http://api.dataatwork.org/v1/jobs/normalize?job_title=#{body}")[0]['uuid']
	related_skills = HTTParty.get("http://api.dataatwork.org/v1/jobs/#{id}/related_skills")["skills"]
	skills = ""
	puts related_skills
	related_skills.each do |related_skill|
		skill_name = related_skill['skill_name']
		skills = skills + skill_name + ', '
	end
	"#{skills[0...-2]}"
end

def skills_jobs body
	id = HTTParty.get("http://api.dataatwork.org/v1/skills/normalize?skill_name=#{body}")[0]['uuid']
	related_jobs = HTTParty.get("http://api.dataatwork.org/v1/skills/#{id}/related_jobs")["jobs"]
	jobs = ""
	puts related_jobs
	related_jobs.each do |related_job|
		title = related_job['job_title']
		jobs = jobs + title + ', '
	end
	"#{jobs[0...-2]}"
end


get "/test/sentiment" do
	analyzer = Sentimental.new
	analyzer.load_defaults
	result = analyzer.sentiment "I didn't get the job"
	puts result
	"#{result}"
end


#find an Emoji
def emoji feeling
	index = Emoji::Index.new
	index.find_by_name(feeling)['moji']
end


# choose a random greeting from greetings array
def greeting
	$greetings.sample
end

# First Time Introduction to Walker
def first_greeting
	emoji = emoji 'wink'
	greeting + " I'm Walker #{emoji}"
end

# General greeting
def general_greeting
	greeting + " What can I help you?"
end



# What problem does Walker solve?
def problem
	emoji = emoji "confused"
	"Do you feel confused #{emoji} when there are so many different names for one job or one skill and you don't know how to find a right name to search a job? I can help you with it!"
end

def send_sms_to send_to, message
	 client = Twilio::REST::Client.new ENV["TWILIO_ACCOUNT_SID"], ENV["TWILIO_AUTH_TOKEN"]
	 client.api.account.messages.create(
		 from: ENV["TWILIO_FROM"],
	   to: send_to,
	   body: message
	 )
 end

 def include_keywords body, keywords
	# check if string contains any word in the keywords array
	keywords.each do |keyword|
		if body.downcase.include?(keyword)
			return true
		end
  end
	return false
end
