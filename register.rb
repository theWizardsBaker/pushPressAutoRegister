#!/usr/bin/env ruby
require 'watir'
require 'yaml'
require 'colorize'

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
		raise LoadError.new("Chrome Driver not found at '#{@config_file[:chromedriver]}'") unless set_chromedriver
  	end

  	def register()
  		# create browser
		@browser = Watir::Browser.new :chrome, headless: @config_file[:visual]
		# login to pushpress
  		raise RuntimeError.new('Could not login. Please check the credentials in the conf.yaml file.') unless login()
  		# wait for how freaking slow their servers are
  		Watir::Wait.until(timeout: 60, message: 'Site Timeout!') { @browser.title.eql?("MKT FIT") }
  		sleep 3
		# go to schedule
		@browser.goto 'https://mktfitness.members.pushpress.com/schedule/index'
		puts "Working..."
		# run day / week / month
		run_time = @config_file[:schedule]
		# check the schedule option so we don't run to oblivion
		raise ScriptError.new("Schedule: '#{@config_file[:schedule]}' is not a valid option") unless %w[ today week month ].index @config_file[:schedule]

		loop do
			# wait for page to load
	  		Watir::Wait.until(timeout: 60, message: 'Schedule Page Timeout!') { @browser.hidden( id: 'csrf').exists? }
	  		sleep 2
			# get site's dotw and month
			text = @browser.a( id: 'date-list' ).strong.text.split "\n"
			day_of_week = text[0].downcase
			calendar_date = text[1]
			month = (text[1].split ' ')[0].downcase
			# get the site's day's index
			current_day_index = DAYS_OF_WEEK.index day_of_week
			class_time = get_time current_day_index
			# try to register for the class
			begin

				success = false

				# check that we're trying to register before the class
				# if the date's today
				if Date.today.strftime("%B %d, %Y").eql? calendar_date
					# and the time is before the class
					if Time.new.to_f < Time.parse(class_time).to_f
						success = register_class(class_time)
					end
				else
					success = register_class(class_time)
				end

				# output
				if success
					puts "SUCCESS: ".green + "Registered for class #{class_time} on #{text[0]} #{text[1]}"
				else
					puts "FAILED: ".red + "Too late to register for class #{class_time} on #{text[0]} #{text[1]}"
				end

			rescue
				puts "ERROR: ".red + "UNAVAILBLE class #{class_time} on #{text[0]} #{text[1]}"
			ensure
				# break after the first iteration. we only want today
				break if run_time.eql?('today')
				# break after the currenty week day is on saturday
				break if run_time.eql?('week') and current_day_index >= 6
				# break if we've moved out of the current month
				break if run_time.eql?('month') and not month.eql?(CUR_MONTH)

				# click to the 'next page'
				next_arrow = @browser.span( class: 'pp-icons-arrow-right-2' ).parent
				next_arrow.click
			end
		end


		@browser.close if @browser

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

	def register_class(time)
		# get the class we want
		span = @browser.span text: time
		# make sure the span exists
		return false unless span.exists?

		#span exists
		# go up to the row parent
		row = span.parent class: 'tr'
		# get reservation button
		reservation_button = row.div class: 'reservation'
		# make sure reservation button exists
		return false unless reservation_button.exists?

		# reservation exists
		reservation_button.click
		# row.click
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

		# return success
		return true
	end
end

begin
	print "Starting".green
	print " PushPress ".blue
	puts "auto-registration".green
	registration = ClassRegistration.new
	registration.register()
rescue Exception => e
	puts "#{e.message}".red
	puts "Aborting".yellow
	exit!
end

