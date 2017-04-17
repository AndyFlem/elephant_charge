class CreateCampaigns < ActiveRecord::Migration[5.0]
  def change
    create_table :campaigns do |t|
      t.string :mailchimp_id
      t.string :web_id
      t.datetime :send_time
      t.string :archive_url
      t.string :long_archive_url
      t.string :subject_line
      t.string :title

      t.timestamps
    end
  end
end
