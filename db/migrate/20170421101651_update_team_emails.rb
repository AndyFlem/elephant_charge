class UpdateTeamEmails < ActiveRecord::Migration[5.0]
  def up
    t=Team.find_by_ref('camel')
    t.email='nickhodgson2001@hotmail.com'
    t.save!

    t=Team.find_by_ref('bushtracks')
    t.email='christopher@bushtracksafrica.com'
    t.save!

    t=Team.find_by_ref('newkasama')
    t.email='angela.chisembele@gmail.com'
    t.save!

    t=Team.find_by_ref('carnivores')
    t.email='rachel@cslzambia.org'
    t.save!

    t=Team.find_by_ref('khalamazi')
    t.email='gmkpw@khalamazi.com'
    t.save!

    t=Team.find_by_ref('sanctuary')
    t.email='omsimuko@sanctuaryretreats.com'
    t.captain='Oscar Simuko'
    t.save!
    t.entries.each do |entry|
      entry.captain='Oscar Simuko'
      entry.save!
    end

    t=Team.find_by_ref('duchesses')
    t.email='theolabarclay@gmail.com'
    t.save!

    t=Team.find_by_ref('mudhogs')
    t.email='prozampaints@gmail.com'
    t.save!

    t=Team.find_by_ref('lhmp')
    t.email='lawrencensompa@lhmp.org'
    t.save!

    t=Team.find_by_ref('goga')
    t.email='joof@afgri.com.zm'
    t.save!

    t=Team.find_by_ref('autoworld')
    t.email='david@autoworld.co.zm'
    t.save!

    t=Team.find_by_ref('almostthere')
    t.email='bosseds@gmail.com'
    t.save!

    t=Team.find_by_ref('sausage')
    t.email='jason@sausagetreecamp.com'
    t.save!

    t=Team.find_by_ref('greenmambas')
    t.email='christopherclubb@yahoo.co.uk'
    t.captain='Chris Clubb'
    t.save!
    e=Entry.find_by_id(192)
    e.captain='Chris Clubb'
    e.save!

    t=Team.find_by_ref('justbeer')
    t.email='justinrmbird@gmail.com'
    t.save!

    t=Team.find_by_ref('cfao')
    t.email='mvanniekerk@cfao.com'
    t.save!

    t=Team.find_by_ref('fuchs')
    t.email='fuchs1@fuchszambia.co.zm'
    t.captain='Alasdair Watson'
    t.save!
    t.entries.each do |entry|
      entry.captain='Alasdair Watson'
      entry.save!
    end

    t=Team.find_by_ref('swampdonkey')
    t.email='brynn@rma.co.bw'
    t.save!

    t=Team.find_by_ref('bigredhonda')
    t.email='nicholas.comana@honda.com.zm'
    t.save!

    t=Team.find_by_ref('hotclutch')
    t.email='sarah@wildlifecrimeprevention.org'
    t.save!

    t=Team.find_by_ref('hogsandkisses')
    t.email='ballettoanita@gmail.com'
    t.save!

    t=Team.find_by_ref('lhmp')
    t.paypal_button='<form action="https://www.paypal.com/cgi-bin/webscr" method="post" target="_blank"> <input type="hidden" name="cmd" value="_s-xclick"> <input type="hidden" name="hosted_button_id" value="8GWV5FMU6C8MJ"> <input type="image" src="https://www.paypalobjects.com/en_GB/i/btn/btn_donate_SM.gif" border="0" name="submit" alt="PayPal – The safer, easier way to pay online!"> <img alt="" border="0" src="https://www.paypalobjects.com/en_GB/i/scr/pixel.gif" width="1" height="1"> </form>'
    t.save!
  end
end
