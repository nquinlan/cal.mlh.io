require "bundler"
Bundler.require

require "sinatra"
require "sinatra/flash"
require "sinatra/reloader" if Sinatra::Base.development?
require "icalendar/tzinfo"

# Monkey patch icalendar to allow for dtstamp
module Icalendar
	class Calendar
		optional_single_property :dtstamp, Icalendar::Values::DateTime
	end
end

def get_season
	(Time.now.month > 8 ? "f" : "s") + Time.now.year.to_s
end

def get_mlh_url(country_code)
	case country_code.upcase
	when "GB"
		"http://mlh.io/seasons/#{get_season}-uk/events"
	else
		"http://mlh.io/seasons/#{get_season}/events"
	end
end

def parse_time(country_code, time_string)
	timezone = TZInfo::Country.get(country_code).zone_identifiers.first.to_s
	tz = TZInfo::Timezone.get(timezone)
	tz.utc_to_local(Time.parse(time_string).utc) + (60*60*24) # Seems to be a date error. Add 24 hours.
end

def get_mlh_events_as_ical(country_code, all_day=false)
	cal = Icalendar::Calendar.new
	cal.prodid = "-//Major League Hacking//cal.mlh.io//EN"
	cal.dtstamp = Date.new
	html = HTTParty.get(get_mlh_url(country_code)).body
	doc = Nokogiri::HTML(html)
	timezone = TZInfo::Country.get(country_code).zone_identifiers.first.to_s

	doc.css('.event').each do |e|
		event_logo = e.css('.event-logo img').first.attribute("src").to_s
		event_image = e.css('.image-wrap img').first.attribute("src").to_s
		event_name = e.css('h3').first.content.to_s
		event_url = e.css('.event-wrapper > a[target="_blank"]').first.attribute("href").to_s
		event_date = e.css('p')[0].content.to_s.gsub(/(?<=[0-9])(?:st|nd|rd|th)/, "")
		event_location = e.css('p')[1].content.to_s

		event_date_split = event_date.split(' - ')

		if event_date_split.count == 2
			event_start = parse_time(country_code, event_date_split[0])
		else
			event_start = parse_time(country_code, event_date)
			event_end = Date.parse(event_date) + (60*60*48) if Time.parse(event_date).wday == 5 # if starts on a friday, it usually ends on sunday
			event_end = Date.parse(event_date) + (60*60*24) if Time.parse(event_date).wday == 6 # if starts on saturday, it usually ends on a sunday
			event_end = parse_time(country_code, event_end.to_s)
		end

		proposed_time = event_start
		event_end = proposed_time if proposed_time.day === event_date.split(' - ')[1].to_s.gsub(/\D+/i, "").to_i

		proposed_time = event_start + (60 * 60 * 24)
		event_end = proposed_time if proposed_time.day === event_date.split(' - ')[1].to_s.gsub(/\D+/i, "").to_i		

		proposed_time = event_start + (60 * 60 * 48)
		event_end = proposed_time if proposed_time.day === event_date.split(' - ')[1].to_s.gsub(/\D+/i, "").to_i

		proposed_time = event_start + (60 * 60 * 72)
		event_end = proposed_time if proposed_time.day === event_date.split(' - ')[1].to_s.gsub(/\D+/i, "").to_i

		# If hackathon starts on Saturday: let's assume it starts at 10am.
		# If hackathon starts on Friday: let's assume it starts at 4pm.
		hour_to_start = (event_start.wday == 6) ? 10 : 16
		event_start = event_start + (60*60 * (hour_to_start - event_start.hour))

		# Assume event ends at 4pm on Sunday
		hour_to_finish = 16
		event_end = event_end + (60*60 * (hour_to_finish - event_end.hour))

		event = Icalendar::Event.new
		event.summary = event_name
		event.description = "MLH #{country_code}: #{event_name} hackathon in #{event_location}."
		event.location = event_location
		event.url = event_url
		event.url.ical_params = { "VALUE" => "URI" }
		event.dtstart = event_start
		event.dtend = event_end

		if all_day
			event.dtstart = Icalendar::Values::Date.new(event_start)
			event.dtstart.ical_params = { "VALUE" => "DATE" }
			event.dtend = Icalendar::Values::Date.new(event_end)
			event.dtend.ical_params = { "VALUE" => "DATE" }
		end

		cal.add_event(event) if event_date.gsub(/\D+/i, "").to_i > 0
	end

	# Disabled for now. Seems to mess the dates up. We'll get back to this soon.
	# tz = TZInfo::Timezone.get(timezone)
	# _timezone = tz.ical_timezone(Time.now)
	# cal.add_timezone _timezone

	cal.to_ical
end

def set_headers
	response.headers['Content-Type'] = 'text/calendar'
	response.headers['Content-Type'] = 'text/plain' if Sinatra::Base.development?
	response['Access-Control-Allow-Origin'] = '*'
end

def determine_country (country)
	
	if !country.nil?
		# If country exists, let's just take that
		country.upcase!
		country_code = ["GB", "UK"].include?(country) ? "GB" : "US"
	else
		# Otherwise let's look it up

		# What's my IP?
		ip = request.env['HTTP_X_FORWARDED_FOR'] || request.env['REMOTE_ADDR']

		# Where am I?
		geo = Geocoder.search(ip)
		country_code = (geo.count > 0) ? geo[0].country_code : "US"
		country_code = "US" unless ["US", "GB"].include?(country_code)
	end

	country_code
end

def create_feed
	set_headers

	country_code = determine_country params[:country]

	# Do I want all day events?
	all_day = !params[:all_day].nil?

	get_mlh_events_as_ical(country_code, all_day)
end

get '/' do
	create_feed
end

get '/:country.ics' do
	create_feed
end

get '/:country' do
	create_feed
end