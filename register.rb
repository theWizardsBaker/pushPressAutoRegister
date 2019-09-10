#!/usr/bin/env ruby
require 'watir'
require 'yaml'
require 'colorize'

begin
	puts "Starting".green
	registration = ClassRegistration.new
	registration.register()
rescue Exception => e
	puts "#{e.message}".red
	puts "Aborting".yellow
	exit!
end

class ClassRegistration

	# months and days
	CUR_MONTH = Date.today.strftime("%B").downcase
	CUR_DAY = Date.today.wday
	# days as integers
	DAYS_OF_WEEK = %w[ sunday monday tuesday wednesday thursday friday saturday ]

	def initialize()
    	# read config file
		@config_file = YAML.load(File.read(File.join(File.absolute_path('./', File.dirname(__FILE__)), 'config.yaml')))
		# @config_file = YAML.load File.read('config.yaml')
		# set the driver
		raise LoadError.new("Chrome Driver not found at '#{@config_file[:chromedriver]}'.") unless self.set_chromedriver
  	end

  	def register()
		@browser = Watir::Browser.new :chrome, headless: true

  		raise RuntimeError.new('Could not login. Please check the credentials in the conf.yaml file.') unless self.login()
		# go to schedule
		@browser.goto 'https://mktfitness.members.pushpress.com/schedule/index'
		puts "Working..."
		# run day / week / month
		run_time = @config_file[:schedule]

		loop do
			# get site's dotw and month
			text = @browser.a( id: 'date-list' ).strong.text.split "\n"
			day_of_week = text[0].downcase
			month = (text[1].split " ")[0].downcase
			# get the site's day's index
			current_day_index = DAYS_OF_WEEK.index day_of_week
			class_time = self.get_time current_day_index

			begin
				register(class_time)
				puts "Registered for class #{class_time} on #{text[0]} #{text[1]}"
			rescue
				puts "ERROR: UNAVAILBLE class #{class_time} on #{text[0]} #{text[1]}".red
			ensure
				# break after the first iteration. we only want today
				break if run_time.equals('today')
				# break after the currenty week day is on saturday
				break if run_time.equals('week') and current_day_index >= 6
				# break if we've moved out of the current month
				break if run_time.equals('month') and not month.eql?(CUR_MONTH)
			end

		end

  	end

  	private

	def get_time(day_of_the_week_index)
		# figure out what day of the week we're looking at
		return case day_of_the_week_index
		# sunday
		when 0
			@config_file[:times][:weekend][1]
		# when saturday
		when 6
			@config_file[:times][:weekend][0]
		else
			if @config_file[:times][:weekday].size > 1
				@config_file[:times][:weekday][day_of_the_week_index]
			else
				@config_file[:times][:weekday][0]
			end
		end
	end

	def set_chromedriver()
		puts "loading chrome driver"
		begin
			# default driver location
			default_chromedriver_path = File.join(File.absolute_path('./', File.dirname(__FILE__)), @config_file[:chromedriver])
			# default_chromedriver_path = 
			# set driver
			Selenium::WebDriver::Chrome::Service.driver_path = default_chromedriver_path
			return true
		rescue
			return false
		end
	end

	def login()
		begin
			puts 'loggin in...'
			# login
			@browser.goto 'https://mktfitness.members.pushpress.com/login?'
			# check for the login button
			loginButton = @browser.button text: 'Login'
			#set email
			loginButton.click
			# set email
			email = @browser.text_field id: 'email' 
			email.set @config_file[:login][:username]
			contButton = @browser.button text: 'Continue'
			contButton.click
			#set password
			password = @browser.text_field id: 'password'
			password.set @config_file[:login][:password]
			@browser.send_keys :enter
			return true
		rescue
			return false
		end
	end

	def register(time)
		# get the class we want
		span = @browser.span text: time
		# go up to the row parent
		row = span.parent class: 'tr'
		# get reservation button
		# reservation_button = row.div class: 'reservation'
		# reservation_button.click
		row.click
		# get ID of the model without the pound sign
		reservation_id = row.attribute_value('data-target')[1..-1]
		popup = @browser.div id: reservation_id
		# find the submit button
		submit = popup.button type: 'submit'
		#click submit button
		submit.click
		# the div that pops up has the same ending id, so let's get that
		plan_number = reservation_id.match(/\d+$/)[0]
		# get the modal
		modal = @browser.div id: 'select-plan-' + plan_number
		modal_button = modal.button 'modal-id': 'select-plan-' + plan_number
		modal_button.click
		# wait for effect to take place
		Watir::Wait.until(timeout: 60, message: 'Site Timeout!') { @browser.div( class:'success-message', text:'Class reserved successfully').exists? }
	end
end

