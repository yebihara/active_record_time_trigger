Rails.application.routes.draw do
  mount ActiveRecordTimeTrigger::Engine => "/active_record_time_trigger"
end
