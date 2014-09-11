require "bundler"
Bundler.require

require "sinatra"
require "sinatra/flash"
require "sinatra/reloader" if Sinatra::Base.development?
require "icalendar/tzinfo"

def get_season
	(Time.now.month > 8 ? "f" : "s") + Time.now.year.to_s
end

def get_mlh_url(cc)
	case cc.upcase
	when "GB"
		"http://mlh.io/seasons/#{get_season}-uk/events"
	else
		"http://mlh.io/seasons/#{get_season}/events"
	end
end

def parse_time(cc, time_string)
	timezone = TZInfo::Country.get(cc).zone_identifiers.first.to_s
	tz = TZInfo::Timezone.get(timezone)
	tz.utc_to_local(Time.parse(time_string).utc)
end

def get_mlh_events_as_ical(cc)
	cal = Icalendar::Calendar.new
	html = HTTParty.get(get_mlh_url(cc)).body
	doc = Nokogiri::HTML(html)
	timezone = TZInfo::Country.get(cc).zone_identifiers.first.to_s

	doc.css('.event').each do |e|
		event_logo = e.css('.event-logo img').first.attribute("src").to_s
		event_image = e.css('.image-wrap img').first.attribute("src").to_s
		event_name = e.css('h3').first.content.to_s
		event_url = e.css('.event-wrapper > a[target="_blank"]').first.attribute("href").to_s
		event_date = e.css('p')[0].content.to_s.gsub(/(?<=[0-9])(?:st|nd|rd|th)/, "")
		event_location = e.css('p')[1].content.to_s

		event_date_split = event_date.split(' - ')

		if event_date_split.count == 2
			event_start = parse_time(cc, event_date_split[0])
		else
			event_start = parse_time(cc, event_date)
			event_ends = Date.parse(event_date) + (60*60*48) if Time.parse(event_date).wday == 5 # if starts on a friday, it usually ends on sunday
			event_ends = Date.parse(event_date) + (60*60*24) if Time.parse(event_date).wday == 6 # if starts on saturday, it usually ends on a sunday
			event_ends = parse_time(cc, event_ends.to_s)
		end

		proposed_time = event_start
		event_ends = proposed_time if proposed_time.day === event_date.split(' - ')[1].to_s.gsub(/\D+/i, "").to_i

		proposed_time = event_start + (60 * 60 * 24)
		event_ends = proposed_time if proposed_time.day === event_date.split(' - ')[1].to_s.gsub(/\D+/i, "").to_i		

		proposed_time = event_start + (60 * 60 * 48)
		event_ends = proposed_time if proposed_time.day === event_date.split(' - ')[1].to_s.gsub(/\D+/i, "").to_i

		proposed_time = event_start + (60 * 60 * 72)
		event_ends = proposed_time if proposed_time.day === event_date.split(' - ')[1].to_s.gsub(/\D+/i, "").to_i

		# If hackathon starts on Saturday: let's assume it starts at 10am.
		# If hackathon starts on Friday: let's assume it starts at 4pm.
		hour_to_start = (event_start.wday == 6) ? 10 : 16
		event_start = event_start + (60*60 * (hour_to_start - event_start.hour))

		# Assume event ends at 4pm on Sunday
		hour_to_finish = 16
		event_ends = event_ends + (60*60 * (hour_to_finish - event_ends.hour))

		event = Icalendar::Event.new
		event.summary = event_name
		event.description = "MLH #{cc}: #{event_name} hackathon in #{event_location}: #{event_url}"
		event.dtstart = event_start
		event.dtend = event_ends

		cal.add_event(event) if event_date.gsub(/\D+/i, "").to_i > 0
	end

	tz = TZInfo::Timezone.get(timezone)
	_timezone = tz.ical_timezone(Time.now)
	cal.add_timezone _timezone

	cal.to_ical
end

get '/' do
	response.headers['Content-Type'] = 'text/calendar'
	# response.headers['Content-Type'] = 'text/plain' if Sinatra::Base.development?
	response['Access-Control-Allow-Origin'] = '*'

	# What's my IP?
	ip = request.env['HTTP_X_FORWARDED_FOR'] || request.env['REMOTE_ADDR']
	ip = "78.148.236.114" if Sinatra::Base.development?

	# Where am I?
	geo = Geocoder.search(ip)
	cc = (geo.count > 0) ? geo[0].country_code : "US"
	cc = "US" unless ["US", "GB"].include?(cc)

	get_mlh_events_as_ical(cc)
end

get '/:country' do
	response.headers['Content-Type'] = 'text/calendar'
	# response.headers['Content-Type'] = 'text/plain' if Sinatra::Base.development?
	response['Access-Control-Allow-Origin'] = '*'

	params[:country].upcase!

	if params[:country] == "GB" or params[:country] == "UK"
		cc = "GB"
	else
		cc = "US"
	end

	get_mlh_events_as_ical(cc)
end


get '/:country.ics' do
	response.headers['Content-Type'] = 'text/calendar'
	# response.headers['Content-Type'] = 'text/plain' if Sinatra::Base.development?
	response['Access-Control-Allow-Origin'] = '*'
	
	params[:country].upcase!

	if params[:country] == "GB" or params[:country] == "UK"
		cc = "GB"
	else
		cc = "US"
	end

	get_mlh_events_as_ical(cc)
end