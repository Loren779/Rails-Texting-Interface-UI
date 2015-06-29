class Task < ActiveRecord::Base
  belongs_to :user
  has_many :ownerships, dependent: :destroy
  has_many :recipients, through: :ownerships

  validates  :activity, presence: true
  validates  :message, presence: true, length: { minimum: 1 }
  validates  :schedule_time, presence: true
  
  before_save :change_run_at

  # Sends a text message using secrets ENV and relays to twilio
  def send_text_message(message, *phone)
    phone.each do |phone|
    	number_to_send_to = phone
      twilio_phone = ENV["TWILIO_PHONE_NUM"]
      twilio_account_sid = Rails.application.secrets.twilio_account_sid
      twilio_auth_token = Rails.application.secrets.twilio_auth_token

      @client = Twilio::REST::Client.new twilio_account_sid, twilio_auth_token

    	@message = @client.messages.create( 
        :from => twilio_phone,
    	  :to   => number_to_send_to,
    	  :body => message
      )
      render plain: @message.status
    end
  end

  def delayed_job
    Delayed::Job.find(delayed_job_id)
  end

  def schedule_sending_text # After user hits button on Task page
    phone = self.recipients.map(&:phone)
    job = self.delay(run_at: self.schedule_time).send_text_message(self.message, *phone)
    update_column(:delayed_job_id, job.id)
  end

  def change_run_at
    if schedule_time_changed? && !new_record? && !self.delayed_job_id.nil?
      delayed_job.update_column(:run_at, schedule_time)
    end
  end

end
