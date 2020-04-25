# ActiveRecordTimeTrigger
Automatic asynchronous job invocation that depends on a date or datetime attribute of any ActiveRecord object.

This is inspired by Salesforce's [workflow time trigger](https://help.salesforce.com/articleView?err=1&id=workflow_time_dependent.htm&type=5&lang=en_US) function.

## Usage
### Active Job
First, you have to configure [Active Job](https://guides.rubyonrails.org/active_job_basics.html).
You can use any type of backend that supports Active Job.

But note that ["Delayed" feature](https://api.rubyonrails.org/v6.0.0/classes/ActiveJob/QueueAdapters.html#module-ActiveJob::QueueAdapters-label-Delayed) must be enabled.

For example, if you use [resque](https://github.com/resque/resque) as the backend, you also have to introduce [resque-scheduler](https://github.com/resque/resque-scheduler).

### Working with your ActiveRecord class
Add `include TimeTrigger` to include the concern and enable time trigger using `time_trigger` statement.

Here is an example.

```ruby
class Inquiry < ApplicationRecord
  include TimeTrigger

  # send an email to the owner agent of an open inquiry on the previous day of the due date
  time_trigger :email_to_agent, on: :due_date, before: 1.day, unless: :closed?

  def email_to_agent
    # send an email in some way
  end
end

```

You have to pass the name of the method that you want to be invoked automatically and some mandatory and optional parameters.

```ruby
time_trigger method_name, on: :date_attribute_name
```

```ruby
time_trigger method_name, at: :datetime_attribute_name
```

Options as follows are supported.

* at
  * name of the datetime attribute used as the base time to calculate the target time when the method should be invoked
* on
  * name of the date attribute used as the base time to to calculate the target time when the method should be invoked
  * time part is considered to be 00:00:00
* before / after
  * specify how earlier or later the method should be invoked than the base time
  * `1.day`, `10.minites`...
* if / unless
  * a symbol corresponding to the name of a predicate method that decide if the method invocation job should be actually scheduled or not

## Installation
Clone this repository and add this line to your application's Gemfile:

```ruby
gem 'active_record_time_trigger', path: 'path_to_/active_record_time_trigger'
```

And then execute:
```bash
$ bundle install
```

## Contributing
Currently not accepted.

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
