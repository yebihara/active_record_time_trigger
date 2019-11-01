module ActiveRecordTimeTrigger
  class TimeTriggerJob < ApplicationJob
    queue_as :default

    def perform(class_name, record_id, method_name)
      klass = class_name.constantize
      obj = klass.find(record_id)

      # 念のため、現時点でトリガー条件を満たしていることを確認してから実行する
      obj.send(method_name) if obj.test_trigger_conditions[method_name]
    end
  end
end
