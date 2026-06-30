class ApplicationJob < ActiveJob::Base
  include ApplicationJobRetryPolicy
  include JobWithWork
end
