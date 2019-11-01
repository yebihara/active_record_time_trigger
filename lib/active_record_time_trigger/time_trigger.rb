# frozen_string_literal: true

module TimeTrigger
  extend ActiveSupport::Concern

  included do
    # 更新前の状態がトリガー条件を満たしているか否かを検査
    after_find { @trigger_condition_results_before = test_trigger_conditions }

    # 更新後の状態がトリガー条件を満たしているか否かを検査
    after_save do
      @trigger_condition_results_after = test_trigger_conditions

      # TODO: タイムトリガーの at/on で参照されている日付/日時属性の値が更新された場合はジョブを再スケジュール
    end

    # コミット後にジョブを登録・キャンセル
    after_commit :manage_time_trigger_jobs
  end

  class_methods do
    def time_trigger(method_name, opts = {})
      time_trigger_settings[method_name.to_s] = opts
    end

    def time_trigger_settings
      @time_trigger_settings ||= {}
    end
  end

  # 全てのタイムトリガーについて、このレコードが起動条件を満たしているかを検査し、
  # その結果をHash（キーがトリガーメソッド名、値が検査結果を表すBoolean）を返す。
  # TODO: if/unlessではProcや配列など、ActiveRecord相当の表現をサポートをしたい
  # https://railsguides.jp/active_record_callbacks.html#%E6%9D%A1%E4%BB%B6%E4%BB%98%E3%81%8D%E3%82%B3%E3%83%BC%E3%83%AB%E3%83%90%E3%83%83%E3%82%AF
  def test_trigger_conditions
    results = {}

    self.class.time_trigger_settings.each do |method_name, opts|
      if_method = opts[:if]
      unless_method = opts[:unless]

      if_result = if if_method
                    send(if_method) ? true : false # nilにならないようにしている
                  else
                    true
                  end

      results[method_name] = if if_result && unless_method # if条件がfalseなら検査不要
                               !send(unless_method) ? true : false
                             else
                               if_result
                             end
    end

    results
  end

  private

  def manage_time_trigger_jobs
    @trigger_condition_results_after.each do |method_name, result_after|
      if @trigger_condition_results_before.nil?
        # 新規作成時は現在の状態だけからトリガーするかどうかを判断してよい
        enqueue_time_trigger_job(method_name) if result_after
      else
        result_before = @trigger_condition_results_before[method_name]

        # 更新時はトリガー条件が false → true と変化したならトリガーする
        enqueue_time_trigger_job(method_name) if !result_before && result_after

        # トリガー条件が true → false ならジョブをキャンセルする
        # ただし念のため、更新後の状態がfalseなら常にキャンセル（未スケジュールなら空振りしてくれればよい）
        cancel_time_trigger_job(method_name) unless result_after
      end
    end

    # 後続のトランザクションで再更新されるのに備えて、現在の状態を「更新前状態」とする
    @trigger_condition_results_before = @trigger_condition_results_after
  end

  def enqueue_time_trigger_job(method_name)
    opts = self.class.time_trigger_settings[method_name]

    # 英語的に at はTime、on はDateを想定しているが、実際には特に両者を区別はしない（ただしatを優先）
    time_attr = opts[:at] || opts[:on] # トリガーの基準となる日付/時刻属性の名前を取得
    target_time = send(time_attr) # 属性値を取得
    target_time = target_time.to_time if target_time.is_a?(Date) # DateならTimeに変換 (時刻は 00:00:00 とみなす)

    target_time = if opts[:before]
                    target_time - opts[:before]
                  elsif opts[:after]
                    target_time + opts[:after]
                  end

    # Delayedジョブをスケジュール
    ActiveRecordTimeTrigger::TimeTriggerJob.set(wait_until: target_time).perform_later(self.class.to_s, id, method_name)
  end

  def cancel_time_trigger_job(method_name)
    # TODO: 未実装
    # Active Jobにはジョブキャンセルの定義がないので、利用するバックエンドに固有の方法で実装する必要がある
  end
end
