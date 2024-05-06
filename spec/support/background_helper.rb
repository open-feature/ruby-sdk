# frozen_string_literal: true

module BackgroundHelper
  attr_writer :threads

  private

  def background(&)
    thread = Thread.new(&)
    thread.report_on_exception = false
    threads << thread
    thread.join(0.1)
    thread
  end

  def threads
    @threads ||= []
  end

  def yield_to_background
    threads.each(&:join)
  end
end

RSpec.configure do |config|
  config.after do
    threads.each(&:kill)
    self.threads = []
  end
  config.include(BackgroundHelper)
end
