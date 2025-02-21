# All logging should be done through the log method. This will log to both the console and a file, ensuring consistency
# across all reports and tasks.
def log(*message)
  log_to_console(message&.first)
  log_to_file(*message)
end

def benchmark(*message)
  log(*message)
  start_time = Time.now
  yield
  end_time = Time.now
  log("Finished in #{end_time - start_time} seconds.")
end

def log_to_console(*messages)
  prefix = "[DRY RUN] "
  messages.each { |m| puts "#{prefix}#{m}" } unless Rails.env.test?
end

def log_to_file(*message)
  File.open(file_path("dry_run.log"), 'a+') do |f|
    f.write("-" * 80 + "\n")
    f.write(DateTime.now.strftime("%Y-%m-%d %H:%M:%S.%L") + "\n")
    message.each { |m| f.write("#{m}\n") }
    f.write("-" * 80 + "\n")
  end
end

def dry_run_start_date
  File.foreach(file_path("dry_run.log")) do |line|
    # datetime_format = "%Y-%m-%d %H:%M:%S.%L"
    # Example: 2021-03-31 15:00:00.000
    # Make sure this matches the format used in log_to_file
    datetime_match = line.match(/\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}/)
    next unless datetime_match

    datetime_string = datetime_match[0]
    begin
      datetime = datetime_string ? DateTime.parse(datetime_string) : DateTime.now
      return datetime
    rescue ArgumentError
      # Ignore invalid datetime strings
    end
  end

  nil # No valid datetime matching the format found
end

def dry_run_end_date
  DateTime.now
end

def file_path(file_name)
  Dir.mkdir(root_path) unless Dir.exist?(root_path)
  "#{root_path}#{file_name.to_s}"
end

def root_path
  "#{Rails.root}/dry_run_report/"
end

def to_csv(file_name, mode = "a+", &block)
  CSV.open(file_path("#{file_name}.csv"), mode, &block)
end

# Delete all records from a mongo collection and log the result
# @param [Mongoid::Criteria] obj
# @return [nil]
# @example
#  delete_all(User.where(:name => "John"))
def delete_all(obj)
  return unless obj

  total = obj.count
  if obj.empty?
    log("No #{get_class_name(obj)} found to delete")
  else
    obj.destroy_all && log("#{total} #{get_class_name(obj)} deleted")
  end
end

# Get all records from a mongo collection and log them
# @param [Mongoid::Criteria] obj
# @return [nil]
# @example
# get_all(User.where(:name => "John"))
def get_all(obj)
  return unless obj

  unless obj.empty?
    log("#{obj.count} #{get_class_name(obj)} found", obj.to_a)
  else
    log("0 #{get_class_name(obj)} found")
  end
end

def get_class_name(object)
  if object.respond_to?(:model_name)
    object.model_name.name
  elsif object.respond_to?(:first)
    object.first.class
  elsif object.respond_to?(:klass)
    object.klass
  else
    object.class
  end
end

def result_message(result)
  if result.success?
    result.value!
  else
    result.failure
  end
end

def result_type(result)
  if result.success?
    "success"
  else
    "failure"
  end
end
