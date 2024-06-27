require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'date'


def clean_zipcode zipcode
  zipcode.to_s.rjust(5, '0')
end

def clean_phone_number number
  return nil unless number
  # these two lines catch the case where the number was recorded as a float
  is_float = !!Float(number) rescue false
  number = number.to_f.to_s if is_float
  # delete all extraneous characters to standardize number format for processing
  number = number.to_s.delete("()").delete("-").delete(" ").delete(".")
  #return 10 digit number without the leading 1, nil if not 10 or 11 digits
  case number.length
  when 10
    return "(#{number[0..2]}) #{number[3..5]}-#{number[6..9]}"
  when 11 && number[0] == 1
    return "(#{number[1..3]}) #{number[4..6]}-#{number[7..10]}"
  else
    nil
  end
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = File.read('secret.key').strip
  begin
    legislators = civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
      ).officials
    # legislators = legislators.officials
    # legislators = legislators.map(&:name).join(", ")
  rescue
    legislators = 'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end

  filename
end

def open_csv(filename)
  CSV.open(
    filename,
    headers: true,
    header_converters: :symbol
  )
end

def csv_reduce(filename, initial_accumulator = 0, skip_headers = true, &block)
  result = initial_accumulator
  File.open(filename).each_with_index do |line, line_num|
    next if skip_headers && line_num == 0
    result = yield(result, line.split(","))
  end
  result
end

def registration_by_hour(filename)
  result_arr = []
  result = csv_reduce('event_attendees.csv', Hash.new(0), true) do |hash, line|
    date = DateTime.strptime(line[1], '%m/%d/%y %k:%M')
    hr = date.strftime("%I:00 %p")
    hash[hr] += 1
    hash
  end
  result.each { |hr, cnt| result_arr << "#{hr} - #{cnt} registrations" }
  result_arr.sort.each { |hr_result| puts hr_result }
end



puts 'Event Manager Initialized!'

filename = 'event_attendees.csv'
lines = open_csv(filename)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

lines.each_with_index do |line, i|
  id = line[0]
  name = line[:first_name]
  zip_code = self.clean_zipcode(line[:zipcode])
  legislators = legislators_by_zipcode(zip_code)
  form_letter = erb_template.result(binding)
  # puts form_letter
  puts "\t#{save_thank_you_letter(id, form_letter)} for #{name} #{line[:last_name]} created..."
  puts "\t\t#{clean_phone_number(line[:homephone])}"
end
registration_by_hour(filename)

puts 'Event Manager Complete!'
