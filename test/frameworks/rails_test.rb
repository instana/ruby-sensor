require 'test_helper'

require 'support/apps/rails/boot'

require_relative 'rails/actioncontroller_test'
require_relative 'rails/activerecord_test'

case Rails::VERSION::MAJOR
when 3
  require_relative 'rails/actionview3_test'
when 4
  require_relative 'rails/actionview4_test'
else
  require_relative 'rails/actionview5_test'
end
