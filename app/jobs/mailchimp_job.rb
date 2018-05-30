class MailchimpJob < ActiveJob::Base
  queue_as :default

  def perform
    gibbon = Gibbon::Request.new(api_key: "1acaa7c449a8bfb78ffa6fca4c6e5821-us12")
    cs=gibbon.campaigns.retrieve(params: {"list_id":"25eacd4a95","status":"sent","sort_field":"send_time","sort_dir":"desc","count":"100"})

    camps=cs.body["campaigns"]

    camps.each do |camp|
      unless Campaign.find_by_mailchimp_id(camp["id"])
        c=Campaign.new()
        c.mailchimp_id=camp["id"]
        c.web_id=camp["web_id"]
        c.send_time=camp["send_time"]
        c.archive_url=camp["archive_url"]
        c.long_archive_url=camp["long_archive_url"]
        c.subject_line=camp["settings"]["subject_line"]
        c.title=camp["settings"]["title"]
        c.save!
      end
    end
  end
end